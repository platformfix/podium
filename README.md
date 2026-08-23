# podium

[![image](https://github.com/platformfix/podium/actions/workflows/image.yml/badge.svg)](https://github.com/platformfix/podium/actions/workflows/image.yml)
[![e2e](https://github.com/platformfix/podium/actions/workflows/e2e.yml/badge.svg)](https://github.com/platformfix/podium/actions/workflows/e2e.yml)
[![commit-lint](https://github.com/platformfix/podium/actions/workflows/commit-lint.yaml/badge.svg)](https://github.com/platformfix/podium/actions/workflows/commit-lint.yaml)
[![pr-lint](https://github.com/platformfix/podium/actions/workflows/pr-lint.yml/badge.svg)](https://github.com/platformfix/podium/actions/workflows/pr-lint.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/platformfix/podium/badge)](https://scorecard.dev/viewer/?uri=github.com/platformfix/podium)
[![Latest Release](https://img.shields.io/github/v/release/platformfix/podium)](https://github.com/platformfix/podium/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A shell in a pod for delivering Kubernetes training, with a self-hosted live-terminal broadcast so participants can watch your commands as you type them.

Built by [Platform Fix](https://platformfix.com) for our own Kubernetes classes, and shared publicly because we point students at it.

## What this is

On your own teacher cluster:

```bash
git clone https://github.com/platformfix/podium && cd podium
make presenter
```

`make presenter` installs the chart with `cluster-admin` and the broadcast sidecar turned on, waits for it to be ready, and attaches you to it, all in one step. Everything you type from there runs from inside your own cluster, with `kubectl`, `helm`, and the rest of the toolchain preconfigured. The shell is zsh with a starship prompt, so it looks and feels like a normal terminal rather than a bare container. The chart pulls its image from `ghcr.io/platformfix/podium` by default, rebuilt on every push to `main`.

That's the same as running the steps by hand:

```bash
helm repo add platformfix https://platformfix.github.io/podium
helm upgrade --install podium platformfix/podium \
  --namespace podium --create-namespace \
  --set rbac.cluster.clusterRoles="{cluster-admin}" \
  --set broadcast.enabled=true \
  --set broadcast.service.type=NodePort
kubectl wait deployment/podium --namespace podium --for=condition=Available
kubectl attach -it deployment/podium --namespace podium -c podium
```

Once attached, share the broadcast page's URL with your class: they'll see a live-updating page showing each command as you run it, no install, no login, just the URL. The page and its WebSocket server are both vendored in this repo's own image; nothing is fetched from a third party at runtime.

With `kubectl exec`, use `-- login -f -p k8s`, not `-- sh` or `-- bash`. `kubectl exec` runs whatever command you give it; only `login -f -p k8s` switches to the `k8s` user and loads its shell: zsh, the starship prompt, and the `kubectl`/`k` aliases. `-- sh` drops you into a bare root shell in `/` with none of that configured. The `-p` matters too: BusyBox `login` wipes the environment by default, and without it `kubectl` inside the shell can't find the in-cluster API server. `kubectl attach` doesn't have this problem at all, since it just connects to the shell the entrypoint already started with the environment intact.

## Why not just use shpod?

[shpod](https://github.com/jpetazzo/shpod) is a great tool, and `podium` borrows its overall shape: a container image plus a Helm chart, multi-arch, deployed straight onto a cluster. It's built for a different job, though: it hands an isolated shell to *each* student, reachable over SSH. `podium` is narrower on purpose: one pod, for the trainer, attached to with `kubectl` rather than SSH, with the terminal broadcast built into the chart instead of a manual setup script.

## Installing

### `make presenter` / `make attendee`

The Makefile wraps the full install, from a clean clone to being attached, for the two people who actually run this: you, and each attendee.

| Target | Who it's for | What it sets |
|---|---|---|
| `make presenter` | You, on your teacher cluster | `cluster-admin`, broadcast sidecar on (`NodePort`) |
| `make attendee` | Each attendee, on their own dedicated cluster | `cluster-admin`, a persistent `$HOME` (see [`examples/attendee-cluster-values.yaml`](examples/attendee-cluster-values.yaml)), broadcast off |

```bash
git clone https://github.com/platformfix/podium && cd podium
make attendee
```

That's the whole onboarding step for an attendee: clone, `make attendee`, and they're attached to a ready-to-use shell. Both targets add the Helm chart repo automatically, and both install into a `podium` namespace rather than whatever the cluster's default happens to be, so podium's footprint stays in one predictable, easy-to-clean-up place. Override `RELEASE_NAME`, `NAMESPACE`, or `HELM_REPO_URL` as `make` variables if you need something other than the defaults.

### By hand, from the chart repo

```bash
helm repo add platformfix https://platformfix.github.io/podium
helm upgrade --install podium platformfix/podium --namespace podium --create-namespace
kubectl wait deployment/podium --namespace podium --for=condition=Available
kubectl attach -it deployment/podium --namespace podium -c podium
```

### Or straight from a clone, without the chart repo

```bash
git clone https://github.com/platformfix/podium
helm upgrade --install podium ./podium/helm/podium --namespace podium --create-namespace
```

See [`helm/podium/values.yaml`](helm/podium/values.yaml) for every setting.

## Configuration

The chart is configured entirely through `values.yaml`. The full reference lives in [`helm/podium/values.yaml`](helm/podium/values.yaml); the settings you're most likely to touch:

| Value | Default | What it does |
|---|---|---|
| `rbac.cluster.clusterRoles` | `[]` | ClusterRoles to bind to podium's ServiceAccount, cluster-wide. Set to `{cluster-admin}` on a dedicated teacher cluster. |
| `persistentVolume.enabled` | `false` | Puts `$HOME` on a PVC so it survives a Pod restart or eviction, instead of an `emptyDir`. |
| `ssh.enabled` | `false` | Starts an SSH server instead of relying on `kubectl attach`/`exec`. Off by default; podium is meant to be reached with `kubectl`. |
| `broadcast.enabled` | `false` | Adds the live-terminal-broadcast sidecar and its Service. |
| `broadcast.service.type` | `ClusterIP` | Set to `NodePort` or `LoadBalancer` to give training participants a reachable URL. |
| `resources` | `{}` | Set requests/limits, especially memory, so the Pod isn't evicted under node pressure mid-session. |

## Running it for attendees, not just the trainer

`make attendee` (above) is the actual onboarding step: an attendee clones the repo on their workshop bastion node and runs it once their cluster is up. It works because every attendee gets their own dedicated cluster for the training, rather than sharing the trainer's, so `cluster-admin` and a persistent `$HOME` are both safe defaults there: there's no other tenant on that cluster to protect against. The broadcast sidecar stays off for attendees; it's for the trainer's own pod, so their class can watch, not something each attendee needs themselves.

## How the broadcast works

`broadcast.enabled=true` adds a second container to the Pod that tails the shell's history file and serves it over a WebSocket, alongside a small static page that renders each line as it arrives. Both the page and the server share the same `$HOME` volume as your shell, so nothing needs wiring together by hand: no `kubectl patch`, no fetching a viewer page from elsewhere. Point participants at the Service's URL (see `kubectl get service podium-broadcast` after install) and they'll see what you type in near-real time.

## What's in the image

Alpine-based, multi-arch (`amd64`/`arm64`), built and published to `ghcr.io/platformfix/podium` on every push to `main` and every tag.

- kubectl, Helm, Kustomize
- k9s, stern, kube-linter, popeye
- ArgoCD CLI, Flux CLI, Velero CLI
- kubeseal, crane, regctl
- kubecolor, jq, yq, git, fzf, vim, tmux
- zsh + starship

Run `cat ~/versions.txt` inside the pod for exact installed versions.

## Supply chain security

Every image push is signed and gets a build provenance attestation, generated by GitHub's own Sigstore-backed [artifact attestations](https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds), not a manually maintained signature. Verify any tag with the GitHub CLI:

```bash
gh attestation verify oci://ghcr.io/platformfix/podium:latest --owner platformfix
```

The repo also runs an [OpenSSF Scorecard](https://scorecard.dev/) check on every push (badge above), and the Helm chart repo carries the metadata [Artifact Hub](https://artifacthub.io/) needs to list it (not yet claimed there). See [SECURITY.md](SECURITY.md) to report a vulnerability.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Commits and pull request titles must follow [Conventional Commits](https://www.conventionalcommits.org/); this is enforced by CI.

## License

[MIT](LICENSE)
