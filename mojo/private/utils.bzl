"""Helpers internal to rules_mojo."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("//mojo:providers.bzl", "MojoInfo")

MOJO_EXTENSIONS = ("mojo",)

def collect_mojoinfo(deps):
    """Get a combined MojoInfo from all the passed dependencies.

    Args:
        deps: A list of dependencies to collect MojoInfo and CcInfo from.

    Returns:
        A tuple (imports, mojodeps, ccdeps): `imports` is a depset of
        struct(package, import_path) entries for building -I flags, `mojodeps`
        is a depset of the precompiled mojo Files for action inputs, and
        `ccdeps` is a single merged CcInfo of every cc dependency, both those
        depended on directly and those propagated through MojoInfo, for use in
        final compile and link actions.
    """
    import_paths = []
    mojodeps = []
    cc_infos = []
    for dep in deps:
        if MojoInfo in dep:
            info = dep[MojoInfo]
            mojodeps.append(info.mojodeps)
            import_paths.append(info.import_paths)
            cc_infos.append(info.ccdeps)
        if CcInfo in dep:
            cc_infos.append(dep[CcInfo])

    return (
        depset(transitive = import_paths),
        depset(transitive = mojodeps),
        cc_common.merge_cc_infos(cc_infos = cc_infos),
    )

def format_import(dep):
    return ["-I", paths.normalize(paths.join(dep.package.dirname, dep.import_path))]

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
