# Exercises

Six short exercises, each building on the last. Replace `<you>` with your GitHub login **in lower
case** (for `JaneDoe`, that's `janedoe`). Everything here uses plain `kubectl`.

Handy to keep in a second terminal while you work:

```bash
kubectl get kustomizations -A --watch
```

To skip waiting for Flux's next tick, ask your area to sync now:

```bash
kubectl -n play-<you> annotate gitrepository playground reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
kubectl -n play-<you> annotate kustomization app reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
```

## 1. Look around

**Goal:** find Flux's pieces and see how they relate.

```bash
kubectl get pods -n flux-system                       # the controllers
kubectl get gitrepositories -A                        # where Flux reads Git from
kubectl get kustomizations -A                         # what it applies, and which commit
kubectl get helmreleases -A                           # charts it installs
kubectl describe kustomization app -n play-<you>      # your area, in detail
kubectl get events -n play-<you> --sort-by=.lastTimestamp
kubectl logs -n flux-system deploy/kustomize-controller --tail=20
```

**What you should see:** every Kustomization `Ready` at the same `main@sha1:…` revision. Yours
is in `play-<you>`; the platform's are in `flux-system`. Compare the `PATH` of each with the folders
in this repo.

Then try something you're not allowed to do:

```bash
kubectl get secrets -n flux-system
```

**What you should see:** `Forbidden`. You can read most things, but not secrets.

## 2. Add a manifest by PR

**Goal:** see a Git change become a cluster change.

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
3. Push, open a PR, and wait for the checks. A PR that only touches your own folder needs no review,
   so merge it yourself.
4. Watch it arrive (or trigger a sync as shown at the top):

   ```bash
   kubectl get kustomization app -n play-<you> --watch
   kubectl get configmap hello -n play-<you> -o yaml
   ```

**What you should see:** the Kustomization's revision moves to your merge commit, and `hello`
appears. Now delete the file (and its line) in another PR and watch it disappear, because `prune: true`.

## 3. Release, and follow the chain

**Goal:** trace image automation end to end.

1. On GitHub: **Actions → release-demo-app → Run workflow**, version `1.0.0`.
2. When the run finishes, follow the chain. Each step takes up to a minute:

   ```bash
   kubectl get imagerepository demo-app -n flux-system        # sees the new tag <you>-1.0.0
   kubectl get imagepolicy <you>-demo-app -n flux-system      # picks it
   git pull && git log -3 --format='%an: %s'                  # fluxcdbot committed it
   kubectl -n play-<you> rollout status deploy/demo-app       # rolled out
   ```

3. Open `https://<you>.gitops.shtev.dev`.
4. Release `1.1.0` and watch the colour change.

**What you should see:** a `fluxcdbot` commit editing `tenants/<you>/app/deployment.yaml`, and the
page showing your version. Your app starts on a shared `base-1.0.0` image, and until your first
release your ImagePolicy has nothing to pick, so it shows not ready. That's expected.

Try releasing `1.1.0` again. The workflow refuses: releases are never overwritten.

## 4. Change something behind Flux's back

**Goal:** see why GitOps means "Git wins".

```bash
kubectl -n play-<you> scale deploy demo-app --replicas=3
kubectl -n play-<you> get deploy demo-app
```

Now trigger a sync (top of this page) and look again.

**What you should see:** back to 1 replica. Flux re-applies what Git says, so the only lasting way
to change it is a PR. Try deleting the Service with `kubectl delete svc demo-app -n play-<you>` too.

## 5. Pin a version

**Goal:** control which releases you take.

1. In a PR, edit `tenants/<you>/images/image-policy.yaml` and change the range to `"~1.1"` (meaning
   1.1.x only). Merge it.
2. Release `1.2.0`. Watch your ImagePolicy: it stays on `1.1.0`.
3. Release `1.1.1`. Now it moves.

```bash
kubectl get imagepolicy <you>-demo-app -n flux-system --watch
```

**What you should see:** the policy ignores `1.2.0` and takes `1.1.1`. This is how teams keep
production on a patch line while new minors are being tried elsewhere. Put the range back to
`">=1.0.0"` when you're done.

## 6. Break it, then fix it

**Goal:** read Flux's errors.

1. In a PR, break `tenants/<you>/app/deployment.yaml`. For example, change `replicas: 1` to
   `replicas: one`. The `checks` job on your PR will complain. Merge it anyway: that check isn't
   required, so you can see what happens.
2. Look:

   ```bash
   kubectl get kustomization app -n play-<you>
   kubectl describe kustomization app -n play-<you>
   kubectl get events -n play-<you> --field-selector involvedObject.kind=Kustomization
   ```

**What you should see:** `Ready: False` with the exact error. Your running app stays as it was:
Flux applies all of a change or none of it. Fix it with another PR and watch it go green.

## Bonus: the flux CLI

The [`flux` CLI](https://fluxcd.io/flux/installation/#install-the-flux-cli) is a friendlier view of
the same objects, and works with your read-only access:

```bash
flux get all -n play-<you>
flux get images all -n flux-system
flux tree kustomization app -n play-<you>
```

It's also how you'd usually trigger syncs (`flux reconcile kustomization app -n play-<you> --with-source`).
