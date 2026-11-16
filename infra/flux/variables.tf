variable "kubeconfig" {
  description = "Admin kubeconfig written by scripts/admin-kubeconfig.sh."
  type        = string
  default     = "~/.kube/gitops-playground-admin"
}

variable "repo" {
  description = "Repository Flux syncs from, owner/name."
  type        = string
  default     = "shtev-gitops-playground/flux-gitops-playground"
}

variable "flux_version" {
  description = "Flux release to install."
  type        = string
  default     = "v2.10.0"
}

# From 1Password at apply time: TF_VAR_github_oauth_client_id / TF_VAR_github_oauth_client_secret.
variable "github_oauth_client_id" {
  description = "GitHub OAuth app client ID used by Dex."
  type        = string
  sensitive   = true
}

variable "github_oauth_client_secret" {
  description = "GitHub OAuth app client secret used by Dex."
  type        = string
  sensitive   = true
}
