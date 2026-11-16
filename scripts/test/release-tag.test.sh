#!/usr/bin/env bash
# Tests scripts/release-tag.sh: valid releases get "<login-lowercased>-<version>", anything else is refused.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

failures=0

accepts() {
  local got
  if got=$(scripts/release-tag.sh "$1" "$2" 2>/dev/null) && [[ $got == "$3" ]]; then
    echo "ok    $1 $2 -> $3"
  else
    echo "FAIL  $1 $2: wanted $3, got '${got:-<refused>}'"; failures=$((failures + 1))
  fi
}

refuses() {
  if scripts/release-tag.sh "$1" "$2" >/dev/null 2>&1; then
    echo "FAIL  $1 '$2' was accepted"; failures=$((failures + 1))
  else
    echo "ok    refused: $1 '$2'"
  fi
}

accepts Alice 1.2.3 alice-1.2.3
accepts sHtev 1.0.0 shtev-1.0.0
accepts bob 10.20.30 bob-10.20.30
accepts bob 0.0.0 bob-0.0.0

refuses bob v1.2.3
refuses bob 1.2
refuses bob 1.2.3-rc1
refuses bob 01.2.3
refuses bob "1.2.3;id"
refuses bob ""
refuses "bob;id" 1.2.3
refuses "bob/x" 1.2.3
refuses "" 1.2.3

if ((failures)); then echo "$failures failure(s)"; exit 1; fi
echo "all checks passed"
