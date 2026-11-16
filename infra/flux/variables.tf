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
