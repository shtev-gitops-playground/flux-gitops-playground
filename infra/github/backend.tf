terraform {
  required_version = ">= 1.10"

  required_providers {
    github = { source = "integrations/github", version = "~> 6.6" }
  }

  # State bucket passed at init: -backend-config=../backend.hcl (git-ignored).
  backend "s3" {
    key          = "gitops-playground/github.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
