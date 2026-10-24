# Security Policy

Thanks for helping keep Vorssaint and the people who use it safe.

## Reporting a vulnerability

Please report security vulnerabilities in private. Do not open a public issue, pull request or discussion for them.

Private vulnerability reporting is not currently enabled on this fork, and no fork-specific private reporting channel is documented. The link below is the original project’s private reporting channel for vulnerabilities affecting upstream; it does not go to this fork’s maintainer.

- **[Report an upstream vulnerability privately](https://github.com/vorssaint/vorssaint-utils/security/advisories/new)**

That opens a private security advisory in the upstream repository, rather than this fork.

When you write it up, please include as much as you can.

- A description of the issue and the impact it could have.
- Steps to reproduce, or a proof of concept.
- The Vorssaint version from Settings under About and your macOS version.

## What to expect

- This is a community project looked after on a best effort basis, so please allow reasonable time for a reply and a fix.
- Please give the maintainer a chance to ship a fix before you talk about the issue in public. That is what coordinated disclosure means.
- Credit goes gladly to reporters who want it.

## Supported versions

This fork is distributed as source and has no published releases. Check the latest fork `main` when investigating a fork issue. For a report to upstream, verify it against the latest official upstream release and identify any fork-specific differences.

## Scope

Vorssaint runs locally. Official upstream releases are Developer ID signed and notarized; this fork’s local build helper uses ad-hoc signing, and upstream self-updates are disabled for the fork. The reports that matter most are the ones that could affect the integrity of the app or its self update flow, or that could let the app's permissions be misused. Issues in the outside services the app merely talks to, like GitHub's releases API or the speed test endpoint, are best taken to those providers.
