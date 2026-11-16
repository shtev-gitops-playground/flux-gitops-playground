# Rules for main: changes arrive by PR, required checks must pass, and anything outside
# tenants/ needs a code owner's (Steve's) review. See .github/CODEOWNERS.
resource "github_repository_ruleset" "main" {
  name        = "main"
  repository  = github_repository.playground.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  # Org owners (Steve) can push platform changes directly.
  bypass_actors {
    actor_type  = "OrganizationAdmin"
    bypass_mode = "always"
  }

  # Deploy keys can't be listed individually; Flux's is the repo's only one. Its image
  # automation commits tag bumps straight to main.
  bypass_actors {
    actor_type  = "DeployKey"
    bypass_mode = "always"
  }

  rules {
    deletion         = true
    non_fast_forward = true

    pull_request {
      required_approving_review_count = 0
      require_code_owner_review       = true
      dismiss_stale_reviews_on_push   = true
    }

    # Not "checks": exercise 6 is merging a broken manifest on purpose and watching Flux report it.
    required_status_checks {
      required_check {
        context = "tenant-paths"
      }
      required_check {
        context = "gitleaks"
      }
    }
  }
}
