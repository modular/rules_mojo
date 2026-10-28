"""MODULE.bazel extensions for Mojo toolchains."""

load("//mojo:mojo_host_platform.bzl", "mojo_host_platform")
load("//mojo/private:mojo_gpu_toolchains_repository.bzl", "mojo_gpu_toolchains_repository")

_PLATFORMS = ["linux_aarch64", "linux_x86_64", "macos_arm64"]
_DEFAULT_VERSION = "1.2.0"

# Generated from official wheel metadata; update with tools/getshas.py.
_KNOWN_RELEASES = {
    "1.0.0": {
        "linux_aarch64": struct(
            url = "https://files.pythonhosted.org/packages/a5/f9/cbfe2bf947d0926ad57599513d898f1e02ee0c60af1253b779ecaa810235/mojo_compiler-1.0.0-py3-none-manylinux_2_34_aarch64.whl",
            sha256 = "3ae3eb0c58a8956f542e324f736866df0ae2f9f875e8a279cbeea961ec4e9ee8",
        ),
        "linux_x86_64": struct(
            url = "https://files.pythonhosted.org/packages/f0/5f/f38fefe327d1c81e28def69c4a52ae4f75e389cb6e613a2c04ca8d68d582/mojo_compiler-1.0.0-py3-none-manylinux_2_34_x86_64.whl",
            sha256 = "e9e60f9638e69ca0f4be7292468523fc98a143f58dbf9024f60ed68b874a867e",
        ),
        "macos_arm64": struct(
            url = "https://files.pythonhosted.org/packages/60/59/c11cf3129d4bc77b1604ac3a84bee51ee1a7cd8a3a8fa25c14528f4bd51e/mojo_compiler-1.0.0-py3-none-macosx_13_0_arm64.whl",
            sha256 = "5077ee27c0dfbbdf138a11ec12838b0d3f10148a874cf95040c9ca2332ae2622",
        ),
        "mojo_compiler_mojo_libs": struct(
            url = "https://files.pythonhosted.org/packages/54/99/ea401ff1db56a4af8607283b95627e01b986fc67f510715b07f100118105/mojo_compiler_mojo_libs-1.0.0-py3-none-any.whl",
            sha256 = "20a92e37ecbd19e2dbb1a525612a8de4c9f266f5536def55c5e2b0786320e8b3",
        ),
    },
    "1.1.0": {
        "linux_aarch64": struct(
            url = "https://files.pythonhosted.org/packages/67/1c/2c93f967615e3581b124b1b5f4af29913994199e8741736d9c08ed3d9f13/mojo_compiler-1.1.0-py3-none-manylinux_2_34_aarch64.whl",
            sha256 = "14ed7fe3570e1374a88bc8aa93dc4e9c519ea28e7f8d731ae4bf1c468d8179ec",
        ),
        "linux_x86_64": struct(
            url = "https://files.pythonhosted.org/packages/e8/5e/31522e5336d63ab0fad18980cccf6c5cc2085c1a041ea3723eb916a17c08/mojo_compiler-1.1.0-py3-none-manylinux_2_34_x86_64.whl",
            sha256 = "b47442278eb39705075f23d058b38a364bd68bdaa542ad514c187cee633beab7",
        ),
        "macos_arm64": struct(
            url = "https://files.pythonhosted.org/packages/7e/47/4ee8cf2041538076d1a11bb3c2b3ed18791b52c1edec8e31ca244d841389/mojo_compiler-1.1.0-py3-none-macosx_13_0_arm64.whl",
            sha256 = "02daffdfd8fcd56ecfb74e93d2adfaf4551cbb0b384094508fd00c1d5d81cb00",
        ),
        "mojo_compiler_mojo_libs": struct(
            url = "https://files.pythonhosted.org/packages/83/8d/4fb2147d140b6ea688f6d256b3119d6554a3d50095d802f01bf24234bd7d/mojo_compiler_mojo_libs-1.1.0-py3-none-any.whl",
            sha256 = "dd8c5382e27fe5c1ffe0834d267f549abbffee35bf1a8d605cf24252ff95a2e6",
        ),
    },
    "1.2.0": {
        "linux_aarch64": struct(
            url = "https://files.pythonhosted.org/packages/62/c6/c716f593f140abf9cf40dd44a1b6a4745ead22cd3fd03cc856b024e6c799/mojo_compiler-1.2.0-py3-none-manylinux_2_34_aarch64.whl",
            sha256 = "72d6f8321a50136945598ab4b9874e9980bd03103bf93545444b4448919e48c9",
        ),
        "linux_x86_64": struct(
            url = "https://files.pythonhosted.org/packages/54/8b/2758e8a2207793613d386f41e36f2bfd28837b157a659518c7b7474f7eb3/mojo_compiler-1.2.0-py3-none-manylinux_2_34_x86_64.whl",
            sha256 = "3ee34a3b26c6cccaa9523a0e8db8f67bea954497d782d97c9e61c3c4ecbdac7b",
        ),
        "macos_arm64": struct(
            url = "https://files.pythonhosted.org/packages/d6/0c/df22d1807e2bddebd992caee411e6cbe0c5d41834e36bff883f4a7d95fc3/mojo_compiler-1.2.0-py3-none-macosx_13_0_arm64.whl",
            sha256 = "bc1777d9b3cf4522ee213cc83876b1955499aec2aa8dd8a75ce477f0cd227a90",
        ),
        "mojo_compiler_mojo_libs": struct(
            url = "https://files.pythonhosted.org/packages/3d/bb/9602cbee467102584721c700dda8033af67c3888c6c8edb6f66275c1df74/mojo_compiler_mojo_libs-1.2.0-py3-none-any.whl",
            sha256 = "3d631f7e798c11d0029c4a892ebae1f5742751fac0c526af74b45a8ae07c3acb",
        ),
    },
}
_PLATFORM_MAPPINGS = {
    "linux_aarch64": "manylinux_2_34_aarch64",
    "linux_x86_64": "manylinux_2_34_x86_64",
    "macos_arm64": "macosx_13_0_arm64",
}

def _mojo_toolchain_impl(rctx):
    for whl in "mojo_compiler", "mojo_compiler_mojo_libs":
        base_url = (rctx.attr.base_url or "https://whl.modular.com/nightly") + "/" + whl.replace("_", "-")
        platform = _PLATFORM_MAPPINGS[rctx.attr.platform] if whl == "mojo_compiler" else "any"
        sha_key = rctx.attr.platform if whl == "mojo_compiler" else "mojo_compiler_mojo_libs"
        release = _KNOWN_RELEASES.get(rctx.attr.version, {}).get(sha_key)
        url = "{}/{}-{}-py3-none-{}.whl".format(base_url, whl, rctx.attr.version, platform)
        if release and not rctx.attr.base_url:
            url = release.url
        rctx.download_and_extract(
            url = url,
            sha256 = release.sha256 if release else "",
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
