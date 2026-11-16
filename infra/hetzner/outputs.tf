output "server_ipv4" {
  value = hcloud_primary_ip.server.ip_address
}

output "api_server" {
  value = "https://api.${var.domain}:6443"
}
