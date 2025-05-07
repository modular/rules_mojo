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
