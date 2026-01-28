"""MODULE.bazel extensions for Mojo toolchains."""

load("//mojo:mojo_host_platform.bzl", "mojo_host_platform")
load("//mojo/private:mojo_gpu_toolchains_repository.bzl", "mojo_gpu_toolchains_repository")

_PLATFORMS = ["linux_aarch64", "linux_x86_64", "macos_arm64"]
_DEFAULT_VERSION = "0.26.2.0.dev2026012806"
_KNOWN_SHAS = {
    "0.26.1.0.dev2026011405": {
        "linux_aarch64": "f365b74545234d891f76db0395dfcfc41eb4591a611d361251738ba197d8281b",
        "linux_x86_64": "4f0f0aa0eb6c815cd081c76a8218865a3d22d0a33fa502245d41e1a6ad836a15",
        "macos_arm64": "0ea255379d009779e6a3ccda7039146f33cdd15324c3e97d659a6fb1644f2519",
    },
    "0.26.2.0.dev2026012806": {
        "linux_aarch64": "1883a67311f8f51c17869c81b93014153215afff078aee0da454823400ecb218",
        "linux_x86_64": "91f88e2fd9b4c612f9c08da95cfcb9a4a1291f603c95314f35ed6366736f01c6",
        "macos_arm64": "ba37e525b6ba6a7e4a70a8bbef83bce1187541a2d4da625943c3a604d69b261c",
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
}

def _mojo_toolchain_impl(rctx):
    base_url = rctx.attr.base_url or "https://whl.modular.com/nightly/mojo-compiler"
    rctx.download_and_extract(
        url = "{}/mojo_compiler-{}-py3-none-{}.whl".format(
            base_url,
            rctx.attr.version,
            _PLATFORM_MAPPINGS[rctx.attr.platform],
        ),
        sha256 = _KNOWN_SHAS.get(rctx.attr.version, _NULL_SHAS)[rctx.attr.platform],
        type = "zip",
        strip_prefix = "mojo_compiler-{}.data/platlib/modular".format(rctx.attr.version),
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
            doc = "Whether to automatically add prebuilt mojopkgs to every mojo target.",
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
            doc = "Whether to automatically add prebuilt mojopkgs to every mojo target.",
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
