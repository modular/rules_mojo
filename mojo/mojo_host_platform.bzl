"""Setup a host platform that takes into account current GPU hardware"""

def _verbose_log(rctx, msg):
    if rctx.getenv("MOJO_VERBOSE_GPU_DETECT"):
        # buildifier: disable=print
        print(msg)

def _log_result(rctx, binary, result):
    _verbose_log(
        rctx,
        "\n------ {}:\nexit status: {}\nstdout: {}\nstderr: {}\n------ end gpu-query info"
            .format(binary, result.return_code, result.stdout, result.stderr),
    )

def _get_amdgpu_constraint(series, gpu_mapping):
    for gpu_name, constraint in gpu_mapping.items():
        if gpu_name in series:
            if constraint:
                return "@mojo_gpu_toolchains//:{}_gpu".format(constraint)
            else:
                return None

    fail("Unrecognized amd-smi/rocm-smi output, please add it to your gpu_mapping in the MODULE.bazel file: {}".format(series))

def _get_rocm_constraint(blob, gpu_mapping):
    for value in blob.values():
        series = value["Card Series"]
        return _get_amdgpu_constraint(series, gpu_mapping)
    fail("Unrecognized rocm-smi output, please report: {}".format(blob))

def _get_amd_constraint(blob, gpu_mapping):
    for value in blob:
        series = value["asic"]["market_name"]
        return _get_amdgpu_constraint(series, gpu_mapping)
    fail("Unrecognized amd-smi output, please report: {}".format(blob))

def _get_nvidia_constraint(lines, gpu_mapping):
    line = lines[0]
    for gpu_name, constraint in gpu_mapping.items():
        if gpu_name in line:
            if constraint:
                return "@mojo_gpu_toolchains//:{}_gpu".format(constraint)
            else:
                return None

    fail("Unrecognized nvidia-smi output, please add it to your gpu_mapping in the MODULE.bazel file: {}".format(lines))

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

                constraint = _get_nvidia_constraint(lines, rctx.attr.gpu_mapping)
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
                constraints.extend([
                    "@mojo_gpu_toolchains//:amd_gpu",
                    "@mojo_gpu_toolchains//:has_gpu",
                ])

                blob = json.decode(result.stdout)
                if len(blob) == 0:
                    fail("amd-smi succeeded but didn't actually have any GPUs, please report this issue")

                constraints.append(_get_amd_constraint(blob, rctx.attr.gpu_mapping))
                if len(blob) > 1:
                    constraints.append("@mojo_gpu_toolchains//:has_multi_gpu")
                if len(blob) >= 4:
                    constraints.append("@mojo_gpu_toolchains//:has_4_gpus")

        elif rocm_smi:
            result = rctx.execute([rocm_smi, "--json", "--showproductname"])
            _log_result(rctx, rocm_smi, result)

            if result.return_code == 0:
                constraints.extend([
                    "@mojo_gpu_toolchains//:amd_gpu",
                    "@mojo_gpu_toolchains//:has_gpu",
                ])

                blob = json.decode(result.stdout)
                if len(blob.keys()) == 0:
                    fail("rocm-smi succeeded but didn't actually have any GPUs, please report this issue")

                constraints.append(_get_rocm_constraint(blob, rctx.attr.gpu_mapping))
                if len(blob.keys()) > 1:
                    constraints.append("@mojo_gpu_toolchains//:has_multi_gpu")
                if len(blob.keys()) >= 4:
                    constraints.append("@mojo_gpu_toolchains//:has_4_gpus")

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
        "MOJO_VERBOSE_GPU_DETECT",
    ],
    attrs = {
        "gpu_mapping": attr.string_dict(),
    },
)
