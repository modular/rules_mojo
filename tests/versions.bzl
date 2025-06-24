"""A repo rule to expose constants that have to be hardcoded in the MODULE.bazel to other bzl files."""

def _impl(rctx):
    rctx.file("BUILD.bazel", "")
    rctx.file("config.bzl", """\
PYTHON_VERSIONS = {python_versions}
""".format(
        python_versions = str(rctx.attr.python_versions),
    ))

versions = repository_rule(
    implementation = _impl,
    attrs = {
        "python_versions": attr.string_list(mandatory = True),
    },
)
