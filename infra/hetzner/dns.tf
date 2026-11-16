data "aws_route53_zone" "parent" {
  name = var.parent_zone
}

# api (kubectl), dex (login) and *.gitops (tenant apps) all point at the one node.
resource "aws_route53_record" "server" {
  for_each = toset(["api.${var.domain}", "dex.${var.domain}", "*.${var.domain}"])

  zone_id = data.aws_route53_zone.parent.zone_id
  name    = each.value
  type    = "A"
  ttl     = 300
  records = [hcloud_primary_ip.server.ip_address]
}
