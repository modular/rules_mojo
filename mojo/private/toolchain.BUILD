load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_cc//cc:defs.bzl", "cc_import")
load("@rules_mojo//mojo:mojo_import.bzl", "mojo_import")
load("@rules_mojo//mojo:toolchain.bzl", "mojo_toolchain")

_INTERNAL_LIBRARIES = [
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
    )
]

[
    cc_import(
        name = name,
        shared_library = library,
        visibility = ["//visibility:private"],
    )
    for name, library in _INTERNAL_LIBRARIES
]

mojo_import(
    name = "std",
    mojodeps = ["lib/mojo/std.mojoc"],
)

mojo_toolchain(
    name = "mojo_toolchain",
    extra_tools = [lib[1] for lib in _INTERNAL_LIBRARIES],
    implicit_deps = [
        name
        for name, _ in _INTERNAL_LIBRARIES
    ] + ([":std"] if "{INCLUDE_MOJOPKGS}" else []),
    lld = "bin/lld",
    mojo = "bin/mojo",
    visibility = ["//visibility:public"],
)
