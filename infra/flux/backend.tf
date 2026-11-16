terraform {
  required_version = ">= 1.10"

  required_providers {
    flux       = { source = "fluxcd/flux", version = "~> 1.10" }
    github     = { source = "integrations/github", version = "~> 6.13" }
    tls        = { source = "hashicorp/tls", version = "~> 4.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 3.5" }
  }

  # State bucket passed at init: -backend-config=../backend.hcl (git-ignored).
  backend "s3" {
    key          = "gitops-playground/flux.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
