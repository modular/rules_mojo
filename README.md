# rules_mojo

This repository provides rules for building
[Mojo](https://www.modular.com/mojo) projects using
[Bazel](https://bazel.build).

## Quick setup

Copy the latest `MODULE.bazel` snippet from [the releases
page](https://github.com/modular/rules_mojo/releases).

Currently `rules_mojo` requires `bzlmod` and bazel 8.x or later.

## Example

```bzl
load("@rules_mojo//mojo:mojo_binary.bzl", "mojo_binary")

mojo_binary(
    name = "hello_mojo",
    srcs = ["hello_mojo.mojo"],
)
```

See the [tests](https://github.com/modular/rules_mojo/tree/main/tests)
directory for more examples.

## Tracking `gpu-memory` as a local resource

If you tag tests with `resources:gpu-memory:<N>` and run with a recent
Bazel (8.3+), the resource manager will reject builds that reference
resources it doesn't know about:

```text
Resource gpu-memory is not being tracked by the resource manager.
Available resources are: cpu, memory.
```

To fix this, Bazel needs `--local_extra_resources=gpu-memory=<N>` set
before the resource manager starts. `mojo_host_platform` autodetects
the GPU count and total GPU memory on the host (via `nvidia-smi`,
`amd-smi`, or `rocm-smi`) and writes a `gpu_resources.bazelrc`
fragment exposing both `gpu-memory` and a `gpu-N` resource family
(`gpu-1`, `gpu-2`, `gpu-4`, sized to `floor(total_gpus / N)`) into
its external repo on each fetch. On first fetch it prints the
absolute path:

```text
rules_mojo: detected 4 GPU(s) (327036 MB total). Exposing local
resources: gpu-1=4, gpu-2=2, gpu-4=1, gpu-memory=327036.
Add this line to your .bazelrc once:

  try-import /home/.../external/+mojo+mojo_host_platform/gpu_resources.bazelrc
```

The generated fragment looks like:

```text
build --local_extra_resources=gpu-1=4
test --local_extra_resources=gpu-1=4
build --local_extra_resources=gpu-2=2
test --local_extra_resources=gpu-2=2
build --local_extra_resources=gpu-4=1
test --local_extra_resources=gpu-4=1
build --local_extra_resources=gpu-memory=327036
test --local_extra_resources=gpu-memory=327036
```

The `gpu-N` family follows the same convention used in our internal
test infrastructure: a test that needs N GPUs claims
`resources:gpu-N:0.01`, and the pool size on each host is set to the
number of N-sized groups available, so a 2-GPU machine naturally
won't schedule a `gpu-4` test.

Paste that `try-import` line into your `.bazelrc` once. The fragment
re-runs whenever the host's GPU configuration changes (the rule is
`configure = True`), so the resource pool stays in sync without
further intervention.

Caveats:

- The path is under your Bazel output base, so it will change if you
  point Bazel at a different cache or use a different user account.
  Re-run any `mojo` extension target to see the current path.
- Set `MOJO_QUIET_GPU_RESOURCES=1` to silence the print on each
  fetch.
