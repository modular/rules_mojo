"""Import a precompiled mojo file for use in other Mojo targets."""

load("//mojo:providers.bzl", "MojoInfo")
load("//mojo/private:utils.bzl", "collect_mojoinfo")

def _mojo_import_impl(ctx):
    mojo_deps = ctx.files.mojodeps
    import_paths, transitive_mojodeps, ccdeps = collect_mojoinfo(ctx.attr.deps)
    return [
        DefaultInfo(files = depset(mojo_deps, transitive = [transitive_mojodeps])),
        MojoInfo(
            import_paths = depset(
                [struct(package = pkg, import_path = ".") for pkg in mojo_deps],
                transitive = [import_paths],
            ),
            mojodeps = depset(mojo_deps, transitive = [transitive_mojodeps]),
            ccdeps = ccdeps,
        ),
    ]

mojo_import = rule(
    implementation = _mojo_import_impl,
    attrs = {
        "mojodeps": attr.label_list(
            allow_files = [".mojoc"],
            doc = "The precompiled mojo files to import.",
        ),
        "deps": attr.label_list(
            providers = [MojoInfo],
            doc = "Additional Mojo dependencies required by the imported mojo file.",
        ),
    },
)
