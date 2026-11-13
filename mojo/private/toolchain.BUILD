load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_cc//cc:defs.bzl", "cc_import")
load("@rules_mojo//mojo:mojo_import.bzl", "mojo_import")
load("@rules_mojo//mojo:toolchain.bzl", "mojo_toolchain")

_COMPILER_LIBRARIES = [
    (
        paths.split_extension(library)[0],
        library,
    )
    for library in glob(
        [
            # Globbed to allow .so or .dylib
            "lib/libAsyncRTRuntimeGlobals.*",
            "lib/libMSupportGlobals.*",
        ],
        allow_empty = False,
    ) + glob(
        # Only used in Mojo 1.3+
        [
            "lib/libLLVMSupport.*",
            "lib/libLLVM.*",
            "lib/libMLIR.*",
            "lib/MDriverCompilation.*",
            "lib/libclangBasic.*",
        ],
        allow_empty = True,
    )
]

_RUNTIME_LIBRARIES = [
    (
        paths.split_extension(library)[0],
        library,
    )
    for library in glob(
        [
            # Globbed to allow .so or .dylib
            "lib/libAsyncRTRuntimeGlobals.*",
            "lib/libKGENCompilerRTShared.*",
            "lib/libMSupportGlobals.*",
        ],
        allow_empty = False,
    ) + glob(
        # Only used in Mojo 1.3+
        [
            "lib/libLLVMSupport.*",
        ],
        allow_empty = True,
    )
]

[
    cc_import(
        name = name,
        shared_library = library,
        visibility = ["//visibility:private"],
    )
    for name, library in set(_RUNTIME_LIBRARIES + _COMPILER_LIBRARIES)
]

mojo_import(
    name = "std",
    mojodeps = ["lib/mojo/std.mojoc"],
)

mojo_toolchain(
    name = "mojo_toolchain",
    extra_tools = [lib[1] for lib in _COMPILER_LIBRARIES],
    implicit_deps = [
        name
        for name, _ in _RUNTIME_LIBRARIES
    ] + ([":std"] if "{INCLUDE_MOJOPKGS}" else []),
    lld = "bin/lld",
    mojo = "bin/mojo",
    visibility = ["//visibility:public"],
)
