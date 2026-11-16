# State bucket passed at init: -backend-config=../backend.hcl (git-ignored).
terraform {
  backend "s3" {
    key          = "bootstrap/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
