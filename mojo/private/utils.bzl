"""Helpers internal to rules_mojo."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("//mojo:providers.bzl", "MojoInfo")

MOJO_EXTENSIONS = ("mojo",)

def collect_mojoinfo(deps):
    """Get a combined MojoInfo from all the passed dependencies.

    Args:
        deps: A list of dependencies to collect MojoInfo and CcInfo from.

    Returns:
        A tuple (imports, mojodeps, ccdeps): `imports` is a depset of
        struct(package, import_path) entries for building -I flags, `mojodeps`
        is a depset of the precompiled mojo Files for action inputs, and
        `ccdeps` is a single merged CcInfo of every cc dependency, both those
        depended on directly and those propagated through MojoInfo, for use in
        final compile and link actions.
    """
    import_paths = []
    mojodeps = []
    cc_infos = []
    for dep in deps:
        if MojoInfo in dep:
            info = dep[MojoInfo]
            mojodeps.append(info.mojodeps)
            import_paths.append(info.import_paths)
            cc_infos.append(info.ccdeps)
        if CcInfo in dep:
            cc_infos.append(dep[CcInfo])

    return (
        depset(transitive = import_paths),
        depset(transitive = mojodeps),
        cc_common.merge_cc_infos(cc_infos = cc_infos),
    )

def format_import(dep):
    return ["-I", paths.normalize(paths.join(dep.package.dirname, dep.import_path))]

def is_exec_config(ctx):
    """Determines whether the current configuration is an exec configuration.

    Args:
        ctx: The rule context.

    Returns:
        Whether the current configuration is an exec configuration.
    """

    # TODO: Remove once we drop 9.x
    if bazel_features.rules.is_tool_configuration_public and ctx.configuration.is_tool_configuration():
        return True
    elif ctx.bin_dir.path.endswith("-exec/bin"):  # NOTE: 9.0.0 or <8.7.0 with --experimental_platform_in_output_dir
        return True
    elif "-exec-" in ctx.bin_dir.path:
        return True

    return False

def _package_relative_label(ctx, label):
    # type: (ctx, string) -> Label
    """Emulate ctx.package_relative_label in Bazel 8

    Can drop this and replace with ctx.package_relative_label once we drop 8.x support.
    """

    if label.startswith(":"):
        # Relative path
        label = "@@" + ctx.label.repo_name + "//" + ctx.label.package + label
    elif label.startswith("//"):
        label = "@@" + ctx.label.repo_name + label
    elif label.startswith("@") and not label.startswith("@@"):
        label = "@" + label
    return Label(label)

def _extract_label(ctx, copt):
    # type: (ctx, string) -> tuple[string, Label]
    """Split a copt into a format string and a label.

    Take something like `--foo=$(location :bar)` and get `:bar` as a label
    This is a minimum working version, there are likely cases that don't work,
    but there are currently no uses for those extra cases.
    """

    start = -1
    labelstart = -1
    labelend = -1
    end = -1

    # Not sure if we should even support all of these.
    for var in ["execpath", "rootpath", "rlocationpath", "location"]:
        start = copt.find("$(" + var)
        if start != -1:
            # Add the "$(" and a space at the end
            labelstart = start + 2 + len(var) + 1
            break
    if start == -1:
        fail("expected one of $(execpath), $(rootpath), $(rlocationpath), or $(location)")
    end = start + copt[start:].find(")")
    if end == -1:
        fail("expected closing )")
    labelend = end
    label_string = copt[labelstart:labelend]
    format_string = copt[:start] + "%s" + copt[end + 1:]

    label = _package_relative_label(ctx, label_string)

    return format_string, label

def _labels_similar(label1, label2):
    """Without the full repo mapping, determine if two labels are close enough to count them as equal.

    Also replacable when `ctx.package_relative_label` is available."""

    if label1.name != label2.name:
        return False
    if label1.package != label2.package:
        return False
    if label1.repo_name not in label2.repo_name and label2.repo_name not in label1.repo_name:
        return False
    return True

def handle_copt(ctx, copt, args):
    # type: (ctx, string, Args) -> None
    """Handles make variable expansion in copts

    This is primarily necessary to support path mapping
    when labels are passed via a copt.

    Args:
        ctx: the context
        copt: the copt
        args: Args object to add to
    """
    if "$(" in copt:
        format_string, label = _extract_label(ctx, copt)
        for input in ctx.attr.additional_compiler_inputs:
            if label != input.label and not _labels_similar(label, input.label):
                continue
            files = input.files.to_list()
            if len(files) != 1:
                fail("expected exactly one file")
            args.add(files[0], format = format_string)
            return
        fail("input {} not found in additional_compiler_inputs".format(label))
    else:
        args.add(copt)
