"""MODULE.bazel extensions for Mojo toolchains."""

load("//mojo:mojo_host_platform.bzl", "mojo_host_platform")
load("//mojo/private:mojo_gpu_toolchains_repository.bzl", "mojo_gpu_toolchains_repository")

_PLATFORMS = ["linux_aarch64", "linux_x86_64", "macos_arm64"]
_DEFAULT_VERSION = "1.0.0b2.dev2026060706"
_KNOWN_SHAS = {
    "1.0.0b2.dev2026060706": {
        "linux_aarch64": "ff57b49bb38eb832302a72d4f4c2f2c7553bf559ee5de2798daafb57a37877e8",
        "linux_x86_64": "e28b4b663cce73416507f957b54d2b4c96a7bd3f42bbe41ec74e8c0b6f93444c",
        "macos_arm64": "45261916bb30cfe16d2bd04bcfcf3ded8dca0934ec33b559316891a5217588e6",
        "mojo_compiler_mojo_libs": "4452a8ad98634178c0cae20799a41e385a306159f94b409955ac95e052dd9e55",
    },
    "1.0.0b2.dev2026051806": {
        "linux_aarch64": "224c4c1590debdff509bde74ead2da7b3eef2bc052380627e824072fe18bef05",
        "linux_x86_64": "7775e0386cb564cfd09f34c74209b80fc5a5d43b5ac20e36e638032e0f0cd63a",
        "macos_arm64": "5effdfe6fa9962802bba236baa15541584d7c27e3224d304d39d00912113fe58",
        "mojo_compiler_mojo_libs": "63e7bcbca2f311d6aba0c90cdd3c1152d153ee3f0f65ccc5c4f06f61b84c06e4",
    },
}
_PLATFORM_MAPPINGS = {
    "linux_aarch64": "manylinux_2_34_aarch64",
    "linux_x86_64": "manylinux_2_34_x86_64",
    "macos_arm64": "macosx_13_0_arm64",
}
_NULL_SHAS = {
    "linux_aarch64": "",
    "linux_x86_64": "",
    "macos_arm64": "",
    "mojo_compiler_mojo_libs": "",
}

def _mojo_toolchain_impl(rctx):
    for whl in "mojo_compiler", "mojo_compiler_mojo_libs":
        base_url = (rctx.attr.base_url or "https://whl.modular.com/nightly") + "/" + whl.replace("_", "-")
        platform = _PLATFORM_MAPPINGS[rctx.attr.platform] if whl == "mojo_compiler" else "any"
        sha_key = rctx.attr.platform if whl == "mojo_compiler" else "mojo_compiler_mojo_libs"
        rctx.download_and_extract(
            url = "{}/{}-{}-py3-none-{}.whl".format(
                base_url,
                whl,
                rctx.attr.version,
                platform,
            ),
            sha256 = _KNOWN_SHAS.get(rctx.attr.version, _NULL_SHAS)[sha_key],
            type = "zip",
            strip_prefix = "{}-{}.data/platlib/modular".format(whl, rctx.attr.version),
        )

    rctx.template(
        "BUILD.bazel",
        rctx.attr._template,
        substitutions = {
            "{INCLUDE_MOJOPKGS}": "yes" if rctx.attr.use_prebuilt_packages else "",  # NOTE: Empty string for false to keep template BUILD file syntax lintable
        },
    )

_mojo_toolchain_repository = repository_rule(
    implementation = _mojo_toolchain_impl,
    doc = "A Mojo toolchain repository rule.",
    attrs = {
        "version": attr.string(
            doc = "The version of the Mojo toolchain to download.",
            mandatory = True,
        ),
        "platform": attr.string(
            doc = "The platform to download the Mojo toolchain for.",
            values = _PLATFORMS,
            mandatory = True,
        ),
        "base_url": attr.string(
            doc = "Override the base download URL for the prebuilt package.",
            default = "",
        ),
        "use_prebuilt_packages": attr.bool(
            doc = "Whether to automatically add prebuilt mojo packages to every mojo target.",
            mandatory = True,
        ),
        "_template": attr.label(
            default = Label("//mojo/private:toolchain.BUILD"),
        ),
    },
)

def _mojo_toolchain_hub_impl(rctx):
    lines = []
    for platform in rctx.attr.platforms:
        lines.append("""
toolchain(
    name = "{platform}_toolchain",
    exec_compatible_with = [
        "@platforms//cpu:{cpu}",
        "@platforms//os:{os}",
    ],
    target_compatible_with = [  # Wheels only contain support libraries for 1 platform and cross OS compilation is not supported.
        "@platforms//cpu:{cpu}",
        "@platforms//os:{os}",
    ],
    toolchain = "@mojo_toolchain_{platform}//:mojo_toolchain",
    toolchain_type = "@rules_mojo//:toolchain_type",
)
""".format(
            platform = platform,
            cpu = "x86_64" if "x86_64" in platform else "aarch64",
            os = "macos" if "macos" in platform else "linux",
        ))

    rctx.file("BUILD.bazel", content = "\n".join(lines))

_mojo_toolchain_hub = repository_rule(
    implementation = _mojo_toolchain_hub_impl,
    doc = "A convenience repository for registering all potential Mojo toolchains at once.",
    attrs = {
        "platforms": attr.string_list(doc = "The platforms to register Mojo toolchains for."),
    },
)

def _setup_toolchains(root_module, rules_mojo_module):
    toolchains = root_module.tags.toolchain or rules_mojo_module.tags.toolchain
    if len(toolchains) > 1:
        fail("mojo.toolchain() can only be called once per module.")

    tags = toolchains[0]
    for platform in _PLATFORMS:
        name = "mojo_toolchain_{}".format(platform)
        _mojo_toolchain_repository(
            name = name,
            version = tags.version,
            platform = platform,
            base_url = tags.base_url,
            use_prebuilt_packages = tags.use_prebuilt_packages,
        )

    gpu_toolchains = root_module.tags.gpu_toolchains or rules_mojo_module.tags.gpu_toolchains
    if len(gpu_toolchains) > 1:
        fail("mojo.gpu_toolchain() can only be called once per module.")
    gpu_toolchain = gpu_toolchains[0]
    mojo_gpu_toolchains_repository(
        name = "mojo_gpu_toolchains",
        supported_gpus = gpu_toolchain.supported_gpus,
    )

    mojo_host_platform(
        name = "mojo_host_platform",
        gpu_mapping = gpu_toolchain.gpu_mapping,
    )

    _mojo_toolchain_hub(
        name = "mojo_toolchains",
        platforms = _PLATFORMS,
    )

def _mojo_impl(mctx):
    # TODO: This requires the root module always call mojo.toolchain(), we
    # should improve this.
    root_module = None
    rules_mojo_module = None
    for module in mctx.modules:
        if module.is_root:
            root_module = module
        if module.name == "rules_mojo":
            rules_mojo_module = module

        if root_module and rules_mojo_module:
            break

    # If you don't have a module() definition there is no root module
    root_module = root_module or rules_mojo_module
    _setup_toolchains(root_module, rules_mojo_module)
    return mctx.extension_metadata(reproducible = True)

_toolchain_tag = tag_class(
    doc = "Tags for downloading Mojo toolchains.",
    attrs = {
        # TODO: Add an attribute to pass through shas
        "version": attr.string(
            doc = "The version of the Mojo toolchain to download.",
            default = _DEFAULT_VERSION,
        ),
        "base_url": attr.string(
            doc = "Override the base download URL for the prebuilt package.",
            default = "",
        ),
        "use_prebuilt_packages": attr.bool(
            doc = "Whether to automatically add prebuilt mojo packages to every mojo target.",
            default = True,
        ),
    },
)

_gpu_toolchains_tag = tag_class(
    doc = "Tags for configuring Mojo GPU toolchains.",
    attrs = {
        "supported_gpus": attr.string_dict(
            default = {
                "780M": "amdgpu:gfx1103",
                "a10": "nvidia:86",
                "a100": "nvidia:80",
                "a3000": "nvidia:86",
                "b100": "nvidia:100a",
                "b200": "nvidia:100a",
                "h100": "nvidia:90a",
                "h200": "nvidia:90a",
                "l4": "nvidia:89",
                "mi300x": "amdgpu:gfx942",
                "mi325": "amdgpu:gfx942",
                "mi355": "amdgpu:gfx950",
                "rtx5090": "nvidia:120a",
                "metal3": "metal:30",
                "metal4": "metal:40",
            },
            doc = "The GPUs supported by this toolchain, mapping to Mojo's target accelerators.",
        ),
        "gpu_mapping": attr.string_dict(
            default = {
                " A10G": "a10",
                "A100-": "a100",
                " H100 ": "h100",
                " H200 ": "h200",
                " L4 ": "L4",
                " Ada ": "L4",
                " A3000 ": "a3000",
                "B100": "b100",
                "B200": "b200",
                " RTX 5090": "rtx5090",
                "Laptop GPU": "",
                "RTX 4070 Ti": "",
                "RTX 4080 SUPER": "",
                "NVIDIA GeForce RTX 3090": "",
                "MI300X": "mi300x",
                "MI325": "mi325",
                "MI355": "mi355",
                "Navi": "radeon",
                "AMD Radeon Graphics": "radeon",
                "Metal 3": "metal3",
                "Metal 4": "metal4",
            },
            doc = "The output from nvidia-smi or rocm-smi to the corresponding GPU name in SUPPORTED_GPUS.",
        ),
    },
)

mojo = module_extension(
    doc = "Mojo toolchain extension.",
    implementation = _mojo_impl,
    tag_classes = {
        "toolchain": _toolchain_tag,
        "gpu_toolchains": _gpu_toolchains_tag,
    },
)
