# From 1Password at apply time: TF_VAR_ghcr_push_token (see scripts/tf-env.sh).
variable "ghcr_push_token" {
  description = "Classic token with only write:packages, used by the release workflow to push images."
  type        = string
  sensitive   = true
}

variable "ghcr_push_user" {
  description = "GitHub login that owns ghcr_push_token."
  type        = string
  default     = "sHtev"
}
