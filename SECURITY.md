# Security Policy

## Supported versions

podium ships one rolling `latest` release; there's no long-term-support branch to track. Security fixes land on `main` and are published as the next image tag and chart version.

## Reporting a vulnerability

Please report security issues privately rather than opening a public GitHub issue: use [GitHub's private vulnerability reporting](https://github.com/platformfix/podium/security/advisories/new) for this repository (Security tab → Report a vulnerability).

Include what you'd include in any good bug report: the affected version or commit, what you found, and how to reproduce it. We'll acknowledge new reports within 5 business days and aim to have a fix or mitigation plan within 30 days, depending on severity.

## Scope

podium runs with `cluster-admin` by design when configured that way (it's meant to be a trainer's or attendee's own dedicated shell, not a shared multi-tenant service). Reports about that intended behavior aren't security issues on their own; reports about the image, the chart's defaults, the broadcast mechanism, or the CI/release pipeline are in scope.
