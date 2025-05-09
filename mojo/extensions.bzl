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
        url = rctx.attr.urls or "https://dl.modular.com/public/nightly/python/max-{}-py3-none-{}.whl".format(
            rctx.attr.version,
            _PLATFORM_MAPPINGS[rctx.attr.platform],
        ),
        sha256 = rctx.attr.sha256 or _KNOWN_SHAS.get(rctx.attr.version, {}).get(rctx.attr.platform, ""),
        type = "zip",
        strip_prefix = rctx.attr.strip_prefix or "max-{}.data/platlib/max".format(rctx.attr.version),
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
        "urls": attr.string_list(
            doc = "The URL to download the Mojo toolchain from.",
            mandatory = False,
        ),
        "sha256": attr.string(
            doc = "The SHA256 hash of the Mojo toolchain archive.",
            mandatory = False,
        ),
        "strip_prefix": attr.string(
            doc = "The prefix to strip from the extracted Mojo toolchain.",
            mandatory = False,
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
    platforms = []

    for module in mctx.modules:
        if not module.is_root:
            continue

        if len(module.tags.toolchain) > 1:
            fail("mojo.toolchain() can only be called once per module.")

        tags = module.tags.toolchain[0]

        platforms = tags.urls.keys() if tags.urls else _PLATFORMS
        for platform in platforms:
            name = "mojo_toolchain_{}".format(platform)
            _mojo_toolchain_repository(
                name = name,
                version = tags.version,
                platform = platform,
                urls = tags.urls.get(platform, None),
                sha256 = tags.sha256.get(platform, None),
                strip_prefix = tags.strip_prefix.get(platform, None),
                use_prebuilt_packages = tags.use_prebuilt_packages,
            )

    _mojo_toolchain_hub(
        name = "mojo_toolchains",
        platforms = platforms,
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
        "urls": attr.string_list_dict(
            mandatory = False,
            doc = """\
URLs to prebuilt archives containing mojo toolchains. They key is the platform
and the value is a list of URLs for the download. Only the provided platforms
will have toolchains created for them. Providing 'sha256's is recommended.

Example:

urls = {
    "linux_x86_64": ["https://.../max-25.4.0.dev2025050905-py3-none-manylinux_2_34_x86_64.whl"],
    "linux_aarch64": ["https://.../max-25.4.0.dev2025050905-py3-none-manylinux_2_34_aarch64.whl"],
    "macos_arm64": ["https://.../max-25.4.0.dev2025050905-py3-none-macosx_13_0_arm64.whl"],
}
""",
        ),
        "sha256": attr.string_dict(
            mandatory = False,
            doc = """\
SHA256 hashes for the provided URLs. The key is the platform and the value is the sha256 hash.

Example:

sha256 = {
    "linux_aarch64": "abc123",
    "linux_x86_64": "abc123",
    "macos_arm64": "abc123",
}
""",
        ),
        "strip_prefix": attr.string_dict(
            mandatory = False,
            doc = """\
The prefix to strip from the extracted Mojo toolchain. The key is the platform the value is the prefix to strip. Otherwise there is a reasonable default based on the 'version' attribute.

Example:

strip_prefix = {
    "linux_aarch64": "abc123",
    "linux_x86_64": "abc123",
    "macos_arm64": "abc123",
}
""",
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
