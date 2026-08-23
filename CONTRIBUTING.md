# Contributing

Thanks for considering a contribution to podium.

## Before you start

Open an issue for anything beyond a small fix, so we can agree on the approach before you put time into it.

## Commits and pull requests

- Commit messages must follow [Conventional Commits](https://www.conventionalcommits.org/). This is enforced by CI (`commit-lint`).
- Pull request titles must also follow Conventional Commits. CI (`pr-lint`) checks this too, since a squash merge takes its message from the PR title.
- Keep commits small and focused; a pull request with five commits that each do one thing is easier to review than one commit that does five things.

Run `make initialise` once after cloning to install the pre-commit hooks (including a local conventional-commit check, so you find out before you push).

## Testing changes locally

```bash
helm lint helm/podium
helm template podium helm/podium
```

To test the image itself, build it and deploy it to a local cluster (kind, k3d, or similar):

```bash
docker build -t podium:dev .
k3d image import podium:dev -c <your-cluster>
helm upgrade --install podium helm/podium --set image.repository=podium --set image.tag=dev
```

## Reporting issues

Open an issue on GitHub with what you expected, what happened instead, and how to reproduce it.
