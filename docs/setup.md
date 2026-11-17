# Setup

You need `kubectl`, its login plugin `kubelogin`, and the `flux` CLI. The same steps work on **WSL**,
**Linux** and **macOS**. You also need `git`, `curl`, `unzip` and `tar`.

Before you start, accept the invitation to the
[`shtev-gitops-playground`](https://github.com/shtev-gitops-playground) org. Steve adds you to the
`players` team, which is what lets you log in.

## 1. Get the repo

```bash
git clone https://github.com/shtev-gitops-playground/flux-gitops-playground.git
cd flux-gitops-playground
```

## 2. Install the tools

### WSL or Linux

```bash
bash scripts/install-tools.sh
```

This puts `kubectl`, `kubectl-oidc_login` and `flux` in `~/.local/bin`, and checks their checksums.
`flux` matches the version running on the cluster. If it
tells you to add `~/.local/bin` to your `PATH`, do that and open a new terminal.

Already have a recent `kubectl`? The script installs its own copy into `~/.local/bin`, which is fine
to keep. Whichever comes first in your `PATH` wins.

### macOS

Either use the same script:

```bash
bash scripts/install-tools.sh
```

or Homebrew:

```bash
brew install kubectl int128/kubelogin/kubelogin fluxcd/tap/flux
```

Check it worked:

```bash
kubectl version --client
kubectl oidc-login --version
flux --version
```

## 3. Point kubectl at the playground

Copy the kubeconfig out of the repo, so you can tweak your copy without changing the repo:

```bash
cp kubeconfig/playground.yaml ~/.kube/playground.yaml
export KUBECONFIG=~/.kube/playground.yaml
```

Add that `export` line to `~/.bashrc` (or `~/.zshrc`) to keep it. If you'd rather not switch your
default, pass `--kubeconfig ~/.kube/playground.yaml` on each command instead.

## 4. Log in

```bash
kubectl auth whoami
```

The first time, a browser opens on GitHub's **Authorize GitOps Playground** page. Approve it and
you're done. You should see:

```text
ATTRIBUTE   VALUE
Username    github:<your-login>
Groups      [github:shtev-gitops-playground:players system:authenticated]
```

Then check Flux can see the cluster through your login:

```bash
flux check
```

Your login lasts an hour and then renews itself quietly for up to a week of not using it. It's
cached in `~/.kube/cache/oidc-login/`.

### WSL: if no browser opens

`kubelogin` prints a `http://localhost:8000` URL. Open it in your Windows browser: WSL2 shares
`localhost` with Windows, so the login completes back in your terminal.

If that doesn't work (or you're on a machine with no browser at all), log in with a code instead.
Edit `~/.kube/playground.yaml` and uncomment this line:

```yaml
          # - --grant-type=device-code
```

Then run `kubectl auth whoami` again. It prints a URL with a code. Open it on any device, sign in
with GitHub, and the terminal carries on.

## Troubleshooting

| You see | Try |
|---|---|
| `unknown command "oidc-login"` | `~/.local/bin` isn't on your `PATH`. |
| Dex says *"user … not in required orgs or teams"* | You haven't accepted the org invite yet, or Steve hasn't added you to `players`. |
| `error: You must be logged in to the server (Unauthorized)` | Clear the cached login and try again: `rm -rf ~/.kube/cache/oidc-login` |
| `Forbidden` on something in another namespace | That's expected. You can read most things but only change `play-<you>`. |
| Anything else | Run the command again with `-v=6` to see what's happening, and ask Steve. |

Next: [exercises](exercises.md).
