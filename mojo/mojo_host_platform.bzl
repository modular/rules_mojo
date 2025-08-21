"""Setup a host platform that takes into account current GPU hardware"""

def _verbose_log(rctx, msg):
    if rctx.getenv("MOJO_VERBOSE_GPU_DETECT"):
        # buildifier: disable=print
        print(msg)

def _log_result(rctx, binary, result):
    _verbose_log(
        rctx,
        "\n------ {binary}:\nexit status: {exit_status}\nstdout: {stdout}\nstderr: {stderr}\n------ end {binary} info"
            .format(
            binary = binary,
            exit_status = result.return_code,
            stdout = result.stdout,
            stderr = result.stderr,
        ),
    )

def _fail(rctx, msg):
    if rctx.getenv("MOJO_IGNORE_UNKNOWN_GPUS") == "1":
        # buildifier: disable=print
        print("WARNING: ignoring unknown GPU, to support it, add it to the gpu_mapping in the MODULE.bazel: {}".format(msg))
    else:
        fail(msg)

def _get_amdgpu_constraint(rctx, series, gpu_mapping):
    for gpu_name, constraint in gpu_mapping.items():
        if gpu_name in series:
            if constraint:
                return "@mojo_gpu_toolchains//:{}_gpu".format(constraint)
            else:
                return None

    _fail(rctx, "Unrecognized amd-smi/rocm-smi output, please add it to your gpu_mapping in the MODULE.bazel file: {}".format(series))
    return None

def _get_rocm_constraint(rctx, blob, gpu_mapping):
    for value in blob.values():
        series = value["Card Series"]
        return _get_amdgpu_constraint(rctx, series, gpu_mapping)
    fail("Unrecognized rocm-smi output, please report: {}".format(blob))

def _get_amd_constraint(rctx, blob, gpu_mapping):
    if "gpu_data" in blob:
        blob = blob["gpu_data"]
    for value in blob:
        series = value["board"]["product_name"]
        return _get_amdgpu_constraint(rctx, series, gpu_mapping)
    fail("Unrecognized amd-smi output, please report: {}".format(blob))

def _get_nvidia_constraint(rctx, lines, gpu_mapping):
    line = lines[0]
    for gpu_name, constraint in gpu_mapping.items():
        if gpu_name in line:
            if constraint:
                return "@mojo_gpu_toolchains//:{}_gpu".format(constraint)
            else:
                return None

    _fail(rctx, "Unrecognized nvidia-smi output, please add it to your gpu_mapping in the MODULE.bazel file: {}".format(lines))
    return None

def _get_amd_constraints_with_rocm_smi(rctx, rocm_smi, gpu_mapping):
    if not rocm_smi:
        return []

    result = rctx.execute([rocm_smi, "--json", "--showproductname"])
    _log_result(rctx, rocm_smi, result)

    constraints = []
    if result.return_code == 0:
        blob = json.decode(result.stdout)
        if len(blob.keys()) == 0:
            fail("rocm-smi succeeded but didn't actually have any GPUs, please report this issue")

        rocm_constraint = _get_rocm_constraint(rctx, blob, gpu_mapping)
        if rocm_constraint:
            constraints.extend([
                rocm_constraint,
                "@mojo_gpu_toolchains//:amd_gpu",
                "@mojo_gpu_toolchains//:has_gpu",
            ])

            if len(blob.keys()) > 1:
                constraints.append("@mojo_gpu_toolchains//:has_multi_gpu")
            if len(blob.keys()) >= 4:
                constraints.append("@mojo_gpu_toolchains//:has_4_gpus")

    return constraints

def _get_apple_constraint(rctx, gpu_mapping):
    result = rctx.execute(["/usr/sbin/system_profiler", "SPDisplaysDataType"])
    if result.return_code != 0:
        return None  # TODO: Should we fail instead?

    _log_result(rctx, "/usr/sbin/system_profiler SPDisplaysDataType", result)

    chipset = None
    for line in result.stdout.splitlines():
        if "Chipset Model" in line:
            chipset = line
            break

    if not chipset:  # macOS VMs may not have GPUs attached
        return None

    for gpu_name, constraint in gpu_mapping.items():
        if gpu_name in chipset:
            if constraint:
                return "@mojo_gpu_toolchains//:{}_gpu".format(constraint)
            else:
                return None

    _fail(rctx, "Unrecognized system_profiler output, please add it to your gpu_mapping in the MODULE.bazel file: {}".format(result.stdout))
    return None

def _impl(rctx):
    constraints = []

    if rctx.os.name == "linux" and rctx.os.arch == "amd64":
        # A system may have both rocm-smi and nvidia-smi installed, check both.
        nvidia_smi = rctx.which("nvidia-smi")

        # amd-smi supersedes rocm-smi
        amd_smi = rctx.which("amd-smi")
        rocm_smi = rctx.which("rocm-smi")

        _verbose_log(rctx, "nvidia-smi path: {}, rocm-smi path: {}, amd-smi path: {}".format(nvidia_smi, rocm_smi, amd_smi))

        # NVIDIA
        if nvidia_smi:
            result = rctx.execute([nvidia_smi, "--query-gpu=gpu_name", "--format=csv,noheader"])
            _log_result(rctx, nvidia_smi, result)
            if result.return_code == 0:
                lines = result.stdout.splitlines()
                if len(lines) == 0:
                    fail("nvidia-smi succeeded but had no GPUs, please report this issue")

                constraint = _get_nvidia_constraint(rctx, lines, rctx.attr.gpu_mapping)
                if constraint:
                    constraints.extend([
                        "@mojo_gpu_toolchains//:nvidia_gpu",
                        "@mojo_gpu_toolchains//:has_gpu",
                        constraint,
                    ])

                    if len(lines) > 1:
                        constraints.append("@mojo_gpu_toolchains//:has_multi_gpu")
                    if len(lines) >= 4:
                        constraints.append("@mojo_gpu_toolchains//:has_4_gpus")

        # AMD
        if amd_smi:
            result = rctx.execute([amd_smi, "static", "--json"])
            _log_result(rctx, amd_smi, result)

            if result.return_code == 0:
                blob = json.decode(result.stdout)
                if len(blob) == 0:
                    fail("amd-smi succeeded but didn't actually have any GPUs, please report this issue")

                amd_constraint = _get_amd_constraint(rctx, blob, rctx.attr.gpu_mapping)
                if amd_constraint:
                    constraints.extend([
                        amd_constraint,
                        "@mojo_gpu_toolchains//:amd_gpu",
                        "@mojo_gpu_toolchains//:has_gpu",
                    ])

                    if len(blob) > 1:
                        constraints.append("@mojo_gpu_toolchains//:has_multi_gpu")
                    if len(blob) >= 4:
                        constraints.append("@mojo_gpu_toolchains//:has_4_gpus")
            else:
                # amd-smi can fail when rocm-smi succeeds, fallback accordingly
                constraints.extend(_get_amd_constraints_with_rocm_smi(rctx, rocm_smi, rctx.attr.gpu_mapping))

        else:
            constraints.extend(_get_amd_constraints_with_rocm_smi(rctx, rocm_smi, rctx.attr.gpu_mapping))

    elif rctx.os.name == "mac os x" and rctx.os.arch == "aarch64":
        apple_constraint = _get_apple_constraint(rctx, rctx.attr.gpu_mapping)
        if apple_constraint:
            constraints.extend([
                apple_constraint,
                "@mojo_gpu_toolchains//:apple_gpu",
            ])
            if rctx.getenv("MOJO_ENABLE_HAS_GPU_FOR_APPLE"):
                constraints.append("@mojo_gpu_toolchains//:has_gpu")

    rctx.file("WORKSPACE.bazel", "workspace(name = {})".format(rctx.attr.name))
    rctx.file("BUILD.bazel", """
platform(
    name = "mojo_host_platform",
    parents = ["@platforms//host"],
    visibility = ["//visibility:public"],
    constraint_values = [{constraints}],
    exec_properties = {{
        "no-remote-exec": "1",
    }},
)
""".format(constraints = ", ".join(['"{}"'.format(x) for x in constraints])))

mojo_host_platform = repository_rule(
    implementation = _impl,
    configure = True,
    environ = [
        "MOJO_ENABLE_HAS_GPU_FOR_APPLE",  # NOTE: Will likely be removed in the future
        "MOJO_IGNORE_UNKNOWN_GPUS",
        "MOJO_VERBOSE_GPU_DETECT",
    ],
    attrs = {
        "gpu_mapping": attr.string_dict(
            doc = "A dictionary of GPU strings from nvidia-smi or amd-smi, mapped to supported GPUs defined by mojo.gpu_toolchains()",
        ),
    },
)
