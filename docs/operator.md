# Operator guide

For whoever runs the playground. Players don't need any of this.

## What you need

- Terraform ≥ 1.10, `kubectl`, `tflint`, `shellcheck`, `gitleaks`, `kubeconform`, `gh`, Docker
- The 1Password CLI (`op`) with access to these items in the **Projects** vault:

  | Item | Used for |
  |---|---|
  | GitOps Playground Hetzner API Token | `infra/hetzner` |
  | GitOps Playground SSH Key | SSH to the server (also loaded into the 1Password SSH agent) |
  | GitOps Playground GitHub Terraform Token | `infra/github`, `infra/flux`; fine-grained, owner `shtev-gitops-playground` |
  | GitOps Playground GitHub OAuth | Dex's OAuth app (fields `client ID`, `secret`) |
  | GitOps Playground GHCR Push Token | The release workflow; classic token, `write:packages` only |

- AWS access to the state bucket and the `shtev.dev` Route 53 zone (`aws sso login --profile <your-profile>`)

Put your AWS profile and 1Password account in `scripts/tf-env.local` (git-ignored; copy
`scripts/tf-env.local.example`), then load everything for a Terraform session with:

```bash
. scripts/tf-env.sh
```

Each stack is initialised with the git-ignored `infra/backend.hcl` (copy `backend.hcl.example`):

```bash
cd infra/<stack> && terraform init -backend-config=../backend.hcl
```

## Building from scratch

Apply in this order. Each step needs the one before.

1. **`infra/bootstrap`**: the state bucket. First apply runs with local state, then
   `terraform init -migrate-state -backend-config=../backend.hcl`.
2. **`infra/hetzner`**: copy `terraform.tfvars.example` to `terraform.tfvars`, set your IP and
   the SSH public key, then apply. Fetch the admin kubeconfig with `scripts/admin-kubeconfig.sh`
   (writes `~/.kube/gitops-playground-admin`, which is cluster-admin: never share it).
3. **`infra/github`**: the repo, the `release` environment and the ruleset on `main`.
4. **`infra/flux`**: installs Flux, adds its deploy key, and creates `dex/github-oauth`. From here
   Flux builds the rest from Git within a few minutes.

One-time manual steps on GitHub, none of which Terraform can do:

- Create the org and its `players` team.
- Create the org-owned OAuth app *GitOps Playground*, with callback
  `https://dex.gitops.shtev.dev/callback`.
- Allow deploy keys: org Settings → **Security and quality**. They're off by default for new orgs.
- After the first image push, make the `demo-app` package **public** (org → Packages → demo-app →
  Package settings). Under *Manage Actions access*, make sure the repo is **not** listed.
- Publish the starter image once:
  `docker build --platform linux/amd64 --build-arg VERSION=1.0.0 -t ghcr.io/shtev-gitops-playground/demo-app:base-1.0.0 apps/demo-app`,
  then push it using the GHCR token.

## Adding a player

1. Invite them to the org and add them to the **`players`** team.
2. Run `scripts/new-tenant.sh <their-github-login>` (exact case, e.g. `JaneDoe`). It creates
   `platform/tenants/<lc>/` and `tenants/<lc>/` and lists them in `platform/tenants/kustomization.yaml`.
3. Commit and push to `main` (you can bypass the PR rule), or open a PR.
4. Send them the repo link and [setup.md](setup.md).

They start on `base-1.0.0`. Their first release (exercise 3) gives them their own image.

## Removing a player

1. Remove them from the `players` team. Their next token refresh fails, and existing tokens expire
   within an hour.
2. Delete `platform/tenants/<lc>/` and `tenants/<lc>/`, and their line in
   `platform/tenants/kustomization.yaml`. Push. Flux prunes their namespace and everything in it.
3. Optionally delete their `<lc>-*` tags from the `demo-app` package.

## Checks

```bash
scripts/validate-manifests.sh          # every kustomization builds and matches its schemas
scripts/test/access-matrix.sh          # who can do what (needs the admin kubeconfig)
scripts/test/tenant-paths.test.sh
scripts/test/new-tenant.test.sh
scripts/test/release-tag.test.sh
scripts/test/install-tools.test.sh     # needs Docker
(cd apps/demo-app && go test ./...)
```

## Rotating credentials

| What | How often | How |
|---|---|---|
| GHCR push token | 90 days | New classic token (`write:packages` only) → update 1Password → `. scripts/tf-env.sh` → apply `infra/github` |
| GitHub Terraform token | 90 days | New fine-grained token → update 1Password |
| Dex OAuth secret | When needed | New secret on the OAuth app → update 1Password → apply `infra/flux` → `kubectl -n dex rollout restart deploy/dex` |
| Flux deploy key | When needed | `terraform apply -replace=tls_private_key.flux` in `infra/flux` |
| Hetzner token | When needed | Update 1Password |

## Things that bit us

- **k3s and anonymous access.** Giving k3s an `authentication-config` file stops it disabling
  anonymous access itself, so the file sets `anonymous.enabled: false`.
- **Dex's code-based login** needs `/device/callback` as a redirect URI on the client, written
  exactly like that, as a relative path.
- **Lockdown means naming service accounts.** Every platform Kustomization and HelmRelease in
  `flux-system` sets `serviceAccountName` (`kustomize-controller` or `helm-controller`), or it runs
  with no permissions.
- **New org packages are private**, and visibility can only be changed in the GitHub UI.

## Tearing it down

1. `infra/flux`: `terraform destroy`. This uninstalls Flux, but leaves the workloads it created.
2. `infra/hetzner`: `terraform destroy` removes the server, IP, firewall and DNS records. The cluster
   goes with the server.
3. `infra/github`: the repo has `prevent_destroy`. Archive it in the GitHub UI instead, or remove
   the lifecycle block first if you really mean it.
4. `infra/bootstrap`: only if you're done for good. Empty the bucket first.

Diagram sources are `docs/diagrams/*.mmd`; after editing one, run `scripts/render-diagrams.sh` (needs Docker) and commit the SVGs.
