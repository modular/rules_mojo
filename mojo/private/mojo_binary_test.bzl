"""mojo_binary and mojo_test rule definitions."""

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain", "use_cpp_toolchain")
load("@build_bazel_rules_android//:link_hack.bzl", "link_hack")  # See link_hack.bzl for details
load("@rules_python//python:py_info.bzl", "PyInfo")
load("//mojo:providers.bzl", "MojoInfo")
load(":transitions.bzl", "python_version_transition")
load(":utils.bzl", "MOJO_EXTENSIONS", "collect_mojoinfo")

_PYTHON_TOOLCHAIN_TYPE = "@rules_python//python:toolchain_type"
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
    "linkopts": attr.string_list(
        doc = "Additional options to pass to the linker.",
    ),
    "python_version": attr.string(
        doc = "The version of Python to use for this target and all its dependencies.",
    ),
    "additional_compiler_inputs": attr.label_list(
        allow_files = True,
        doc = """\
Additional files to pass to the compiler command line. Files specified here can
then be used in copts with the $(location) function.
""",
    ),
    "_mojo_copts": attr.label(
        default = Label("//:mojo_copt"),
    ),
}

_TOOLCHAINS = use_cpp_toolchain() + [
    "//:toolchain_type",
    _PYTHON_TOOLCHAIN_TYPE,
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

def _mojo_binary_test_implementation(ctx, *, shared_library = False):
    cc_toolchain = find_cpp_toolchain(ctx)
    mojo_toolchain = ctx.toolchains["//:toolchain_type"].mojo_toolchain_info
    py_toolchain = ctx.toolchains[_PYTHON_TOOLCHAIN_TYPE]

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
    args.add_all([
        ctx.expand_location(copt, targets = ctx.attr.additional_compiler_inputs)
        for copt in ctx.attr.copts
    ])
    if ctx.attr.enable_assertions:
        args.add("-D", "ASSERT=all")

    ctx.actions.run(
        executable = mojo_toolchain.mojo,
        tools = mojo_toolchain.all_tools,
        inputs = depset(ctx.files.srcs + ctx.files.additional_compiler_inputs, transitive = [transitive_mojopkgs]),
        outputs = [object_file],
        arguments = [args],
        mnemonic = "MojoCompile",
        progress_message = "%{label} compiling mojo object",
        env = {
            "MODULAR_CRASH_REPORTING_ENABLED": "false",
            "MODULAR_MOJO_MAX_COMPILERRT_PATH": "/dev/null",  # Make sure this fails if accessed
            "MODULAR_MOJO_MAX_LINKER_DRIVER": "/dev/null",  # Make sure this fails if accessed
            "MODULAR_MOJO_MAX_LLD_PATH": mojo_toolchain.lld.path,
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

    link_kwargs = {}
    if shared_library:
        link_kwargs["output_type"] = "dynamic_library"
        if ctx.attr.shared_lib_name:
            link_kwargs["main_output"] = ctx.actions.declare_file(ctx.attr.shared_lib_name)  # Only set if name is not using the default logic

    linking_outputs = link_hack(
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        linking_contexts = [object_linking_context] + [dep[CcInfo].linking_context for dep in (ctx.attr.deps + mojo_toolchain.implicit_deps) if CcInfo in dep],
        name = ctx.label.name,
        user_link_flags = ctx.attr.linkopts,
        **link_kwargs
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
    transitive_libraries = []
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
                    transitive_libraries.append(depset([library]))
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

    default_path = ctx.attr.env.get("PATH") or ctx.configuration.default_shell_env.get("PATH") or "/usr/bin:/bin:/usr/sbin"
    runtime_env = dict(ctx.attr.env) | {
        "MODULAR_PYTHON_EXECUTABLE": py_toolchain.py3_runtime.interpreter.short_path,
        "MOJO_PYTHON": py_toolchain.py3_runtime.interpreter.short_path,
        "MOJO_PYTHON_LIBRARY": libpython,
        "PATH": paths.dirname(py_toolchain.py3_runtime.interpreter.short_path) + ":" + default_path,  # python < 3.11 doesn't set sys.executable correctly when Py_Initialize is called unless it's in the $PATH
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

    if shared_library:
        return [
            DefaultInfo(
                executable = linking_outputs.library_to_link.resolved_symlink_dynamic_library,
                runfiles = runfiles.merge_all(transitive_runfiles),
            ),
            PyInfo(
                imports = depset(["_main/" + paths.dirname(linking_outputs.library_to_link.dynamic_library.short_path)]),
                transitive_sources = depset([linking_outputs.library_to_link.dynamic_library]),
            ),
            CcInfo(
                linking_context = cc_common.create_linking_context(
                    linker_inputs = depset([
                        cc_common.create_linker_input(
                            owner = ctx.label,
                            libraries = depset(
                                [linking_outputs.library_to_link],
                                transitive = transitive_libraries,
                            ),
                        ),
                    ]),
                ),
            ),
        ]
    else:
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
    implementation = lambda ctx: _mojo_binary_test_implementation(ctx),
    attrs = _ATTRS,
    toolchains = _TOOLCHAINS,
    fragments = ["cpp"],
    executable = True,
)

mojo_test = rule(
    implementation = lambda ctx: _mojo_binary_test_implementation(ctx),
    attrs = _ATTRS,
    toolchains = _TOOLCHAINS,
    fragments = ["cpp"],
    test = True,
    cfg = python_version_transition,
)

mojo_shared_library = rule(
    implementation = lambda ctx: _mojo_binary_test_implementation(ctx, shared_library = True),
    attrs = _ATTRS | {
        "shared_lib_name": attr.string(
            doc = "The name of the shared library to be created.",
        ),
    },
    toolchains = _TOOLCHAINS,
    fragments = ["cpp"],
)
