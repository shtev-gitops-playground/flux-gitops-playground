resource "github_repository" "playground" {
  name        = "flux-gitops-playground"
  description = "A live Kubernetes cluster run by Flux, for learning GitOps from the platform side."
  visibility  = "public"

  has_issues             = true
  has_wiki               = false
  has_projects           = false
  delete_branch_on_merge = true
  allow_auto_merge       = true

  # Keep the repo if this stack is ever destroyed by mistake.
  lifecycle {
    prevent_destroy = true
  }
}
