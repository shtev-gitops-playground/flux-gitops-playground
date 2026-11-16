#!/usr/bin/env bash
# Tests scripts/tenant-paths.sh: a PR may only touch tenants/<its author>/ inside tenants/.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

failures=0
tab=$'\t'

# check <want-exit> <description> <author> <name-status lines...>
check() {
  local want=$1 desc=$2 author=$3; shift 3
  local got=0
  printf '%s\n' "$@" | scripts/tenant-paths.sh "$author" >/dev/null 2>&1 || got=$?
  if [[ $got == "$want" ]]; then
    echo "ok    $desc"
  else
    echo "FAIL  $desc: wanted exit $want, got $got"; failures=$((failures + 1))
  fi
}

check 0 "own folder"                     bob   "M${tab}tenants/bob/app/deployment.yaml"
check 0 "mixed-case login, own folder"   Bob   "A${tab}tenants/bob/app/configmap.yaml"
check 0 "not under tenants/ at all"      bob   "M${tab}docs/exercises.md"
check 0 "rename within own folder"       bob   "R100${tab}tenants/bob/a.yaml${tab}tenants/bob/b.yaml"
check 1 "someone else's folder"          bob   "M${tab}tenants/alice/app/deployment.yaml"
check 1 "rename out of someone else's"   bob   "R100${tab}tenants/alice/x.yaml${tab}tenants/bob/x.yaml"
check 1 "rename into someone else's"     bob   "R100${tab}tenants/bob/x.yaml${tab}tenants/alice/x.yaml"
check 1 "delete someone else's file"     bob   "D${tab}tenants/alice/x.yaml"
check 1 "prefix trap (bobby)"            bob   "M${tab}tenants/bobby/x.yaml"
check 1 "the shared template"            bob   "M${tab}tenants/_template/app/deployment.yaml"
check 1 "own and someone else's"         bob   "M${tab}tenants/bob/x.yaml" "M${tab}tenants/alice/x.yaml"
check 1 "a file directly in tenants/"    bob   "A${tab}tenants/README.md"
check 0 "empty diff"                     bob   ""

if ((failures)); then echo "$failures failure(s)"; exit 1; fi
echo "all checks passed"
