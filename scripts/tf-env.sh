# Source me: puts this project's credentials from 1Password into the environment for Terraform.
#   . scripts/tf-env.sh
# Your AWS profile and 1Password account come from scripts/tf-env.local (git-ignored; copy the
# .example). Without it, AWS_PROFILE and OP_ACCOUNT are taken from your environment as they are.
_tf_env_local="$(dirname "${BASH_SOURCE[0]:-$0}")/tf-env.local"
# shellcheck source=/dev/null
[ -f "$_tf_env_local" ] && . "$_tf_env_local"
unset _tf_env_local
HCLOUD_TOKEN=$(op read "op://Projects/GitOps Playground Hetzner API Token/credential")
GITHUB_TOKEN=$(op read "op://Projects/GitOps Playground GitHub Terraform Token/credential")
TF_VAR_github_oauth_client_id=$(op read "op://Projects/GitOps Playground GitHub OAuth/client ID")
TF_VAR_github_oauth_client_secret=$(op read "op://Projects/GitOps Playground GitHub OAuth/secret")
export HCLOUD_TOKEN GITHUB_TOKEN TF_VAR_github_oauth_client_id TF_VAR_github_oauth_client_secret
TF_VAR_ghcr_push_token=$(op read "op://Projects/GitOps Playground GHCR Push Token/credential" 2>/dev/null || true)
export TF_VAR_ghcr_push_token
