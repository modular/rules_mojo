#!/usr/bin/env bash
set -euo pipefail

# Print only the requested version, accepting linked and plain release headings.
# An optional path lets validation inspect the tagged changelog before checkout.
TAG=${1:?Usage: changelog_entry.sh <unprefixed-release-tag> [changelog-path]}
CHANGELOG=${2:-CHANGELOG.md}
if [[ -f "$CHANGELOG" ]]; then
    awk -v version="$TAG" '
        /^##? / {
            heading = $2
            sub(/^\[/, "", heading)
            sub(/\].*$/, "", heading)
            if (found) exit
            found = (heading == version)
        }
        found { print }
    ' "$CHANGELOG"
fi
