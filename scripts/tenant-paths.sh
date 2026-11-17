#!/usr/bin/env bash
# PR check: inside tenants/, a PR may only touch tenants/<author>/ (author lowercased).
# Reads `git diff --name-status` lines on stdin; renames carry both old and new paths.
# Paths outside tenants/ are left to CODEOWNERS (they need Steve's review).
# If the pusher is given, it must be the author: nobody else may push to your PR and merge it.
#   git -c core.quotePath=false diff --name-status origin/main...HEAD | scripts/tenant-paths.sh sHtev [pusher]
set -euo pipefail

author=$(tr '[:upper:]' '[:lower:]' <<<"${1:?usage: tenant-paths.sh <github-login>}")
own="tenants/$author/"
bad=()

if [[ -n ${2:-} ]]; then
  pusher=$(tr '[:upper:]' '[:lower:]' <<<"$2")
  if [[ $pusher != "$author" ]]; then
    echo "This PR was updated by $2, not its author. Only the author's own pushes can merge without review." >&2
    exit 1
  fi
fi

while IFS=$'\t' read -r _status path1 path2 || [[ -n ${_status:-} ]]; do
  for path in "${path1:-}" "${path2:-}"; do
    # git quotes names with unusual characters; treat any of those as suspicious.
    [[ $path == \"* ]] && { bad+=("$path"); continue; }
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
