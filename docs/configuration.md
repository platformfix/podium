# Configuration

The chart is configured entirely through `values.yaml`; every setting is documented inline in [`helm/podium/values.yaml`](../helm/podium/values.yaml). The ones you're most likely to touch:

| Value | Default | What it does |
|---|---|---|
| `rbac.cluster.clusterRoles` | `[]` | ClusterRoles to bind to podium's ServiceAccount, cluster-wide. Set to `{cluster-admin}` on a dedicated teacher or attendee cluster. |
| `rbac.namespace.clusterRoles` | `[view]` | ClusterRoles bound only within the release namespace, when you don't want cluster-wide access. |
| `persistentVolume.enabled` | `false` | Puts `$HOME` on a PVC so it survives a Pod restart or eviction, instead of an `emptyDir`. |
| `persistentVolume.size` | `1G` | PVC size, when `persistentVolume.enabled` is true. |
| `ssh.enabled` | `false` | Starts an SSH server instead of relying on `kubectl attach`/`exec`. Off by default; podium is meant to be reached with `kubectl`. |
| `broadcast.enabled` | `false` | Adds the live-terminal-broadcast sidecar and its Service. See [architecture](architecture.md) for how it works. |
| `broadcast.service.type` | `ClusterIP` | Set to `NodePort` or `LoadBalancer` to give training participants a reachable URL. |
| `resources` | `{}` | Set requests/limits, especially memory, so the Pod isn't evicted under node pressure mid-session. |
| `image.pullPolicy` | `Always` | Correct default for the floating `latest` tag; switch to `IfNotPresent` only if you pin `image.tag` to an immutable digest or release tag. |

## Attendee clusters

If every attendee gets their own dedicated cluster for the training, rather than sharing the trainer's, the same chart works for their shell too: `cluster-admin` and a persistent `$HOME` are both safe defaults there, since there's no other tenant on that cluster to protect against. [`examples/attendee-cluster-values.yaml`](../examples/attendee-cluster-values.yaml) has the recommended values for that case (cluster-admin, a 2G PVC, and sane resource limits so the training survives a Pod restart) - `make attendee` applies it for you; see the main [README](../README.md) for that flow.

The broadcast sidecar stays off in the attendee case. It's for the trainer's own pod, so their class can watch, not something each attendee needs on their own shell.
