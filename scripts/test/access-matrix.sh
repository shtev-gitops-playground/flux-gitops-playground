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
expect yes "list CRDs (flux check)"     -- list customresourcedefinitions.apiextensions.k8s.io "${player[@]}"
expect no  "get flux-system secrets"    -- get secrets -n flux-system "${player[@]}"
expect no  "list all secrets"           -- list secrets -A "${player[@]}"
expect no  "create pods in flux-system" -- create pods -n flux-system "${player[@]}"
expect no  "patch Kustomizations"       -- patch kustomizations.kustomize.toolkit.fluxcd.io -n flux-system "${player[@]}"
expect no  "create ClusterRoleBindings" -- create clusterrolebindings "${player[@]}"
expect no  "impersonate users"          -- impersonate users "${player[@]}"

echo "# Logged in but not in players (shouldn't get past Dex, but RBAC must hold too)"
expect no  "list namespaces"            -- list namespaces "${stranger[@]}"

# deny <description> <kubectl args...>: a server-side dry run that must be refused.
deny() {
  local desc=$1; shift
  if kubectl --kubeconfig "$KUBECONFIG_ADMIN" "$@" --dry-run=server >/dev/null 2>&1; then
    echo "FAIL  $desc: was allowed"
    failures=$((failures + 1))
  else
    echo "ok    $desc"
  fi
}

TENANT=${TENANT:-shtev}
TENANT_LOGIN=${TENANT_LOGIN:-sHtev}
flux_tenant=("--as=system:serviceaccount:play-$TENANT:flux-tenant")
images_sa=("--as=system:serviceaccount:flux-system:tenant-images-$TENANT")
owner=("--as=github:$TENANT_LOGIN" --as-group="$PLAYERS" --as-group=system:authenticated)

echo "# Flux acting for tenant $TENANT: only inside play-$TENANT"
expect yes "create deployments in own namespace"    -- create deployments -n "play-$TENANT" "${flux_tenant[@]}"
expect no  "create deployments in flux-system"      -- create deployments -n flux-system "${flux_tenant[@]}"
expect no  "create ClusterRoleBindings"             -- create clusterrolebindings "${flux_tenant[@]}"
expect no  "read Dex's secrets"                     -- get secrets -n dex "${flux_tenant[@]}"

echo "# Tenant $TENANT's image sync: ImagePolicies in flux-system only"
expect yes "create ImagePolicies in flux-system"    -- create imagepolicies.image.toolkit.fluxcd.io -n flux-system "${images_sa[@]}"
expect no  "create Kustomizations in flux-system"   -- create kustomizations.kustomize.toolkit.fluxcd.io -n flux-system "${images_sa[@]}"
expect no  "read flux-system secrets"               -- get secrets -n flux-system "${images_sa[@]}"
expect no  "create ImageUpdateAutomations"          -- create imageupdateautomations.image.toolkit.fluxcd.io -n flux-system "${images_sa[@]}"

echo "# $TENANT_LOGIN in person"
expect yes "edit things in own namespace"           -- create deployments -n "play-$TENANT" "${owner[@]}"
expect no  "edit things in someone else's"          -- create deployments -n play-someoneelse "${owner[@]}"

echo "# Nobody can claim someone else's hostname"
deny "Ingress for another player's host" create ingress hijack -n "play-$TENANT" \
  --rule="someoneelse.gitops.shtev.dev/*=demo-app:80" "${flux_tenant[@]}"
if kubectl --kubeconfig "$KUBECONFIG_ADMIN" create ingress own -n "play-$TENANT" \
  --rule="$TENANT.gitops.shtev.dev/*=demo-app:80" --dry-run=server "${flux_tenant[@]}" >/dev/null 2>&1; then
  echo "ok    Ingress for own host"
else
  echo "FAIL  Ingress for own host: was refused"; failures=$((failures + 1))
fi

if ((failures)); then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
