resource "hcloud_firewall" "server" {
  name   = "gitops-playground"
  labels = local.labels

  rule {
    description = "SSH, admins only"
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = var.admin_cidrs
  }

  # Web traffic for Let's Encrypt, Dex and the tenants' apps.
  dynamic "rule" {
    for_each = ["80", "443"]
    content {
      description = "HTTP(S)"
      direction   = "in"
      protocol    = "tcp"
      port        = rule.value
      source_ips  = ["0.0.0.0/0", "::/0"]
    }
  }

  # Colleagues run kubectl from wherever they are; access is gated by OIDC and RBAC.
  rule {
    description = "Kubernetes API"
    direction   = "in"
    protocol    = "tcp"
    port        = "6443"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
}
