# rules_mojo

This repository provides [Bazel](https://bazel.build) rules for building
[Mojo](https://www.modular.com/mojo) projects.

## Requirements

`rules_mojo` requires Bzlmod and Bazel 8 or later.

## Example

In `MODULE.bazel`, replace `<rules_mojo_version>` with a published version from
the [Bazel Central Registry](https://registry.bazel.build/modules/rules_mojo) and
`<mojo_version>` with the Mojo version you want to use:

```bzl
bazel_dep(name = "rules_mojo", version = "<rules_mojo_version>")

mojo = use_extension("@rules_mojo//mojo:extensions.bzl", "mojo")
mojo.toolchain(version = "<mojo_version>")
```

Omit `version` from `mojo.toolchain()` to use the default Mojo toolchain. See the
[toolchain definitions](mojo/extensions.bzl) for the default version and pinned
releases. Unlisted nightly versions are downloaded without pinned checksums.

Then define a `mojo_binary` target in `BUILD.bazel`:

```bzl
load("@rules_mojo//mojo:mojo_binary.bzl", "mojo_binary")

mojo_binary(
    name = "hello_mojo",
    srcs = ["hello_mojo.mojo"],
)
```

See the [tests](tests) directory for more examples.
