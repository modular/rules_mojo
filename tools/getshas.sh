#!/bin/bash

set -euo pipefail

getsha() {
  shasum -a 256 "$1" | cut -d " " -f1 | xargs
}

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <version>"
  exit 1
fi

readonly version=$1
directory=$(mktemp -d)

curl --location --fail --output "$directory/linux_x86_64" "https://dl.modular.com/public/nightly/python/mojo_compiler-$version-py3-none-manylinux_2_34_x86_64.whl"
curl --location --fail --output "$directory/linux_aarch64" "https://dl.modular.com/public/nightly/python/mojo_compiler-$version-py3-none-manylinux_2_34_aarch64.whl"
curl --location --fail --output "$directory/macos" "https://dl.modular.com/public/nightly/python/mojo_compiler-$version-py3-none-macosx_13_0_arm64.whl"

cat <<EOF
"$version": {
  "linux_aarch64": "$(getsha "$directory/linux_aarch64")",
  "linux_x86_64": "$(getsha "$directory/linux_x86_64")",
  "macos_arm64": "$(getsha "$directory/macos")",
}
EOF
