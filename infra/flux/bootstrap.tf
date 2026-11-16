# Flux's own key to the repo. Write access, because image automation commits tag bumps back to main.
resource "tls_private_key" "flux" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "github_repository_deploy_key" "flux" {
  repository = split("/", var.repo)[1]
  title      = "flux"
  key        = tls_private_key.flux.public_key_openssh
  read_only  = false
}

resource "flux_bootstrap_git" "this" {
  depends_on = [github_repository_deploy_key.flux]

  version          = var.flux_version
  path             = "clusters/playground"
  components_extra = ["image-reflector-controller", "image-automation-controller"]

  # Multi-tenancy lockdown, as in the Flux docs. Flux runs as cluster-admin, so without this a
  # tenant's manifests could reach into other namespaces or act with Flux's own permissions.
  kustomization_override = file("${path.module}/lockdown.yaml")
}
