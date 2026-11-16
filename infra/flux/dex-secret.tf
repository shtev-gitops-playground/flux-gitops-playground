# Dex's GitHub OAuth credentials go straight into the cluster, never into Git.
# The HelmRelease in infrastructure/controllers/dex reads them from this Secret.
resource "kubernetes_namespace_v1" "dex" {
  metadata {
    name = "dex"
  }
}

resource "kubernetes_secret_v1" "github_oauth" {
  metadata {
    name      = "github-oauth"
    namespace = kubernetes_namespace_v1.dex.metadata[0].name
  }
  data = {
    "client-id"     = var.github_oauth_client_id
    "client-secret" = var.github_oauth_client_secret
  }
}
