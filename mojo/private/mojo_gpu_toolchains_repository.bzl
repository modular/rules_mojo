"""Repository rule for registering Mojo GPU toolchains."""

def _mojo_gpu_toolchains_repository_impl(rctx):
    rctx.file(
        "gpus.bzl",
        """\
load("@rules_mojo//mojo/private:mojo_gpu_toolchain.bzl", "mojo_gpu_toolchain")

SUPPORTED_GPUS = {}

def declare_gpu_toolchains():
    for gpu, target_accelerator in SUPPORTED_GPUS.items():
        mojo_gpu_toolchain(
            name = gpu,
            target_accelerator = target_accelerator,
            multi_gpu = select({{
                "@mojo_gpu_toolchains//:has_multi_gpu": True,
                "//conditions:default": False,
            }}),
            has_4_gpus = select({{
                "@mojo_gpu_toolchains//:has_4_gpus": True,
                "//conditions:default": False,
            }}),
        )

        native.toolchain(
            name = gpu + "_toolchain",
            toolchain_type = "@rules_mojo//:gpu_toolchain_type",
            target_compatible_with = ["@mojo_gpu_toolchains//:{{}}_gpu".format(gpu)],
            toolchain = gpu,
        )
""".format(rctx.attr.supported_gpus),
    )

    rctx.file(
        "BUILD.bazel",
        """\
load(":gpus.bzl", "SUPPORTED_GPUS", "declare_gpu_toolchains")

package(default_visibility = ["//visibility:public"])

constraint_setting(name = "gpu_bool")

constraint_value(
    name = "has_gpu",
    constraint_setting = ":gpu_bool",
)

constraint_setting(name = "multi_gpu_bool")

constraint_value(
    name = "has_multi_gpu",
    constraint_setting = ":multi_gpu_bool",
)

constraint_setting(name = "multi_gpu_4_bool")

constraint_value(
    name = "has_4_gpus",
    constraint_setting = ":multi_gpu_4_bool",
)

constraint_setting(name = "gpu_brand")

constraint_value(
    name = "amd_gpu",
    constraint_setting = ":gpu_brand",
)

constraint_value(
    name = "nvidia_gpu",
    constraint_setting = ":gpu_brand",
)

constraint_setting(name = "gpu_name")

[
    constraint_value(
        name = "{}_gpu".format(gpu),
        constraint_setting = ":gpu_name",
    )
    for gpu in SUPPORTED_GPUS.keys()
]

declare_gpu_toolchains()
""",
    )

mojo_gpu_toolchains_repository = repository_rule(
    implementation = _mojo_gpu_toolchains_repository_impl,
    doc = "A Mojo GPU toolchain repository rule.",
    attrs = {
        "supported_gpus": attr.string_dict(
            doc = "The GPUs supported by this toolchain.",
            mandatory = True,
        ),
    },
)
