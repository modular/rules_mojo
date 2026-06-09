"""Import a precompiled mojo file for use in other Mojo targets."""

load("//mojo:providers.bzl", "MojoInfo")
load("//mojo/private:utils.bzl", "collect_mojoinfo", "collect_src_mojoinfo")

def _mojo_import_impl(ctx):
    mojo_deps = ctx.files.mojodeps
    import_paths, transitive_mojodeps = collect_mojoinfo(ctx.attr.deps)
    src_import_paths, src_mojodeps = collect_src_mojoinfo(ctx.attr.deps)
    return [
        DefaultInfo(files = depset(mojo_deps, transitive = [transitive_mojodeps])),
        MojoInfo(
            import_paths = depset([pkg.dirname for pkg in mojo_deps], transitive = [import_paths]),
            mojodeps = depset([pkg for pkg in mojo_deps], transitive = [transitive_mojodeps]),
            # A precompiled import has no sources, so source-mode consumers fall
            # back to its .mojoc files and their directories.
            src_import_paths = depset([pkg.dirname for pkg in mojo_deps], transitive = [src_import_paths]),
            src_mojodeps = depset(mojo_deps, transitive = [src_mojodeps]),
        ),
    ]

mojo_import = rule(
    implementation = _mojo_import_impl,
    attrs = {
        "mojodeps": attr.label_list(
            allow_files = [".mojopkg", ".mojoc"],
            doc = "The precompiled mojo files to import.",
        ),
        "deps": attr.label_list(
            providers = [MojoInfo],
            doc = "Additional Mojo dependencies required by the imported mojo file.",
        ),
    },
)
