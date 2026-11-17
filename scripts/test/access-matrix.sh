#!/usr/bin/env bash
# Checks who can do what, by asking the API server as other users (needs the admin kubeconfig).
#   scripts/test/access-matrix.sh
set -euo pipefail

KUBECONFIG_ADMIN=${KUBECONFIG_ADMIN:-$HOME/.kube/gitops-playground-admin}
PLAYERS=github:shtev-gitops-playground:players
failures=0
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

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

echo "# Nothing that could reach the node itself"
cat >"$tmpdir/privileged-pod.yaml" <<YAML
apiVersion: v1
kind: Pod
metadata: { name: escape, namespace: play-$TENANT }
spec:
  hostPID: true
  containers:
    - name: c
      image: busybox:1.37
      securityContext: { privileged: true }
      volumeMounts: [{ name: root, mountPath: /host }]
  volumes: [{ name: root, hostPath: { path: / } }]
YAML
deny "privileged hostPath pod" apply -f "$tmpdir/privileged-pod.yaml" "${flux_tenant[@]}"
deny "LoadBalancer Service (could take node ports)" create service loadbalancer grab -n "play-$TENANT" --tcp=6443:6443 "${flux_tenant[@]}"
deny "NodePort Service" create service nodeport grab -n "play-$TENANT" --tcp=80:80 "${flux_tenant[@]}"

deny "Service with externalIPs" create -f - "${flux_tenant[@]}" <<YAML
apiVersion: v1
kind: Service
metadata: { name: grab, namespace: play-$TENANT }
spec: { ports: [{ port: 80 }], externalIPs: [116.203.147.119] }
YAML

echo "# Nobody can grab the whole node's memory"
deny "pod asking for 8Gi" run hog -n "play-$TENANT" --image=busybox:1.37 \
  --overrides='{"spec":{"containers":[{"name":"hog","image":"busybox:1.37","resources":{"requests":{"memory":"8Gi"}}}]}}' \
  "${flux_tenant[@]}"
if kubectl --kubeconfig "$KUBECONFIG_ADMIN" get networkpolicy isolate -n "play-$TENANT" >/dev/null 2>&1; then
  echo "ok    other players' pods can't reach yours (NetworkPolicy isolate)"
else
  echo "FAIL  no NetworkPolicy isolate in play-$TENANT"; failures=$((failures + 1))
fi

echo "# Tenant $TENANT's image sync can only write its own ImagePolicy"
# shellcheck disable=SC2016 # $version is literal YAML
policy() { # policy <name> <pattern>
  printf 'apiVersion: image.toolkit.fluxcd.io/v1\nkind: ImagePolicy\nmetadata: { name: %s, namespace: flux-system }\nspec: { imageRepositoryRef: { name: demo-app }, filterTags: { pattern: "%s", extract: "$version" }, policy: { semver: { range: ">=1.0.0" } } }\n' "$1" "$2"
}
policy "$TENANT-demo-app" "^$TENANT-(?P<version>.+)\$" >"$tmpdir/own-policy.yaml"
if kubectl --kubeconfig "$KUBECONFIG_ADMIN" apply --server-side --force-conflicts --dry-run=server -f "$tmpdir/own-policy.yaml" \
  --field-manager=test "${images_sa[@]}" >/dev/null 2>&1; then
  echo "ok    own ImagePolicy"
else
  echo "FAIL  own ImagePolicy: was refused"; failures=$((failures + 1))
fi
policy someoneelse-demo-app "^someoneelse-(?P<version>.+)\$" >"$tmpdir/other-policy.yaml"
deny "ImagePolicy named for someone else" create -f "$tmpdir/other-policy.yaml" "${images_sa[@]}"
policy "$TENANT-demo-app" "^someoneelse-(?P<version>.+)\$" >"$tmpdir/stolen-tags.yaml"
deny "own ImagePolicy reading someone else's tags" apply --server-side --force-conflicts --field-manager=test -f "$tmpdir/stolen-tags.yaml" "${images_sa[@]}"

if ((failures)); then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
