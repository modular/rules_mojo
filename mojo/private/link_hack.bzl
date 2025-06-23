"""This rule hacks around a private API limitation in bazel by re-using the name of a library that is allowed to access the private API.

https://github.com/bazelbuild/bazel/pull/23838
"""

def _link_hack_impl(rctx):
    rctx.file("BUILD.bazel", "")
    rctx.file("link_hack.bzl", """\
def link_hack(**kwargs):
    return cc_common.link(**kwargs)
""")

link_hack = repository_rule(
    implementation = _link_hack_impl,
)
