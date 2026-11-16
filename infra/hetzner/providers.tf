# Reads HCLOUD_TOKEN from the environment.
provider "hcloud" {}

# Route 53 only: the shtev.dev zone lives in AWS.
provider "aws" {
  region = "eu-west-2"
  default_tags {
    tags = { Project = "gitops-playground", ManagedBy = "terraform", Stack = "hetzner" }
  }
}
