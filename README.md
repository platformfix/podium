# podium

[![image](https://github.com/platformfix/podium/actions/workflows/image.yml/badge.svg)](https://github.com/platformfix/podium/actions/workflows/image.yml)
[![broadcast-e2e](https://github.com/platformfix/podium/actions/workflows/broadcast-e2e.yml/badge.svg)](https://github.com/platformfix/podium/actions/workflows/broadcast-e2e.yml)
[![commit-lint](https://github.com/platformfix/podium/actions/workflows/commit-lint.yaml/badge.svg)](https://github.com/platformfix/podium/actions/workflows/commit-lint.yaml)
[![pr-lint](https://github.com/platformfix/podium/actions/workflows/pr-lint.yml/badge.svg)](https://github.com/platformfix/podium/actions/workflows/pr-lint.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A shell in a pod for delivering Kubernetes training, with a self-hosted live-terminal broadcast so participants can watch your commands as you type them.

Built by [Platform Fix](https://platformfix.com) for our own Kubernetes classes, and shared publicly because we point students at it.

## What this is

You deploy `podium` once, on your own cluster, and attach to it as your terminal for the session:

```bash
helm repo add platformfix https://platformfix.github.io/podium
helm upgrade --install podium platformfix/podium \
  --set rbac.cluster.clusterRoles="{cluster-admin}"
kubectl wait deployment/podium --for=condition=Available
kubectl attach -it deployment/podium -- login -f k8s
```

Everything you type runs from inside your own cluster, with `kubectl`, `helm`, and the rest of the toolchain preconfigured. The shell is zsh with a starship prompt, so it looks and feels like a normal terminal rather than a bare container. The chart pulls its image from `ghcr.io/platformfix/podium` by default, rebuilt on every push to `main`.

Use `-- login -f k8s`, not `-- sh` or `-- bash`. `kubectl exec`/`attach` land you in whatever command you give them, and only `login -f k8s` switches to the `k8s` user and loads its shell: zsh, the starship prompt, and the `kubectl`/`k` aliases. `-- sh` drops you into a bare root shell in `/` with none of that configured. The one exception is `k` itself, which is a real binary (not a shell alias), so it resolves to colorized `kubectl` output even from a plain `sh`.

Optionally, turn on the broadcast sidecar and share the resulting URL with your class:

```bash
helm upgrade --install podium platformfix/podium \
  --set rbac.cluster.clusterRoles="{cluster-admin}" \
  --set broadcast.enabled=true \
  --set broadcast.service.type=NodePort
```

They'll see a live-updating page showing each command as you run it: no install, no login, just the URL. The page and its WebSocket server are both vendored in this repo's own image; nothing is fetched from a third party at runtime.

## Why not just use shpod?

[shpod](https://github.com/jpetazzo/shpod) is a great tool, and `podium` borrows its overall shape: a container image plus a Helm chart, multi-arch, deployed straight onto a cluster. It's built for a different job, though: it hands an isolated shell to *each* student, reachable over SSH. `podium` is narrower on purpose: one pod, for the trainer, attached to with `kubectl` rather than SSH, with the terminal broadcast built into the chart instead of a manual setup script.

## Installing

### From the Helm chart repo (recommended)

```bash
helm repo add platformfix https://platformfix.github.io/podium
helm upgrade --install podium platformfix/podium
kubectl wait deployment/podium --for=condition=Available
kubectl attach -it deployment/podium -- login -f k8s
```

### Or straight from a clone

```bash
git clone https://github.com/platformfix/podium
helm upgrade --install podium ./podium/helm/podium
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

If every attendee gets their own dedicated cluster for the training (rather than sharing the trainer's), the same chart works for their shell too: `cluster-admin` and a persistent `$HOME` are both safe defaults there, since there's no other tenant on the cluster to protect against. [`examples/attendee-cluster-values.yaml`](examples/attendee-cluster-values.yaml) has the recommended values for that case (cluster-admin, a 2G PVC, and sane resource limits so the training survives a Pod restart). Install it per attendee into its own namespace; they attach from their bastion node:

```bash
helm upgrade --install podium platformfix/podium \
  --namespace podium --create-namespace \
  -f examples/attendee-cluster-values.yaml
kubectl attach -it deployment/podium --namespace podium -- login -f k8s
```

Leave the broadcast sidecar off in this case; it's for the trainer's own pod, not each attendee's.

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

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Commits and pull request titles must follow [Conventional Commits](https://www.conventionalcommits.org/); this is enforced by CI.

## License

[MIT](LICENSE)
