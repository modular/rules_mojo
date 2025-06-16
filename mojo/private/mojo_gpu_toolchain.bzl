"""Bazel toolchain representing the currently targeted GPU hardware"""

load("//mojo:providers.bzl", "MojoGPUToolchainInfo")

def _mojo_gpu_toolchain_impl(ctx):
    brand = ctx.attr.target_accelerator.split(":")[0]
    return [
        platform_common.ToolchainInfo(
            mojo_gpu_toolchain_info = MojoGPUToolchainInfo(
                brand = brand,
                has_4_gpus = ctx.attr.has_4_gpus,
                multi_gpu = ctx.attr.multi_gpu,
                name = ctx.attr.name,
                target_accelerator = ctx.attr.target_accelerator,
            ),
        ),
    ]

mojo_gpu_toolchain = rule(
    implementation = _mojo_gpu_toolchain_impl,
    attrs = {
        "target_accelerator": attr.string(mandatory = True),
        "multi_gpu": attr.bool(mandatory = True),
        "has_4_gpus": attr.bool(mandatory = True),
    },
)
