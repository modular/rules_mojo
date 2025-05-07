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
            "lib/libAsyncRTMojoBindings.*",
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
    name = "all_mojopkgs",
    mojopkgs = glob(
        ["lib/mojo/**/*.mojopkg"],
        allow_empty = False,
    ),
)

mojo_toolchain(
    name = "mojo_toolchain",
    implicit_deps = [
        name
        for name, _ in _INTERNAL_LIBRARIES
    ] + ([":all_mojopkgs"] if "{INCLUDE_MOJOPKGS}" else []),
    lld = "bin/lld",
    mojo = "bin/mojo",
    visibility = ["//visibility:public"],
)
