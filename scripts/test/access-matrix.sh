#!/usr/bin/env bash
# Checks who can do what, by asking the API server as other users (needs the admin kubeconfig).
#   scripts/test/access-matrix.sh
set -euo pipefail

KUBECONFIG_ADMIN=${KUBECONFIG_ADMIN:-$HOME/.kube/gitops-playground-admin}
PLAYERS=github:shtev-gitops-playground:players
failures=0

# expect <yes|no> <description> -- <kubectl auth can-i args...>
expect() {
  local want=$1 desc=$2; shift 3
  local got
  got=$(kubectl --kubeconfig "$KUBECONFIG_ADMIN" auth can-i "$@" 2>/dev/null || true)
  if [[ $got == "$want" ]]; then
    echo "ok    $desc"
  else
    echo "FAIL  $desc: wanted $want, got ${got:-error}"
    failures=$((failures + 1))
  fi
}

player=(--as=github:testuser --as-group="$PLAYERS" --as-group=system:authenticated)
stranger=(--as=github:stranger --as-group=system:authenticated)

echo "# A player who isn't onboarded yet: can look around, can't touch or read secrets"
expect yes "list namespaces"            -- list namespaces "${player[@]}"
expect yes "list Kustomizations"        -- list kustomizations.kustomize.toolkit.fluxcd.io -A "${player[@]}"
expect yes "get flux-system pods"       -- get pods -n flux-system "${player[@]}"
expect yes "read flux-system logs"      -- get pods/log -n flux-system "${player[@]}"
expect yes "list events"                -- list events -A "${player[@]}"
expect yes "list ImagePolicies"         -- list imagepolicies.image.toolkit.fluxcd.io -A "${player[@]}"
expect no  "get flux-system secrets"    -- get secrets -n flux-system "${player[@]}"
expect no  "list all secrets"           -- list secrets -A "${player[@]}"
expect no  "create pods in flux-system" -- create pods -n flux-system "${player[@]}"
expect no  "patch Kustomizations"       -- patch kustomizations.kustomize.toolkit.fluxcd.io -n flux-system "${player[@]}"
expect no  "create ClusterRoleBindings" -- create clusterrolebindings "${player[@]}"
expect no  "impersonate users"          -- impersonate users "${player[@]}"

echo "# Logged in but not in players (shouldn't get past Dex, but RBAC must hold too)"
expect no  "list namespaces"            -- list namespaces "${stranger[@]}"

if ((failures)); then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
