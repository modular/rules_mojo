"""Compile Mojo files into a mojopkg that can be consumed by other Mojo targets."""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("//mojo:providers.bzl", "MojoInfo")
load("//mojo/private:utils.bzl", "MOJO_EXTENSIONS", "collect_mojoinfo")

def _format_include(arg):
    return ["-I", arg.dirname]

def _mojo_library_implementation(ctx):
    mojo_toolchain = ctx.toolchains["//:toolchain_type"].mojo_toolchain_info

    mojo_package = ctx.actions.declare_file(ctx.label.name + ".mojopkg")
    args = ctx.actions.args()
    args.add("package")
    args.add("-strip-file-prefix=.")
    args.add("-o", mojo_package)

    args.add_all(mojo_toolchain.package_copts)
    if "-exec-" not in ctx.bin_dir.path:
        args.add_all(ctx.attr._mojo_package_copts[BuildSettingInfo].value)
    args.add_all([
        ctx.expand_location(copt, targets = ctx.attr.additional_compiler_inputs)
        for copt in ctx.attr.copts
    ])

    import_paths, transitive_mojopkgs = collect_mojoinfo(ctx.attr.deps + mojo_toolchain.implicit_deps)
    root_directory = ctx.files.srcs[0].dirname

    file_args = ctx.actions.args()
    for file in ctx.files.srcs:
        if not file.dirname.startswith(root_directory):
            args.add_all([file], map_each = _format_include)

    output_group_kwargs = {}
    package_outputs = [mojo_package]
    if ctx.attr._export_fixits[BuildSettingInfo].value:
        fixits_file = ctx.actions.declare_file(ctx.label.name + ".mojo_fixits.yaml")
        package_outputs.append(fixits_file)
        output_group_kwargs["mojo_fixits"] = depset([fixits_file])
        args.add("--experimental-export-fixit", fixits_file)

    file_args.add_all(transitive_mojopkgs, map_each = _format_include)
    file_args.add(root_directory)
    ctx.actions.run(
        executable = mojo_toolchain.mojo,
        inputs = depset(ctx.files.srcs + ctx.files.additional_compiler_inputs, transitive = [transitive_mojopkgs]),
        tools = mojo_toolchain.all_tools,
        outputs = package_outputs,
        arguments = [args, file_args],
        mnemonic = "MojoPackage",
        progress_message = "%{label} building mojo package",
        env = {
            "MODULAR_CRASH_REPORTING_ENABLED": "false",
            "PATH": "/dev/null",  # Avoid using the host's PATH
            "TEST_TMPDIR": ".",  # Make sure any cache files are written to somewhere bazel will cleanup
        },
        use_default_shell_env = True,
        toolchain = "//:toolchain_type",
        execution_requirements = {
            "supports-path-mapping": "1",
        },
    )

    transitive_runfiles = []
    for target in ctx.attr.data:
        transitive_runfiles.append(target[DefaultInfo].default_runfiles)

    return [
        DefaultInfo(
            files = depset([mojo_package]),
            runfiles = ctx.runfiles(ctx.files.data).merge_all(transitive_runfiles),
        ),
        MojoInfo(
            import_paths = depset([mojo_package.dirname], transitive = [import_paths]),
            mojopkgs = depset([mojo_package], transitive = [transitive_mojopkgs]),
        ),
        OutputGroupInfo(**output_group_kwargs),
    ]

mojo_library = rule(
    implementation = _mojo_library_implementation,
    attrs = {
        "additional_compiler_inputs": attr.label_list(
            allow_files = True,
            doc = """\
Additional files to pass to the compiler command line. Files specified here can
then be used in copts with the $(location) function.
""",
        ),
        "copts": attr.string_list(
            doc = """\
Additional compiler options to pass to the Mojo compiler.

Order of options:
1. copts from mojo_toolchain.package_copts
2. copts from //:mojo_package_copt (if not building in exec config)
3. copts from this attribute, with $(location) expanded for files in
   additional_compiler_inputs.

NOTE: copts from --mojocopt and mojo_toolchain.copts are not passed to 'mojo
package' since it does not accept many flags.
""",
        ),
        "srcs": attr.label_list(
            allow_empty = False,
            allow_files = MOJO_EXTENSIONS,
        ),
        "deps": attr.label_list(
            providers = [MojoInfo],
        ),
        "data": attr.label_list(),
        "_mojo_package_copts": attr.label(
            default = Label("//:mojo_package_copt"),
        ),
        "_export_fixits": attr.label(
            default = Label("@rules_mojo//:experimental_export_fixits"),
        ),
    },
    toolchains = ["//:toolchain_type"],
)
