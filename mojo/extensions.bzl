"""MODULE.bazel extensions for Mojo toolchains."""

_PLATFORMS = ["linux_aarch64", "linux_x86_64", "macos_arm64"]
_DEFAULT_VERSION = "25.4.0.dev2025050902"
_KNOWN_SHAS = {
    "25.4.0.dev2025050902": {
        "linux_aarch64": "d52c67f245575397d8176010d27bd12e76cde297ed8ee7f07dcc73fe48955508",
        "linux_x86_64": "69898a4ffb328489e5c7c1c7e0cba37cd64dd0fa87b4a98501b3562dc89f2695",
        "macos_arm64": "8856745cab1cb88fbba174afb9784cbdda865c8a4e4db5693750efefe7505160",
    },
}
_PLATFORM_MAPPINGS = {
    "linux_aarch64": "manylinux_2_34_aarch64",
    "linux_x86_64": "manylinux_2_34_x86_64",
    "macos_arm64": "macosx_13_0_arm64",
}

def _mojo_toolchain_impl(rctx):
    rctx.download_and_extract(
        url = "https://dl.modular.com/public/nightly/python/max-{}-py3-none-{}.whl".format(
            rctx.attr.version,
            _PLATFORM_MAPPINGS[rctx.attr.platform],
        ),
        sha256 = _KNOWN_SHAS[rctx.attr.version][rctx.attr.platform],
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

        if len(module.tags.toolchain) > 1:
            fail("mojo.toolchain() can only be called once per module.")

        has_toolchains = True
        tags = module.tags.toolchain[0]

        for platform in _PLATFORMS:
            name = "mojo_toolchain_{}".format(platform)
            _mojo_toolchain_repository(
                name = name,
                version = tags.version,
                platform = platform,
                use_prebuilt_packages = tags.use_prebuilt_packages,
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
        "use_prebuilt_packages": attr.bool(
            doc = "Whether to automatically add prebuilt mojopkgs to every mojo target.",
            default = True,
        ),
    },
)

mojo = module_extension(
    doc = "Mojo toolchain extension.",
    implementation = _mojo_impl,
    tag_classes = {
        "toolchain": _toolchain_tag,
    },
)
