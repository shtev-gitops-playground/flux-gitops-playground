#!/usr/bin/env bash
# Runs scripts/install-tools.sh in clean Ubuntu containers (amd64 and arm64), as a WSL/Linux user would.
#   scripts/test/install-tools.test.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

for platform in linux/amd64 linux/arm64; do
  echo "# $platform"
  docker run --rm --platform "$platform" -v "$PWD:/repo:ro" ubuntu:24.04 bash -euo pipefail -c '
    apt-get update -qq >/dev/null && apt-get install -y -qq curl unzip ca-certificates >/dev/null
    useradd -m dev && su dev -s /bin/bash -c "
      set -euo pipefail
      bash /repo/scripts/install-tools.sh
      ~/.local/bin/kubectl version --client
      PATH=\$HOME/.local/bin:\$PATH kubectl oidc-login --version
      ~/.local/bin/flux --version
    "'
done
echo "install-tools: all platforms passed"
