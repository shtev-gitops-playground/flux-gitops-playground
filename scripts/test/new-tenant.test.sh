#!/usr/bin/env bash
# Tests scripts/new-tenant.sh in a scratch copy of the repo.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp -R scripts platform tenants "$work"/
cd "$work" || exit 1

failures=0
ok() { echo "ok    $1"; }
fail() { echo "FAIL  $1"; failures=$((failures + 1)); }
check() { if eval "$2"; then ok "$1"; else fail "$1"; fi; }

scripts/new-tenant.sh JaneDoe >/dev/null 2>&1
check "creates tenants/janedoe"                  "[[ -d tenants/janedoe/app && -d tenants/janedoe/images ]]"
check "creates platform/tenants/janedoe"         "[[ -d platform/tenants/janedoe ]]"
check "namespace is play-janedoe"                "grep -rq 'name: play-janedoe' platform/tenants/janedoe"
check "RBAC subject keeps exact case"            "grep -rq 'name: github:JaneDoe' platform/tenants/janedoe"
check "image policy filters janedoe- tags"       "grep -q \"pattern: '^janedoe-\" tenants/janedoe/images/image-policy.yaml"
check "ingress host is janedoe.gitops.shtev.dev" "grep -q 'janedoe.gitops.shtev.dev' tenants/janedoe/app/ingress.yaml"
check "no placeholders left"                     "! grep -rq '__' tenants/janedoe platform/tenants/janedoe"
check "listed in platform/tenants"               "grep -q -- '- janedoe' platform/tenants/kustomization.yaml"
check "platform/tenants builds"                  "kubectl kustomize platform/tenants >/dev/null"
check "tenant app builds"                        "kubectl kustomize tenants/janedoe/app >/dev/null"
check "tenant images build"                      "kubectl kustomize tenants/janedoe/images >/dev/null"
check "second run is refused"                    "! scripts/new-tenant.sh JaneDoe >/dev/null 2>&1"
check "bad login is refused"                     "! scripts/new-tenant.sh 'bad/name' >/dev/null 2>&1"

if ((failures)); then echo "$failures failure(s)"; exit 1; fi
echo "all checks passed"
