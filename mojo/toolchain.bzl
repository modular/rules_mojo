"""The Mojo compiler toolchain."""

load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("//mojo:providers.bzl", "MojoInfo", "MojoToolchainInfo")

def _mojo_toolchain_impl(ctx):
    tool_files = []
    for dep in ctx.attr.implicit_deps + ctx.attr.extra_tools + [ctx.attr.lld, ctx.attr.mojo]:
        tool_files.append(dep[DefaultInfo].default_runfiles.files)
        tool_files.append(dep[DefaultInfo].files)

    copts = list(ctx.attr.copts)
    gpu_toolchain = ctx.toolchains["//:gpu_toolchain_type"]
    if gpu_toolchain:
        copts.append("--target-accelerator=" + gpu_toolchain.mojo_gpu_toolchain_info.target_accelerator)
    else:
        copts.append("--target-accelerator=NONE")

    is_macos = ctx.target_platform_has_constraint(ctx.attr._macos_constraint[platform_common.ConstraintValueInfo])
    if is_macos:
        min_os = ctx.fragments.cpp.minimum_os_version() or ctx.fragments.apple.macos_minimum_os_flag
        if min_os:
            copts.append("--target-triple=arm64-apple-macosx{}".format(min_os))

    return [
        platform_common.ToolchainInfo(
            mojo_toolchain_info = MojoToolchainInfo(
                all_tools = tool_files,
                copts = copts,
                package_copts = ctx.attr.package_copts,
                lld = ctx.executable.lld,
                mojo = ctx.executable.mojo,
                implicit_deps = ctx.attr.implicit_deps,
            ),
        ),
    ]

mojo_toolchain = rule(
    implementation = _mojo_toolchain_impl,
    attrs = {
        "copts": attr.string_list(
            mandatory = False,
            doc = "Additional compiler options to pass to the Mojo compiler.",
        ),
        "package_copts": attr.string_list(
            mandatory = False,
            doc = "Additional compiler options to pass to the Mojo compiler when running 'mojo package'.",
        ),
        "extra_tools": attr.label_list(
            providers = [DefaultInfo],
            allow_files = True,
            mandatory = False,
            cfg = "exec",
            doc = "Additional tools to make available to every Mojo action.",
        ),
        "lld": attr.label(
            allow_files = True,
            mandatory = True,
            executable = True,
            cfg = "exec",
            doc = "The lld executable to link with.",
        ),
        "mojo": attr.label(
            allow_files = True,
            mandatory = True,
            executable = True,
            cfg = "exec",
            doc = "The mojo compiler executable to build with.",
        ),
        "implicit_deps": attr.label_list(
            providers = [[CcInfo], [MojoInfo]],
            mandatory = True,
            cfg = "target",
            doc = "Implicit dependencies that every target should depend on, providing either CcInfo, or MojoInfo.",
        ),
        "_macos_constraint": attr.label(
            default = Label("@platforms//os:macos"),
        ),
    },
    doc = """\
Defines the Mojo compiler toolchain.
""",
    toolchains = [
        config_common.toolchain_type("//:gpu_toolchain_type", mandatory = False),
    ],
    fragments = ["cpp", "apple"],
)
