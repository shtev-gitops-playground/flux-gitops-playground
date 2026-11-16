#!/usr/bin/env bash
# Builds every kustomization in the repo and checks the result against Kubernetes and Flux schemas.
#   scripts/validate-manifests.sh
set -euo pipefail
cd "$(dirname "$0")/.."

# CRD definitions themselves (in Flux's generated install files) have no schema to check against.
CRDS='https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
status=0
out=$(mktemp)
trap 'rm -f "$out"' EXIT

while IFS= read -r dir; do
  if kubectl kustomize "$dir" |
    kubeconform -strict -summary -skip CustomResourceDefinition -schema-location default -schema-location "$CRDS" -output text - >"$out" 2>&1; then
    echo "ok    $dir: $(tail -1 "$out")"
  else
    echo "FAIL  $dir"; sed 's/^/      /' "$out"
    status=1
  fi
done < <(find . -name kustomization.yaml -not -path './.git/*' -not -path '*/.terraform/*' -exec dirname {} \; | sort)

# clusters/playground has no kustomization.yaml (Flux generates one), so check its files directly.
for f in clusters/playground/*.yaml; do
  kubeconform -strict -schema-location default -schema-location "$CRDS" "$f" || status=1
done

exit $status
