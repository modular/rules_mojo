"""The Mojo compiler toolchain."""

load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("//mojo:providers.bzl", "MojoCoptsToolchainInfo", "MojoInfo", "MojoToolchainInfo")

def _mojo_toolchain_impl(ctx):
    precompile_files = []
    for dep in ctx.attr.precompile_tools + [ctx.attr.mojo]:
        precompile_files.append(dep[DefaultInfo].default_runfiles.files)
        precompile_files.append(dep[DefaultInfo].files)

    build_files = []
    for dep in ctx.attr.build_tools + [ctx.attr.lld]:
        build_files.append(dep[DefaultInfo].default_runfiles.files)
        build_files.append(dep[DefaultInfo].files)

    copts = list(ctx.attr.copts)
    precompile_copts = list(ctx.attr.precompile_copts)
    gpu_toolchain = ctx.toolchains["//:gpu_toolchain_type"]
    if gpu_toolchain:
        copts.append("--target-accelerator=" + gpu_toolchain.mojo_gpu_toolchain_info.target_accelerator)

    is_macos = ctx.target_platform_has_constraint(ctx.attr._macos_constraint[platform_common.ConstraintValueInfo])
    if is_macos:
        min_os = ctx.fragments.cpp.minimum_os_version() or ctx.fragments.apple.macos_minimum_os_flag
        if min_os:
            copts.append("--target-triple=arm64-apple-macosx{}".format(min_os))

    copts_toolchain = ctx.toolchains["//:copts_toolchain_type"]
    if copts_toolchain:
        copts.extend(copts_toolchain.copts_toolchain_info.copts)
        precompile_copts = copts_toolchain.copts_toolchain_info.precompile_copts

    return [
        platform_common.ToolchainInfo(
            mojo_toolchain_info = MojoToolchainInfo(
                copts = copts,
                build_env = ctx.attr.build_env,
                build_tools = build_files,
                precompile_copts = precompile_copts,
                precompile_env = ctx.attr.precompile_env,
                precompile_tools = precompile_files,
                lld = ctx.executable.lld,
                mojo = ctx.executable.mojo,
                implicit_deps = ctx.attr.implicit_deps,
                runtime_env = ctx.attr.runtime_env,
                extra_runfiles = ctx.attr.extra_runfiles,
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
        "build_env": attr.string_dict(
            mandatory = False,
            doc = "Dict of environment variables to set during compilation. Additive on precompile_env.",
        ),
        "build_tools": attr.label_list(
            providers = [DefaultInfo],
            allow_files = True,
            mandatory = False,
            cfg = "exec",
            doc = "Additional tools to make available to Mojo compile actions. Additive on precompile_tools.",
        ),
        "precompile_copts": attr.string_list(
            mandatory = False,
            doc = "Additional compiler options to pass to the Mojo compiler when running 'mojo precompile'.",
        ),
        "precompile_env": attr.string_dict(
            mandatory = False,
            doc = "Dict of environment variables to set during precompilation.",
        ),
        "precompile_tools": attr.label_list(
            providers = [DefaultInfo],
            allow_files = True,
            mandatory = False,
            cfg = "exec",
            doc = "Additional tools to make available to Mojo precompile actions.",
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
        "runtime_env": attr.string_dict(
            mandatory = False,
            doc = "Dict of environment variables to set on compiled Mojo programs at runtime.",
        ),
        "extra_runfiles": attr.label_list(
            providers = [DefaultInfo],
            allow_files = True,
            mandatory = False,
            cfg = "target",
            doc = "Additional files to make available to compiled Mojo programs at runtime.",
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
        config_common.toolchain_type("//:copts_toolchain_type", mandatory = False),
    ],
    fragments = ["cpp", "apple"],
)

def _mojo_copts_toolchain_impl(ctx):
    return [
        platform_common.ToolchainInfo(
            copts_toolchain_info = MojoCoptsToolchainInfo(
                copts = ctx.attr.copts,
                precompile_copts = ctx.attr.precompile_copts,
            ),
        ),
    ]

mojo_copts_toolchain = rule(
    implementation = _mojo_copts_toolchain_impl,
    attrs = {
        "copts": attr.string_list(
            mandatory = True,
            doc = "Additional compiler options to pass to the Mojo compiler.",
        ),
        "precompile_copts": attr.string_list(
            mandatory = True,
            doc = "Additional compiler options to pass to the Mojo compiler when running 'mojo precompile'.",
        ),
    },
    doc = """\
Defines additional compiler options for the Mojo compiler.
""",
)
