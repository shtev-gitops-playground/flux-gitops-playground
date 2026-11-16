#!/usr/bin/env bash
# PR check: inside tenants/, a PR may only touch tenants/<author>/ (author lowercased).
# Reads `git diff --name-status` lines on stdin; renames carry both old and new paths.
# Paths outside tenants/ are left to CODEOWNERS (they need Steve's review).
#   git diff --name-status origin/main...HEAD | scripts/tenant-paths.sh sHtev
set -euo pipefail

author=$(tr '[:upper:]' '[:lower:]' <<<"${1:?usage: tenant-paths.sh <github-login>}")
own="tenants/$author/"
bad=()

while IFS=$'\t' read -r _status path1 path2 || [[ -n ${_status:-} ]]; do
  for path in "${path1:-}" "${path2:-}"; do
    [[ $path == tenants/* ]] || continue
    [[ $path == "$own"* ]] || bad+=("$path")
  done
done

if ((${#bad[@]})); then
  echo "This PR changes files outside your own folder ($own):" >&2
  printf '  %s\n' "${bad[@]}" >&2
  echo "Only Steve can merge changes to other people's folders." >&2
  exit 1
fi
echo "tenant-paths: ok (only $own)"
