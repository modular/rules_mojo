"""Compile Mojo files into a mojopkg that can be consumed by other Mojo targets."""

load("//mojo:providers.bzl", "MojoInfo")
load("//mojo/private:utils.bzl", "MOJO_EXTENSIONS", "collect_mojoinfo")

def _mojo_library_implementation(ctx):
    mojo_toolchain = ctx.toolchains["//:toolchain_type"].mojo_toolchain_info

    mojo_package = ctx.actions.declare_file(ctx.label.name + ".mojopkg")
    args = ctx.actions.args()
    args.add("package")
    args.add("-strip-file-prefix=.")
    args.add("-o", mojo_package.path)

    import_paths, transitive_mojopkgs = collect_mojoinfo(ctx.attr.deps + mojo_toolchain.implicit_deps)
    root_directory = ctx.files.srcs[0].dirname

    file_args = ctx.actions.args()
    for file in ctx.files.srcs:
        if not file.dirname.startswith(root_directory):
            file_args.add("-I", file.dirname)

    file_args.add_all(import_paths, before_each = "-I")
    file_args.add(root_directory)
    ctx.actions.run(
        executable = mojo_toolchain.mojo,
        inputs = depset(ctx.files.srcs, transitive = [transitive_mojopkgs]),
        tools = mojo_toolchain.all_tools,
        outputs = [mojo_package],
        arguments = [args, file_args],
        mnemonic = "MojoPackage",
        progress_message = "%{label} building mojo package",
        env = {
            "MODULAR_CRASH_REPORTING_ENABLED": "false",
            "TEST_TMPDIR": ".",  # Make sure any cache files are written to somewhere bazel will cleanup
        },
        use_default_shell_env = True,
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
    ]

mojo_library = rule(
    implementation = _mojo_library_implementation,
    attrs = {
        "srcs": attr.label_list(
            allow_empty = False,
            allow_files = MOJO_EXTENSIONS,
        ),
        "deps": attr.label_list(
            providers = [MojoInfo],
        ),
        "data": attr.label_list(),
    },
    toolchains = ["//:toolchain_type"],
)
