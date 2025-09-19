"""Helpers internal to rules_mojo."""

load("//mojo:providers.bzl", "MojoInfo")

MOJO_EXTENSIONS = ("mojo", "🔥")

def collect_mojoinfo(deps):
    import_paths = []
    mojopkgs = []
    for dep in deps:
        if MojoInfo in dep:
            info = dep[MojoInfo]
            mojopkgs.append(info.mojopkgs)
            import_paths.append(info.import_paths)

    return depset(transitive = import_paths), depset(transitive = mojopkgs)
