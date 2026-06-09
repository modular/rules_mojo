"""Helpers internal to rules_mojo."""

load("@bazel_features//:features.bzl", "bazel_features")
load("//mojo:providers.bzl", "MojoInfo")

MOJO_EXTENSIONS = ("mojo",)

def collect_mojoinfo(deps):
    """Get a combined MojoInfo from all the passed dependencies.

    Args:
        deps: A list of dependencies to collect MojoInfo from.

    Returns:
        A single MojoInfo object with the combined data.
    """
    import_paths = []
    mojodeps = []
    for dep in deps:
        if MojoInfo in dep:
            info = dep[MojoInfo]
            mojodeps.append(info.mojodeps)
            import_paths.append(info.import_paths)

    return depset(transitive = import_paths), depset(transitive = mojodeps)

def collect_src_mojoinfo(deps):
    """Collect the source-mode (src_deps) data from the passed dependencies.

    Unlike collect_mojoinfo, this gathers the raw sources and their import
    paths so the consuming target can compile against them directly instead of
    against precompiled .mojoc files.

    Args:
        deps: A list of dependencies to collect MojoInfo from.

    Returns:
        A tuple (src_import_paths, src_mojodeps) where src_import_paths is a
        depset of directory strings and src_mojodeps is a depset of Files.
    """
    src_import_paths = []
    src_mojodeps = []
    for dep in deps:
        if MojoInfo in dep:
            info = dep[MojoInfo]

            # Tolerate MojoInfo producers (e.g. third-party rules) that predate
            # the source-mode fields by treating them as empty.
            src_import_paths.append(getattr(info, "src_import_paths", depset()))
            src_mojodeps.append(getattr(info, "src_mojodeps", depset()))

    return depset(transitive = src_import_paths), depset(transitive = src_mojodeps)

def source_import_path(srcs, root_directory):
    """Compute the -I directory that makes a library importable from source.

    Precompiled mode flattens a library into a single <name>.mojoc and puts the
    directory holding it on the import path, so the unit is always a file. Source
    mode hands the compiler the real tree, where Mojo distinguishes two shapes:

      * a package -- a directory containing __init__.mojo -- is importable when
        its *parent* directory is on the import path, and
      * a flat module -- a single foo.mojo -- is importable when *its own*
        directory is on the import path.

    In both cases the library is imported as its on-disk name, which is expected
    to match ctx.label.name (the same name precompiled mode gives <name>.mojoc).

    Args:
        srcs: The source Files of the library (ctx.files.srcs).
        root_directory: The directory containing the sources (srcs[0].dirname).

    Returns:
        The directory string to pass with -I.
    """
    is_package = any([f.basename == "__init__.mojo" for f in srcs])
    if is_package:
        return root_directory.rsplit("/", 1)[0] if "/" in root_directory else "."
    return root_directory

def is_exec_config(ctx):
    """Determines whether the current configuration is an exec configuration.

    Args:
        ctx: The rule context.

    Returns:
        Whether the current configuration is an exec configuration.
    """

    # TODO: Remove once we drop 9.x
    if bazel_features.rules.is_tool_configuration_public and ctx.configuration.is_tool_configuration():
        return True
    elif ctx.bin_dir.path.endswith("-exec/bin"):  # NOTE: 9.0.0 or <8.7.0 with --experimental_platform_in_output_dir
        return True
    elif "-exec-" in ctx.bin_dir.path:
        return True

    return False
