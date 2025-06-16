"""Mojo related providers."""

MojoInfo = provider(
    doc = "Information about how to build a Mojo target.",
    fields = {
        "import_paths": "Directories that should be passed with -I to mojo",
        "mojopkgs": "The mojopkg files required by the target",
    },
)

MojoToolchainInfo = provider(
    doc = "Provider holding the tools for building Mojo targets.",
    fields = {
        "all_tools": "All the files that must be available in actions in order for the toolchain to work.",
        "copts": "Additional compiler options to pass to the Mojo compiler.",
        "lld": "The lld compiler executable to link with",
        "mojo": "The mojo compiler executable to build with",
        "implicit_deps": "Implicit dependencies that every target should depend on, providing either CcInfo, or MojoInfo",
    },
)

MojoGPUToolchainInfo = provider(
    doc = "Provider holding information about the GPU being targeted by Mojo.",
    fields = {
        "brand": "The brand of the GPU, e.g., 'amd', 'nvidia'",
        "has_4_gpus": "Whether the target supports at least 4 GPUs",
        "multi_gpu": "Whether the target supports multiple GPUs",
        "name": "The name of the GPU, e.g., 'a100', 'mi325'",
        "target_accelerator": "The target accelerator, e.g., '90a', 'gfx942', can be passed to the Mojo compiler",
    },
)
