# Exercises

Six short exercises, each building on the last. Replace `<you>` with your GitHub login **in lower
case** (for `JaneDoe`, that's `janedoe`).

Each step shows the **`flux` CLI** first, since that's what you'd use day to day, then what it's
doing **under the hood** with plain `kubectl`. The `flux` CLI is only a friendly client: everything
it does is reading or annotating ordinary Kubernetes objects, and the controllers do the actual work.

Handy to keep in a second terminal while you work:

```bash
flux get kustomizations -A --watch
```

## 1. Look around

**Goal:** find Flux's pieces and see how they relate.

```bash
flux check                                    # Flux's controllers and CRDs are healthy
flux get all -A                               # every Flux object, its revision and status
flux get sources git -A                       # where Flux reads Git from
flux get kustomizations -A                    # what it applies, and from which commit
flux get helmreleases -A                      # charts it installs (cert-manager, Dex)
flux tree kustomization app -n play-<you>     # what your area created
flux events -n play-<you>                     # what's been happening
flux stats -A                                 # counts of everything, by kind
```

**What you should see:** every object `Ready` at the same `main@sha1:…` revision. Yours are in
`play-<you>`; the platform's are in `flux-system`. Compare each Kustomization's path with the
folders in this repo.

**Under the hood:** they're just custom resources.

```bash
kubectl get gitrepositories,kustomizations,helmreleases -A
kubectl describe kustomization app -n play-<you>
kubectl get pods -n flux-system               # the controllers doing the work
```

Then try something you're not allowed to do:

```bash
kubectl get secrets -n flux-system
```

**What you should see:** `Forbidden`. You can read most things, but not secrets.

## 2. Add a manifest by PR

**Goal:** see a Git change become a cluster change, and preview it before you push.

1. Make a branch and add `tenants/<you>/app/configmap.yaml`:

   ```yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: hello
   data:
     greeting: "hello from Git"
   ```

2. List it in `tenants/<you>/app/kustomization.yaml` under `resources:`.
3. **Preview** what Flux would change, straight from your working copy:

   ```bash
   flux diff kustomization app -n play-<you> --path ./tenants/<you>/app
   ```

   It shows `ConfigMap/play-<you>/hello created` and exits non-zero because there are differences,
   which makes it useful in CI too.
4. Push, open a PR, and wait for the checks. A PR that only touches your own folder needs no review,
   so merge it yourself.
5. Don't wait for the next tick. Pull the new commit and apply it now:

   ```bash
   flux reconcile kustomization app -n play-<you> --with-source
   kubectl get configmap hello -n play-<you> -o yaml
   ```

**What you should see:** the reconcile reports your merge commit, and `hello` exists. Now delete
the file (and its line) in another PR, reconcile, and watch it disappear: `prune: true` removes
anything that's gone from Git.

**Under the hood:** `flux reconcile` just sets an annotation, which the controllers notice:

```bash
kubectl -n play-<you> annotate gitrepository playground reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
kubectl -n play-<you> annotate kustomization app reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
```

## 3. Release, and follow the chain

**Goal:** trace image automation end to end.

1. On GitHub: **Actions → release-demo-app → Run workflow**, version `1.0.0`.
2. When the run finishes, follow the chain. Each step takes up to a minute:

   ```bash
   flux get image repository demo-app -n flux-system         # sees the new tag <you>-1.0.0
   flux get image policy <you>-demo-app -n flux-system       # picks it
   flux get image update tenants -n flux-system              # commits it to Git
   git pull && git log -3 --format='%an: %s'                 # ...as fluxcdbot
   flux get kustomizations -n play-<you> --watch             # your area applies that commit
   ```

3. Open `https://<you>.gitops.shtev.dev`.
4. Release `1.1.0` and watch the colour change.

**What you should see:** a `fluxcdbot` commit editing `tenants/<you>/app/deployment.yaml`, and the
page showing your version. Your app starts on a shared `base-1.0.0` image, and until your first
release your ImagePolicy has nothing to pick, so it shows not ready. That's expected.

You can speed up your own area (`flux reconcile kustomization app -n play-<you> --with-source`), but
the image scanning in `flux-system` is the platform's, so `flux reconcile image repository …` there
is `Forbidden`.

Try releasing `1.1.0` again. The workflow refuses: releases are never overwritten.

**Under the hood:** `kubectl get imagerepository,imagepolicy,imageupdateautomation -n flux-system`.

## 4. Change something behind Flux's back

**Goal:** see why GitOps means "Git wins", and how to pause it when you need to.

```bash
kubectl -n play-<you> scale deploy demo-app --replicas=3
flux reconcile kustomization app -n play-<you>
kubectl -n play-<you> get deploy demo-app
```

**What you should see:** back to 1 replica. Flux re-applies what Git says, so the only lasting way
to change it is a PR.

Now pause Flux for your area, as you might while debugging something live:

```bash
flux suspend kustomization app -n play-<you>
kubectl -n play-<you> scale deploy demo-app --replicas=3
flux reconcile kustomization app -n play-<you>      # refuses: it's suspended
kubectl -n play-<you> get deploy demo-app           # still 3
flux resume kustomization app -n play-<you>         # reconciles straight away
kubectl -n play-<you> get deploy demo-app           # back to 1
```

**Under the hood:** `flux suspend` sets `spec.suspend: true` on the Kustomization. Look for it in
`kubectl get kustomization app -n play-<you> -o yaml` while it's suspended. Don't forget to resume!

## 5. Pin a version

**Goal:** control which releases you take.

1. In a PR, edit `tenants/<you>/images/image-policy.yaml` and change the range to `"~1.1"` (meaning
   1.1.x only). Merge it.
2. Release `1.2.0`. Your policy stays on `1.1.0`.
3. Release `1.1.1`. Now it moves.

```bash
flux get image policy <you>-demo-app -n flux-system --watch
```

**What you should see:** the policy ignores `1.2.0` and takes `1.1.1`. This is how teams keep
production on a patch line while new minors are being tried elsewhere. Put the range back to
`">=1.0.0"` when you're done, and watch it jump to `1.2.0`.

## 6. Break it, then fix it

**Goal:** read Flux's errors.

1. In a PR, break `tenants/<you>/app/deployment.yaml`. For example, change `replicas: 1` to
   `replicas: one`. `flux diff` on your branch would already have told you. The `checks` job on
   your PR will complain too, but that check isn't required, so merge it anyway and see what happens.
2. Look:

   ```bash
   flux get kustomizations -n play-<you>
   flux events -n play-<you> --for Kustomization/app
   flux logs --kind=Kustomization --name=app --namespace=play-<you>
   ```

**What you should see:** `Ready: False` with the exact error. Your running app stays as it was:
Flux applies all of a change or none of it. Fix it with another PR, then
`flux reconcile kustomization app -n play-<you> --with-source`.

## Going further

- `flux get all -A --status-selector ready=false` lists anything unhealthy.
- `flux export kustomization app -n play-<you>` prints the object as YAML you could commit.
- `flux trace deployment demo-app -n play-<you>` explains which Flux object manages a resource and
  which commit it came from.
