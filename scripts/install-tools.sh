#!/usr/bin/env bash
# Installs kubectl and the kubelogin plugin (kubectl oidc-login) into ~/.local/bin.
# Works the same on WSL, Linux and macOS. Needs: curl, unzip.
#   bash scripts/install-tools.sh
set -euo pipefail

KUBECTL_VERSION=v1.37.2
KUBELOGIN_VERSION=v1.36.4
BIN_DIR=${BIN_DIR:-$HOME/.local/bin}

case "$(uname -s)" in
  Linux) os=linux ;;
  Darwin) os=darwin ;;
  *) echo "Unsupported OS: $(uname -s). On Windows, run this inside WSL." >&2; exit 1 ;;
esac
case "$(uname -m)" in
  x86_64 | amd64) arch=amd64 ;;
  arm64 | aarch64) arch=arm64 ;;
  *) echo "Unsupported CPU: $(uname -m)" >&2; exit 1 ;;
esac

for tool in curl unzip; do
  command -v "$tool" >/dev/null || { echo "Please install $tool first." >&2; exit 1; }
done

sha256() {
  if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1
}

# verify <file> <expected-sha256>
verify() {
  local got
  got=$(sha256 "$1")
  [[ $got == "$2" ]] || { echo "Checksum mismatch for $1 (got $got, expected $2)" >&2; exit 1; }
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$BIN_DIR"

echo "Installing kubectl $KUBECTL_VERSION ($os/$arch)"
url=https://dl.k8s.io/release/$KUBECTL_VERSION/bin/$os/$arch/kubectl
curl -fsSL -o "$tmp/kubectl" "$url"
verify "$tmp/kubectl" "$(curl -fsSL "$url.sha256")"
install -m 0755 "$tmp/kubectl" "$BIN_DIR/kubectl"

echo "Installing kubelogin $KUBELOGIN_VERSION ($os/$arch)"
zip=kubelogin_${os}_${arch}.zip
url=https://github.com/int128/kubelogin/releases/download/$KUBELOGIN_VERSION/$zip
curl -fsSL -o "$tmp/$zip" "$url"
verify "$tmp/$zip" "$(curl -fsSL "$url.sha256" | cut -d' ' -f1)"
unzip -q -o "$tmp/$zip" kubelogin -d "$tmp"
# kubectl finds plugins by name: kubectl-oidc_login becomes "kubectl oidc-login".
install -m 0755 "$tmp/kubelogin" "$BIN_DIR/kubectl-oidc_login"

echo "Done: $BIN_DIR/kubectl and $BIN_DIR/kubectl-oidc_login"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "Add $BIN_DIR to your PATH: put  export PATH=\"$BIN_DIR:\$PATH\"  in ~/.bashrc (or ~/.zshrc on a Mac), then open a new terminal." ;;
esac
