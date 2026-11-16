# Reads GITHUB_TOKEN from the environment.
provider "github" {
  owner = split("/", var.repo)[0]
}

provider "flux" {
  kubernetes = {
    config_path = pathexpand(var.kubeconfig)
  }
  git = {
    url    = "ssh://git@github.com/${var.repo}.git"
    branch = "main"
    ssh = {
      username    = "git"
      private_key = tls_private_key.flux.private_key_pem
    }
  }
}

provider "kubernetes" {
  config_path = pathexpand(var.kubeconfig)
}
