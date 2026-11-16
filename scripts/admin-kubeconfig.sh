#!/usr/bin/env bash
# Operator only. Fetches the k3s admin kubeconfig over SSH into ~/.kube/gitops-playground-admin
# (context gitops-playground-admin). This file is cluster-admin: never commit or share it.
# Colleagues use kubeconfig/playground.yaml and their GitHub login instead.
set -euo pipefail

HOST=${SSH_HOST:-gitops-playground}   # see "Host gitops-playground" in ~/.ssh/config
API=${API_SERVER:-https://api.gitops.shtev.dev:6443}
OUT=${KUBECONFIG_OUT:-$HOME/.kube/gitops-playground-admin}

mkdir -p "$(dirname "$OUT")"
umask 077
ssh "root@$HOST" cat /etc/rancher/k3s/k3s.yaml |
  sed -e "s#https://127.0.0.1:6443#$API#" -e 's/: default$/: gitops-playground-admin/' > "$OUT"
chmod 600 "$OUT"
echo "Wrote $OUT. Use: kubectl --kubeconfig $OUT get nodes"
