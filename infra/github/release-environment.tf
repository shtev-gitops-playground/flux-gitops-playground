# The release workflow's push credential lives only in this environment, and the environment
# only accepts jobs running from main. A workflow edited on a branch can't reach the secret.
resource "github_repository_environment" "release" {
  repository  = github_repository.playground.name
  environment = "release"

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "release_main" {
  repository     = github_repository.playground.name
  environment    = github_repository_environment.release.environment
  branch_pattern = "main"
}

resource "github_actions_environment_secret" "ghcr_push_token" {
  repository      = github_repository.playground.name
  environment     = github_repository_environment.release.environment
  secret_name     = "GHCR_PUSH_TOKEN"
  plaintext_value = var.ghcr_push_token
}

resource "github_actions_environment_variable" "ghcr_push_user" {
  repository    = github_repository.playground.name
  environment   = github_repository_environment.release.environment
  variable_name = "GHCR_PUSH_USER"
  value         = var.ghcr_push_user
}
