terraform {
  required_version = ">= 1.10"

  required_providers {
    hcloud = { source = "hetznercloud/hcloud", version = "~> 1.70" }
    aws    = { source = "hashicorp/aws", version = "~> 6.0" }
  }

  # State bucket passed at init: -backend-config=../backend.hcl (git-ignored).
  backend "s3" {
    key          = "gitops-playground/hetzner.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
