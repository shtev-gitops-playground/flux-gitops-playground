# How it works

This page follows the playground from the bottom up: what Terraform builds, what Flux does with this
repo, how your app gets updated when you release a new image, and how logging in with GitHub turns
into permissions on the cluster.

## Terraform builds the ground floor

Flux can only manage a cluster that already exists, from a repo that already exists. Those come from
Terraform, in `infra/`, applied by hand by the operator:

| Stack | Builds |
|---|---|
| `infra/bootstrap` | The S3 bucket that holds Terraform's own state |
| `infra/hetzner` | One Hetzner server running [k3s](https://k3s.io), its firewall, and DNS records for `api.`, `dex.` and `*.gitops.shtev.dev` |
| `infra/github` | This repo, its rules for `main`, and the `release` environment |
| `infra/flux` | Flux itself (via the `flux` Terraform provider), Flux's deploy key, and the one secret Dex needs |

From then on, the rule is: **if it's in the cluster, it came from this repo**. The handful of
exceptions are secrets, listed at the end.

## Flux's controllers

Flux is a set of controllers in the `flux-system` namespace. Each one watches its own kinds of
object and keeps reality matching them:

| Controller | Watches | Does |
|---|---|---|
| source-controller | `GitRepository`, `HelmRepository` | Fetches Git commits and Helm charts, packages them as "artifacts" |
| kustomize-controller | `Kustomization` | Runs `kustomize build` on a path in an artifact and applies the result |
| helm-controller | `HelmRelease` | Installs and upgrades Helm charts |
| image-reflector-controller | `ImageRepository`, `ImagePolicy` | Lists tags in a registry and picks one by a rule |
| image-automation-controller | `ImageUpdateAutomation` | Writes the picked tags into Git and commits |
| notification-controller | `Alert`, `Provider`, `Receiver` | Sends and receives events (not used here yet) |

Look at them yourself:

```bash
kubectl get pods -n flux-system
kubectl get gitrepositories,kustomizations,helmreleases -A
```

## The reconcile loop

Every Flux object has an `interval`. On each tick, its controller compares what Git says against
what's in the cluster and fixes any difference:

1. **source-controller** pulls `main` (every minute) and records the commit as an artifact.
2. **kustomize-controller** builds each Kustomization's path from that artifact and applies it with
   server-side apply. With `prune: true`, anything that disappeared from Git is deleted from the cluster.
3. Each object reports `Ready` and the revision it applied, which is what you see in `kubectl get`.

Because the loop runs whether or not Git changed, **changes made by hand get undone** (exercise 4).
To ask for a reconcile now instead of waiting, annotate the object:

```bash
kubectl -n play-<you> annotate gitrepository playground reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
kubectl -n play-<you> annotate kustomization app reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
```

(That's all `flux reconcile` does under the hood.)

### What gets applied, in what order

Flux starts at `clusters/playground/`. The bootstrap created `flux-system/` there; everything else is
ours:

```text
flux-system            clusters/playground/flux-system   Flux syncing itself
infrastructure         infrastructure/controllers        cert-manager, Dex (HelmReleases)
infrastructure-config  infrastructure/config             ClusterIssuer, RBAC, image automation, policies
tenants                platform/tenants                  one namespace + permissions + syncs per player
<you>-images           tenants/<you>/images              your ImagePolicy (into flux-system)
app (in play-<you>)    tenants/<you>/app                 your app (into play-<you>)
```

`dependsOn` makes each wait for the one before. For example, the ClusterIssuer can't be created
until cert-manager has installed the `ClusterIssuer` type.

## Sharing a cluster safely: multi-tenancy lockdown

Flux's controllers have cluster-admin rights. Left as they are, anyone who can get a manifest merged
could make Flux do anything. So Flux runs with the
[multi-tenancy lockdown](https://fluxcd.io/flux/installation/configuration/multitenancy/)
flags (see `infra/flux/lockdown.yaml`):

- **`--default-service-account=default`.** A Kustomization acts with the permissions of a service
  account in its own namespace. If it doesn't name one, it gets that namespace's `default` account,
  which can do nothing. The platform's own Kustomizations name Flux's account explicitly.
- **`--no-cross-namespace-refs`.** Objects can only refer to sources and policies in their own
  namespace.
- **`--no-remote-bases`.** Manifests must come from this repo, not from URLs pulled in at build time.

Your area is set up to work within that (`platform/tenants/<you>/`):

- Your namespace `play-<you>` has a service account, `flux-tenant`, that is admin **in that
  namespace only**.
- Your `app` Kustomization lives in `play-<you>` and acts as `flux-tenant`. Anything in
  `tenants/<you>/app` that tries to reach outside your namespace simply fails to apply.
- Your namespace has its own `GitRepository`, reading this (public) repo anonymously and trimmed to
  your folder, because the lockdown stops it borrowing the one in `flux-system`.
- Your `<you>-images` Kustomization applies your ImagePolicy into `flux-system`. It acts as an
  account that can **only** manage ImagePolicies (see "Image automation" for why it lives there).
- A `ValidatingAdmissionPolicy` (`infrastructure/config/policies`) stops an Ingress in your namespace
  claiming any hostname except `<you>.gitops.shtev.dev`.

On GitHub's side, PRs that only touch `tenants/<you>/` merge without review. A check called
`tenant-paths` fails any PR that touches someone else's folder, and `CODEOWNERS` makes everything
outside `tenants/` need Steve's review.

## Image automation: from a new tag to a Git commit

This is the part you've probably only seen from the outside.

```text
 release button ─▶ ghcr.io/…/demo-app:<you>-1.2.0
                          │  ImageRepository "demo-app" lists tags every minute
                          ▼
                   ImagePolicy "<you>-demo-app"
                     filterTags  ^<you>-(?P<version>.+)$   keep only your tags, read the version
                     semver      >=1.0.0                   pick the highest that fits
                          │  latest: <you>-1.2.0
                          ▼
                   ImageUpdateAutomation "tenants"
                     finds   # {"$imagepolicy": "flux-system:<you>-demo-app"}   in tenants/
                     rewrites that line to the new tag, commits as fluxcdbot, pushes to main
                          │
                          ▼
                   your GitRepository sees the commit ─▶ your app Kustomization applies it ─▶ rollout
```

Things worth noticing:

- **The marker comment is the whole contract.** Open `tenants/<you>/app/deployment.yaml`: the
  automation only touches lines carrying `{"$imagepolicy": …}`.
- **The cluster changes because Git changed.** Image automation never touches the Deployment
  directly. It commits, and the normal reconcile loop does the rest, so Git stays the record of
  what's running.
- **Your ImagePolicy lives in `flux-system`** because an `ImageUpdateAutomation` only reads
  policies from its own namespace, and keeping it in `flux-system` means Flux's write access to
  the repo never has to sit in your namespace.
- **`fluxcdbot` pushes straight to `main`** although `main` requires PRs: the ruleset lets Flux's
  deploy key bypass it.
- **Release tags carry your login** (`<you>-1.2.0`), so your releases only ever move your app.

```bash
kubectl get imagerepository demo-app -n flux-system
kubectl get imagepolicies -n flux-system
kubectl get imageupdateautomation tenants -n flux-system
```

## Logging in: GitHub → Dex → API server → RBAC

1. `kubectl` runs `kubectl oidc-login get-token` (that's the `exec` section in your kubeconfig).
2. That opens Dex (`https://dex.gitops.shtev.dev`), which sends you to GitHub to log in.
3. Dex asks GitHub which teams you're in, and refuses anyone not in
   `shtev-gitops-playground/players`.
4. Dex gives `kubectl` a signed ID token containing your login and team. It expires after an hour,
   and a refresh token renews it.
5. The API server trusts tokens signed by Dex (set in k3s's `AuthenticationConfiguration`). It
   turns yours into user `github:<your-login>` in group `github:shtev-gitops-playground:players`,
   and double-checks the team itself.
6. RBAC takes it from there:
   - The group gets **`playground-viewer`**: read access to most things everywhere, but no Secrets.
   - Your user gets **`admin`** in `play-<you>`.

Try `kubectl auth whoami` and `kubectl auth can-i --list -n play-<you>`.

## What isn't in Git

Secrets never go in this repo. These are created by Terraform from the operator's password manager:

- Dex's GitHub OAuth client ID and secret (Secret `dex/github-oauth`)
- Flux's deploy key (Secret `flux-system/flux-system`)
- The release workflow's registry token (GitHub `release` environment secret)

And these the cluster makes for itself: Let's Encrypt account keys, TLS certificates, and Dex's
signing keys.
