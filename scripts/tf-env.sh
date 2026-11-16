# Source me: puts this project's credentials from 1Password into the environment for Terraform.
#   . scripts/tf-env.sh
export AWS_PROFILE=shtev-admin
export OP_ACCOUNT=gilroy-smith.1password.com
HCLOUD_TOKEN=$(op read "op://Projects/GitOps Playground Hetzner API Token/credential")
GITHUB_TOKEN=$(op read "op://Projects/GitOps Playground GitHub Terraform Token/credential")
TF_VAR_github_oauth_client_id=$(op read "op://Projects/GitOps Playground GitHub OAuth/client ID")
TF_VAR_github_oauth_client_secret=$(op read "op://Projects/GitOps Playground GitHub OAuth/secret")
export HCLOUD_TOKEN GITHUB_TOKEN TF_VAR_github_oauth_client_id TF_VAR_github_oauth_client_secret
