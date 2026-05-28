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
    if result.return_code == 0 and len(result.stdout) > 0: #len(result.stdout) == 0 when the driver is not initialized
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

def _toolchain_supports_metal4(rctx):
    result = rctx.execute(["/usr/bin/xcrun", "--sdk", "macosx", "--show-sdk-version"])
    _log_result(rctx, "/usr/bin/xcrun --sdk macosx --show-sdk-version", result)
    if result.return_code != 0:
        return False
    return int(result.stdout.strip().split(".")[0]) >= 26

def _detect_nvidia_memory(rctx, nvidia_smi):
    """Returns (gpu_count, total_memory_mb)."""
    result = rctx.execute([nvidia_smi, "--query-gpu=memory.total", "--format=csv,noheader,nounits"])
    _log_result(rctx, "{} memory.total".format(nvidia_smi), result)
    if result.return_code != 0:
        return 0, 0
    count = 0
    total = 0
    for line in result.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        total += int(line)
        count += 1
    return count, total

def _detect_amd_smi_memory(rctx, amd_smi):
    """Returns (gpu_count, total_memory_mb)."""
    result = rctx.execute([amd_smi, "static", "--vram", "--json"])
    _log_result(rctx, "{} static --vram".format(amd_smi), result)
    if result.return_code != 0:
        return 0, 0
    json_lines = []
    for line in result.stdout.splitlines():
        if line.startswith("WARNING:"):
            continue
        json_lines.append(line)
    blob = json.decode("\n".join(json_lines), default = None)
    if blob == None:
        return 0, 0
    if type(blob) == "dict" and "gpu_data" in blob:
        blob = blob["gpu_data"]
    count = 0
    total = 0
    for entry in blob:
        count += 1
        vram = entry.get("vram", {})
        size = vram.get("size", {})
        value = size.get("value")
        unit = size.get("unit", "MB")
        if value == None:
            continue
        # Normalize to MB
        if unit == "GB":
            total += int(value) * 1024
        elif unit == "KB":
            total += int(value) // 1024
        elif unit == "B":
            total += int(value) // (1024 * 1024)
        else:  # MB or unknown
            total += int(value)
    return count, total

def _detect_rocm_smi_memory(rctx, rocm_smi):
    """Returns (gpu_count, total_memory_mb)."""
    result = rctx.execute([rocm_smi, "--showmeminfo", "vram", "--json"])
    _log_result(rctx, "{} --showmeminfo vram".format(rocm_smi), result)
    if result.return_code != 0 or not result.stdout:
        return 0, 0
    blob = json.decode(result.stdout, default = None)
    if blob == None:
        return 0, 0
    count = 0
    total = 0
    for value in blob.values():
        count += 1
        # Field name varies across rocm-smi versions:
        #   "VRAM Total Memory (B)" (bytes), or "VRAM Total Memory (MiB)".
        for key, raw in value.items():
            if "VRAM Total Memory" not in key:
                continue
            raw_str = str(raw).strip()
            if not raw_str.isdigit():
                continue
            num = int(raw_str)
            if "(B)" in key:
                total += num // (1024 * 1024)
            elif "MiB" in key or "MB" in key:
                total += num
            elif "GiB" in key or "GB" in key:
                total += num * 1024
    return count, total

_GPU_COUNT_BUCKETS = [1, 2, 4]

def _write_gpu_resources_bazelrc(rctx, gpu_count, total_mb):
    # Mirrors the modular monorepo convention in bazel/internal/remote_run.py:
    # a test that needs N GPUs claims `resources:gpu-N:0.01`. Each `gpu-N`
    # resource pool is sized to floor(total_gpus / N) so the convention works
    # naturally on smaller hosts (a 2-GPU box gets gpu-1=2, gpu-2=1, no gpu-4).
    lines = [
        "# Generated by @rules_mojo//mojo:mojo_host_platform.bzl.",
        "# Detected {} GPU(s), {} MB total memory.".format(gpu_count, total_mb),
    ]
    emitted_gpu_buckets = []
    for n in _GPU_COUNT_BUCKETS:
        pool = gpu_count // n
        if pool <= 0:
            continue
        emitted_gpu_buckets.append("gpu-{}={}".format(n, pool))
        lines.append("build --local_extra_resources=gpu-{}={}".format(n, pool))
        lines.append("test --local_extra_resources=gpu-{}={}".format(n, pool))
    if total_mb > 0:
        lines.append("build --local_extra_resources=gpu-memory={}".format(total_mb))
        lines.append("test --local_extra_resources=gpu-memory={}".format(total_mb))
    rctx.file("gpu_resources.bazelrc", content = "\n".join(lines) + "\n")
    abs_path = rctx.path("gpu_resources.bazelrc")
    if rctx.getenv("MOJO_QUIET_GPU_RESOURCES") != "1":
        summary = ", ".join(emitted_gpu_buckets + (["gpu-memory={}".format(total_mb)] if total_mb > 0 else []))
        # buildifier: disable=print
        print(
            "rules_mojo: detected {} GPU(s) ({} MB total). ".format(gpu_count, total_mb) +
            "Exposing local resources: {}.\n".format(summary) +
            "Add this line to your .bazelrc once:\n\n" +
            "  try-import {}\n\n".format(abs_path) +
            "Silence this message with MOJO_QUIET_GPU_RESOURCES=1.",
        )

def _get_apple_constraint(rctx, gpu_mapping):
    result = rctx.execute(["/usr/bin/sw_vers", "--productVersion"])
    _log_result(rctx, "/usr/sbin/sw_vers --productVersion", result)
    if result.return_code != 0:
        fail("sw_vers failed, please report this issue: {}".format(result.stderr))
    major_version = int(result.stdout.split(".")[0])
    if major_version < 15:
        return None  # Metal < 3.2 is not supported

    result = rctx.execute(["/usr/sbin/system_profiler", "SPDisplaysDataType"])
    if result.return_code != 0:
        return None  # TODO: Should we fail instead?

    _log_result(rctx, "/usr/sbin/system_profiler SPDisplaysDataType", result)

    chipset_model = None
    metal_support = None
    for line in result.stdout.splitlines():
        if "Chipset Model:" in line:
            chipset_model = line
        elif "Metal Support:" in line:
            metal_support = line

    if not chipset_model:  # macOS VMs may not have GPUs attached
        return None

    metal4 = (
        metal_support and "Metal 4" in metal_support and
        _toolchain_supports_metal4(rctx)
    )

    for gpu_name, constraint in gpu_mapping.items():
        if gpu_name in chipset_model:
            if not constraint:
                return None
            if metal4:
                constraint += "_metal4"
            return "@mojo_gpu_toolchains//:{}_gpu".format(constraint)

    _fail(rctx, "Unrecognized system_profiler output, please add it to your gpu_mapping in the MODULE.bazel file: {}".format(result.stdout))
    return None

def _impl(rctx):
    constraints = []
    total_gpu_count = 0
    total_gpu_memory_mb = 0

    if rctx.os.name == "linux" and (rctx.os.arch == "amd64" or rctx.os.arch == "aarch64"):
        # A system may have both rocm-smi and nvidia-smi installed, check both.
        nvidia_smi = rctx.which("nvidia-smi")

        # amd-smi supersedes rocm-smi
        amd_smi = rctx.which("amd-smi")
        rocm_smi = rctx.which("rocm-smi")

        if nvidia_smi:
            count, mb = _detect_nvidia_memory(rctx, nvidia_smi)
            total_gpu_count += count
            total_gpu_memory_mb += mb
        if amd_smi:
            count, mb = _detect_amd_smi_memory(rctx, amd_smi)
            total_gpu_count += count
            total_gpu_memory_mb += mb
        elif rocm_smi:
            count, mb = _detect_rocm_smi_memory(rctx, rocm_smi)
            total_gpu_count += count
            total_gpu_memory_mb += mb

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
                # amd-smi outputs warnings to stdout, filter them out
                json_lines = []
                for line in result.stdout.splitlines():
                    if line.startswith("WARNING:"):
                        continue
                    json_lines.append(line)
                failure_sentinel = {"DECODE": "FAILED"}
                blob = json.decode("\n".join(json_lines), default = failure_sentinel)
                if blob == failure_sentinel:
                    fail("amd-smi output was not valid json, please report this issue: {}".format(result.stdout))

                if "gpu_data" in blob:
                    blob = blob["gpu_data"]
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
                "@mojo_gpu_toolchains//:has_gpu",
            ])

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

    if total_gpu_count > 0 or total_gpu_memory_mb > 0:
        _write_gpu_resources_bazelrc(rctx, total_gpu_count, total_gpu_memory_mb)

mojo_host_platform = repository_rule(
    implementation = _impl,
    configure = True,
    environ = [
        "MOJO_IGNORE_UNKNOWN_GPUS",
        "MOJO_QUIET_GPU_RESOURCES",
        "MOJO_VERBOSE_GPU_DETECT",
    ],
    attrs = {
        "gpu_mapping": attr.string_dict(
            doc = "A dictionary of GPU strings from nvidia-smi or amd-smi, mapped to supported GPUs defined by mojo.gpu_toolchains()",
        ),
    },
)
