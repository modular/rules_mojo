"""Helpers internal to rules_mojo."""

load("@bazel_features//:features.bzl", "bazel_features")
load("//mojo:providers.bzl", "MojoInfo")

MOJO_EXTENSIONS = ("mojo", "🔥")

def collect_mojoinfo(deps):
    """Get a combined MojoInfo from all the passed dependencies.

    Args:
        deps: A list of dependencies to collect MojoInfo from.

    Returns:
        A single MojoInfo object with the combined data.
    """
    import_paths = []
    mojopkgs = []
    for dep in deps:
        if MojoInfo in dep:
            info = dep[MojoInfo]
            mojopkgs.append(info.mojopkgs)
            import_paths.append(info.import_paths)

    return depset(transitive = import_paths), depset(transitive = mojopkgs)

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
