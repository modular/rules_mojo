#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <unprefixed-release-tag>" >&2
    exit 1
fi

TAG=$1
NUMBER='(0|[1-9][0-9]*)'
IDENTIFIER="($NUMBER|[0-9]*[A-Za-z-][0-9A-Za-z-]*)"
if [[ ! "$TAG" =~ ^$NUMBER\.$NUMBER\.$NUMBER(-$IDENTIFIER(\.$IDENTIFIER)*)?$ ]]; then
    echo "Expected an unprefixed version such as 0.9.0 or 0.9.0-rc.1" >&2
    exit 1
fi

PREFIX="rules_mojo-$TAG"
ARCHIVE="$PREFIX.tar.gz"
git rev-parse --verify "${TAG}^{commit}" > /dev/null
# Keep committed sources intact; the BCR publisher stamps its MODULE.bazel.
# Refuse to overwrite an existing artifact, and omit gzip timestamps.
set -o noclobber
git -C "$(git rev-parse --show-toplevel)" archive --format=tar --prefix="${PREFIX}/" "$TAG" | gzip -n > "$ARCHIVE"
SHA=$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')

cat << EOF
## rules_mojo $TAG

Add the following to your \`MODULE.bazel\`:

\`\`\`bzl
bazel_dep(name = "rules_mojo", version = "$TAG")
\`\`\`

Requires Bazel 8 or later. Omit the version from \`mojo.toolchain()\` to use the
default Mojo toolchain, or select one with \`mojo.toolchain(version = "...")\`.

Archive: \`$ARCHIVE\` (strip prefix: \`$PREFIX\`)

SHA-256: \`$SHA\`

Archive and BCR metadata attestations are attached by the release workflow.
EOF
