locals {
  labels = { project = "gitops-playground" }
  issuer = "https://dex.${var.domain}"
}

resource "hcloud_ssh_key" "admin" {
  name       = "gitops-playground-admin"
  public_key = var.ssh_public_key
  labels     = local.labels
}

# Kept separately from the server so the address (and DNS) survives a rebuild.
resource "hcloud_primary_ip" "server" {
  name        = "gitops-playground"
  type        = "ipv4"
  location    = var.location
  auto_delete = false
  labels      = local.labels
}

resource "hcloud_server" "server" {
  name         = "gitops-playground"
  server_type  = var.server_type
  image        = "ubuntu-24.04"
  location     = var.location
  ssh_keys     = [hcloud_ssh_key.admin.id]
  firewall_ids = [hcloud_firewall.server.id]
  labels       = local.labels

  public_net {
    ipv4 = hcloud_primary_ip.server.id
  }

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    k3s_version = var.k3s_version
    api_host    = "api.${var.domain}"
    issuer      = local.issuer
  })

  lifecycle {
    # cloud-init only runs on first boot; a changed template shouldn't rebuild the node.
    ignore_changes = [user_data, ssh_keys]
  }
}
