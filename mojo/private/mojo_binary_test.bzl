"""mojo_binary and mojo_test rule definitions."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain", "use_cpp_toolchain")
load("@rules_python//python:py_info.bzl", "PyInfo")
load("//mojo:providers.bzl", "MojoInfo")
load(":utils.bzl", "MOJO_EXTENSIONS", "collect_mojoinfo")

_ATTRS = {
    "srcs": attr.label_list(
        allow_files = MOJO_EXTENSIONS,
    ),
    "main": attr.label(
        allow_single_file = MOJO_EXTENSIONS,
        doc = "The main Mojo source file for the target, used to disambiguate when multiple files are passed to srcs.",
    ),
    "copts": attr.string_list(),
    "deps": attr.label_list(
        providers = [[CcInfo], [MojoInfo], [PyInfo]],
    ),
    "data": attr.label_list(allow_files = True),
    "enable_assertions": attr.bool(default = True),
    "env": attr.string_dict(),
    "_mojo_copts": attr.label(
        default = Label("//:mojo_copt"),
    ),
}

_TOOLCHAINS = use_cpp_toolchain() + [
    "//:toolchain_type",
    "@bazel_tools//tools/python:toolchain_type",
]

def _find_main(name, srcs, main):
    """Finds the main source file from the list of srcs and the main attribute."""
    if main:
        if main not in srcs:
            fail("Main file not found in srcs. Please add '{}' to 'srcs'.".format(main.path))
        return main

    if len(srcs) == 1:
        return srcs[0]

    files_matching_name = []
    main_files = []
    for src in srcs:
        filename_without_extension = paths.split_extension(src.basename)[0]
        if filename_without_extension == name:
            files_matching_name.append(src)
        if filename_without_extension == "main":
            main_files.append(src)
    if len(files_matching_name) == 1:
        return files_matching_name[0]
    if len(main_files) == 1:
        return main_files[0]

    fail("Multiple Mojo files provided, but no main file specified. Please set 'main = \"foo.mojo\"' to disambiguate.")

def _mojo_binary_test_implementation(ctx):
    cc_toolchain = find_cpp_toolchain(ctx)
    mojo_toolchain = ctx.toolchains["//:toolchain_type"].mojo_toolchain_info
    py_toolchain = ctx.toolchains["@bazel_tools//tools/python:toolchain_type"]

    object_file = ctx.actions.declare_file(ctx.label.name + ".lo")
    args = ctx.actions.args()
    args.add("build")
    args.add("-strip-file-prefix=.")
    args.add("--emit", "object")
    args.add("-o", object_file.path)

    main = _find_main(ctx.label.name, ctx.files.srcs, ctx.file.main)
    args.add(main.path)
    root_directory = main.dirname
    for file in ctx.files.srcs:
        if not file.dirname.startswith(root_directory):
            args.add("-I", file.dirname)

    import_paths, transitive_mojopkgs = collect_mojoinfo(ctx.attr.deps + mojo_toolchain.implicit_deps)
    args.add_all(import_paths, before_each = "-I")

    # NOTE: Argument order:
    # 1. Basic functional arguments
    # 2. Mojo toolchain arguments
    # 3. --mojocopt arguments
    # 4. copts = [] arguments
    # 5. Attribute enabled arguments
    args.add_all(mojo_toolchain.copts)

    # Ignore default mojo flags for exec built binaries
    if "-exec-" not in ctx.bin_dir.path:
        args.add_all(ctx.attr._mojo_copts[BuildSettingInfo].value)
    args.add_all(ctx.attr.copts)
    if ctx.attr.enable_assertions:
        args.add("-D", "ASSERT=all")

    ctx.actions.run(
        executable = mojo_toolchain.mojo,
        tools = mojo_toolchain.all_tools,
        inputs = depset(ctx.files.srcs, transitive = [transitive_mojopkgs]),
        outputs = [object_file],
        arguments = [args],
        mnemonic = "MojoCompile",
        progress_message = "%{label} compiling mojo object",
        env = {
            "MODULAR_CRASH_REPORTING_ENABLED": "false",
            "MODULAR_MOJO_MAX_COMPILERRT_PATH": "/dev/null",  # Make sure this fails if accessed
            "MODULAR_MOJO_MAX_LINKER_DRIVER": "/dev/null",  # Make sure this fails if accessed
            "MODULAR_MOJO_MAX_LLD_PATH": mojo_toolchain.lld.path,
            "MODULAR_MOJO_MAX_ORCRT_PATH": "/dev/null",  # Make sure this fails if accessed
            "TEST_TMPDIR": ".",
        },
        use_default_shell_env = True,
        toolchain = "//:toolchain_type",
    )

    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    object_linking_context = cc_common.create_linking_context(
        linker_inputs = depset([cc_common.create_linker_input(
            owner = ctx.label,
            libraries = depset([
                cc_common.create_library_to_link(
                    actions = ctx.actions,
                    pic_static_library = object_file,
                    alwayslink = True,
                ),
            ]),
        )]),
    )
    linking_outputs = cc_common.link(
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        linking_contexts = [object_linking_context] + [dep[CcInfo].linking_context for dep in (ctx.attr.deps + mojo_toolchain.implicit_deps) if CcInfo in dep],
        name = ctx.label.name,
    )

    data = ctx.attr.data
    runfiles = ctx.runfiles(ctx.files.data)
    transitive_runfiles = [
        ctx.runfiles(transitive_files = py_toolchain.py3_runtime.files),
    ]
    for target in data:
        transitive_runfiles.append(target[DefaultInfo].default_runfiles)

    # Collect transitive shared libraries that must exist at runtime
    python_imports = []
    for target in ctx.attr.deps + mojo_toolchain.implicit_deps:
        transitive_runfiles.append(target[DefaultInfo].default_runfiles)

        if PyInfo in target:
            python_imports.append(target[PyInfo].imports)
            transitive_runfiles.append(
                ctx.runfiles(transitive_files = target[PyInfo].transitive_sources),
            )

        if CcInfo not in target:
            continue
        for linker_input in target[CcInfo].linking_context.linker_inputs.to_list():
            for library in linker_input.libraries:
                if library.dynamic_library and not library.pic_static_library and not library.static_library:
                    transitive_runfiles.append(ctx.runfiles(transitive_files = depset([library.dynamic_library])))

    python_path = ""
    for path in depset(transitive = python_imports).to_list():
        python_path += "../" + path + ":"

    # https://github.com/bazelbuild/rules_python/issues/2262
    libpython = None
    for file in py_toolchain.py3_runtime.files.to_list():
        if file.basename.startswith("libpython"):
            libpython = file.short_path
            break  # if there are multiple any of them should work and they are likely symlinks to each other

    if not libpython:
        fail("failed to find libpython, please report this at https://github.com/modular/rules_mojo/issues")

    runtime_env = dict(ctx.attr.env) | {
        "MODULAR_PYTHON_EXECUTABLE": py_toolchain.py3_runtime.interpreter.short_path,
        "MOJO_PYTHON": py_toolchain.py3_runtime.interpreter.short_path,
        "MOJO_PYTHON_LIBRARY": libpython,
        "PYTHONEXECUTABLE": py_toolchain.py3_runtime.interpreter.short_path,
        "PYTHONNOUSERSITE": "affirmative",
        "PYTHONPATH": python_path,
        "PYTHONSAFEPATH": "affirmative",
    }
    for key, value in runtime_env.items():
        runtime_env[key] = ctx.expand_make_variables(
            "env",
            ctx.expand_location(value, targets = data),
            {},
        )

    return [
        DefaultInfo(
            executable = linking_outputs.executable,
            runfiles = runfiles.merge_all(transitive_runfiles),
        ),
        RunEnvironmentInfo(
            environment = runtime_env,
        ),
    ]

mojo_binary = rule(
    implementation = _mojo_binary_test_implementation,
    attrs = _ATTRS,
    toolchains = _TOOLCHAINS,
    fragments = ["cpp"],
    executable = True,
)

mojo_test = rule(
    implementation = _mojo_binary_test_implementation,
    attrs = _ATTRS,
    toolchains = _TOOLCHAINS,
    fragments = ["cpp"],
    test = True,
)
