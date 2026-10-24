#!/usr/bin/env python3
"""Print a _KNOWN_RELEASES entry for mojo/extensions.bzl.

Stable wheel URLs and checksums come from PyPI; nightly checksums are computed
from the wheels.
"""

import argparse
import hashlib
import json
import urllib.request


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version", help="Mojo release or nightly version")
    version = parser.parse_args().version
    platforms = {
        "linux_aarch64": "manylinux_2_34_aarch64",
        "linux_x86_64": "manylinux_2_34_x86_64",
        "macos_arm64": "macosx_13_0_arm64",
        "mojo_compiler_mojo_libs": "any",
    }
    metadata = {}
    releases = {}
    for key, platform in platforms.items():
        package = "mojo-compiler-mojo-libs" if platform == "any" else "mojo-compiler"
        filename = f'{package.replace("-", "_")}-{version}-py3-none-{platform}.whl'
        if ".dev" in version:
            url = f"https://whl.modular.com/nightly/{package}/{filename}"
            digest = hashlib.sha256()
            with urllib.request.urlopen(url) as response:
                for chunk in iter(lambda: response.read(1024 * 1024), b""):
                    digest.update(chunk)
            sha256 = digest.hexdigest()
        else:
            if package not in metadata:
                with urllib.request.urlopen(f"https://pypi.org/pypi/{package}/{version}/json") as response:
                    metadata[package] = json.load(response)
            wheel, = [
                wheel for wheel in metadata[package]["urls"]
                if wheel["filename"] == filename and not wheel["yanked"]
            ]
            url = wheel["url"]
            sha256 = wheel["digests"]["sha256"]
        releases[key] = (url, sha256)

    print(f'"{version}": {{')
    for key, (url, sha256) in releases.items():
        print(f'    "{key}": struct(')
        print(f'        url = "{url}",')
        print(f'        sha256 = "{sha256}",')
        print('    ),')
    print('},')


if __name__ == "__main__":
    main()
