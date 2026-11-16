#!/usr/bin/env bash
# Prints the image tag for a release: <github-login, lowercased>-<version>.
# Refuses anything that isn't a plain MAJOR.MINOR.PATCH version or a valid GitHub login.
#   scripts/release-tag.sh sHtev 1.2.3   ->  shtev-1.2.3
set -euo pipefail

actor=${1:-}
version=${2:-}

if [[ ! $actor =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]]; then
  echo "Not a GitHub login: '$actor'" >&2
  exit 1
fi
if [[ ! $version =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  echo "Version must look like 1.2.3 (no 'v', no suffix): '$version'" >&2
  exit 1
fi

echo "$(tr '[:upper:]' '[:lower:]' <<<"$actor")-$version"
