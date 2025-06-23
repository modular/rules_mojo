"""MODULE.bazel extensions for Mojo toolchains."""

load("//mojo:mojo_host_platform.bzl", "mojo_host_platform")
load("//mojo/private:mojo_gpu_toolchains_repository.bzl", "mojo_gpu_toolchains_repository")

_PLATFORMS = ["linux_aarch64", "linux_x86_64", "macos_arm64"]
_DEFAULT_VERSION = "25.5.0.dev2025062305"
_KNOWN_SHAS = {
    "25.4.0.dev2025050902": {
        "linux_aarch64": "d52c67f245575397d8176010d27bd12e76cde297ed8ee7f07dcc73fe48955508",
        "linux_x86_64": "69898a4ffb328489e5c7c1c7e0cba37cd64dd0fa87b4a98501b3562dc89f2695",
        "macos_arm64": "8856745cab1cb88fbba174afb9784cbdda865c8a4e4db5693750efefe7505160",
    },
    "25.5.0.dev2025062305": {
        "linux_aarch64": "7b516b9ef485cc25f981d438bba974108dc115509d17f58431866bde8f962043",
        "linux_x86_64": "51302b87d8d83891762877be0bf73fffbf196a47246be339e818c4b3480e1ac4",
        "macos_arm64": "694e3be8f2180a67602e781fcbde5c0241d1b5951300962a04d5e695ead7db28",
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
    rctx.download_and_extract(
        url = rctx.attr.url_override or "https://dl.modular.com/public/nightly/python/max-{}-py3-none-{}.whl".format(
            rctx.attr.version,
            _PLATFORM_MAPPINGS[rctx.attr.platform],
        ),
        sha256 = _KNOWN_SHAS.get(rctx.attr.version, _NULL_SHAS)[rctx.attr.platform],
        type = "zip",
        strip_prefix = "max-{}.data/platlib/max".format(rctx.attr.version),
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
        "url_override": attr.string(
            doc = "Override the download URL for the prebuilt package.",
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

def _mojo_impl(mctx):
    # TODO: This requires the root module always call mojo.toolchain(), we
    # should improve this.
    has_toolchains = False
    for module in mctx.modules:
        if not module.is_root:
            continue

        toolchains = module.tags.toolchain
        if len(module.tags.toolchain) > 1:
            fail("mojo.toolchain() can only be called once per module.")
        if toolchains:
            has_toolchains = True
            tags = toolchains[0]

            for platform in _PLATFORMS:
                name = "mojo_toolchain_{}".format(platform)
                _mojo_toolchain_repository(
                    name = name,
                    version = tags.version,
                    platform = platform,
                    url_override = tags.url_override,
                    use_prebuilt_packages = tags.use_prebuilt_packages,
                )

        gpu_toolchains = module.tags.gpu_toolchains
        if len(gpu_toolchains) > 1:
            fail("mojo.gpu_toolchain() can only be called once per module.")
        if gpu_toolchains:
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
        platforms = _PLATFORMS if has_toolchains else [],
    )

    return mctx.extension_metadata(reproducible = True)

_toolchain_tag = tag_class(
    doc = "Tags for downloading Mojo toolchains.",
    attrs = {
        # TODO: Add an attribute to pass through shas
        "version": attr.string(
            doc = "The version of the Mojo toolchain to download.",
            default = _DEFAULT_VERSION,
        ),
        "url_override": attr.string(
            doc = "Override the download URL for the prebuilt package.",
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
                "rtx5090": "nvidia:120a",
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
                "Navi": "radeon",
                "AMD Radeon Graphics": "radeon",
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
