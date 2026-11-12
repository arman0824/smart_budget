# Security Policy

## Reporting a vulnerability

Smart Budget stores all data locally on the device and has no account, no
server, and no analytics. Even so, please report suspected vulnerabilities
privately.

Use GitHub's private vulnerability reporting:

1. Go to the [Security tab](https://github.com/arman0824/smart_budget/security) of this repository.
2. Click **Report a vulnerability**.

Please include a description, reproduction steps, the affected platform
(iOS / macOS) and app version (Settings → About). You should receive an
acknowledgement within a few days.

**Do not open a public issue for a security problem.**

## Supported versions

| Version | Supported |
|---------|-----------|
| Latest release (1.x) | ✅ |
| Earlier tags | ❌ |

## Scope

In scope: data loss or corruption of the local SwiftData store, unsafe file
handling (e.g. CSV export), notification leakage of financial details.

Out of scope: social engineering, attacks requiring a jailbroken/unlocked
device, and vulnerabilities in Apple's platforms or dependencies (report those
upstream).
