# The ruleset on main lets this key push past PR rules (image automation commits).
output "flux_deploy_key_id" {
  value = github_repository_deploy_key.flux.id
}
