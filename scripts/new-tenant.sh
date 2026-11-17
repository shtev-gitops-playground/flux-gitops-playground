#!/usr/bin/env bash
# Operator only. Sets up a new player from the templates, then open a PR with the result.
#   scripts/new-tenant.sh <github-login>      e.g. scripts/new-tenant.sh JaneDoe
# Creates platform/tenants/<lc>/ (namespace, permissions, Flux syncs; Steve-owned) and
# tenants/<lc>/ (the player's own folder). <lc> is the login in lower case.
set -euo pipefail
cd "$(dirname "$0")/.."

login=${1:?usage: new-tenant.sh <github-login>}
if [[ ! $login =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,38}$ ]]; then
  echo "Not a GitHub login: '$login'" >&2
  exit 1
fi

# Logins are case-insensitive on GitHub, but the cluster's RBAC matches the exact spelling.
api=${GITHUB_API:-https://api.github.com}
canonical=$( (curl -fsS "$api/users/$login" 2>/dev/null || true) | sed -n 's/.*"login": *"\([^"]*\)".*/\1/p' | head -1)
if [[ -z $canonical ]]; then
  echo "GitHub has no user '$login'." >&2
  exit 1
fi
if [[ $canonical != "$login" ]]; then
  echo "GitHub spells it '$canonical'. Run again with exactly that." >&2
  exit 1
fi
lc=$(tr '[:upper:]' '[:lower:]' <<<"$login")

if [[ -e tenants/$lc || -e platform/tenants/$lc ]]; then
  echo "Tenant '$lc' already exists." >&2
  exit 1
fi

# Copy a template folder, filling in __LOGIN__ (exact case, for RBAC) and __LC__ (names, hosts, tags).
stamp() {
  local from=$1 to=$2 f
  cp -R "$from" "$to"
  while IFS= read -r f; do
    sed -e "s/__LOGIN__/$login/g" -e "s/__LC__/$lc/g" "$f" >"$f.tmp" && mv "$f.tmp" "$f"
  done < <(find "$to" -type f)
}

stamp platform/tenants/_template "platform/tenants/$lc"
stamp tenants/_template "tenants/$lc"

list=platform/tenants/kustomization.yaml
sed -i.bak 's/^resources: \[\]$/resources:/' "$list" && rm -f "$list.bak"
echo "  - $lc" >>"$list"

echo "Created platform/tenants/$lc and tenants/$lc for github:$login (namespace play-$lc)."
echo "Next: make sure $login is in the 'players' team, then commit and push."
