variable "admin_cidrs" {
  description = "Addresses allowed to reach SSH, e.g. [\"203.0.113.7/32\"]."
  type        = list(string)
}

variable "ssh_public_key" {
  description = "Public key installed for root on the server."
  type        = string
}

variable "location" {
  description = "Hetzner location."
  type        = string
  default     = "nbg1"
}

variable "server_type" {
  description = "Hetzner server type."
  type        = string
  default     = "cx23"
}

variable "k3s_version" {
  description = "k3s release."
  type        = string
  default     = "v1.37.2+k3s1"
}

variable "domain" {
  description = "Subdomain everything lives under; its parent zone must already exist in Route 53."
  type        = string
  default     = "gitops.shtev.dev"
}

variable "parent_zone" {
  description = "Existing Route 53 hosted zone the records go in."
  type        = string
  default     = "shtev.dev"
}
