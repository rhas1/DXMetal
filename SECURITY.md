# Security

## Reporting a vulnerability

Please report security problems privately: on this repository's **Security** tab, choose **Report a vulnerability**. Don't open a public issue for them.

This covers the scripts, the Vapor app and the release downloads in this repository. Report problems in Wine, Sikarugir, D3DMetal, DXMT, Steam or a game to those projects.

## How Vapor protects you

- **Downloads are checked.** Everything is downloaded over HTTPS. The wrapper and Wine are checked against SHA-256 checksums pinned in `scripts/config.sh`, and app updates against the `SHA256SUMS` published with each release.
- **Your sign-ins stay private.** Setup makes Vapor Steam, which holds your Steam and game sign-ins, readable only by your Mac account.
- **Vapor collects nothing.** It contains no accounts, keys or tracking. It only contacts GitHub, to check for and download its own updates.
- **Releases are built by GitHub** from the tagged source code, with the hardened runtime.

## Limits

- **Wine isn't a sandbox.** Windows programs run with the same access to your files as any app you run. Only install games and mods from sources you trust.
- **Vapor isn't notarized by Apple,** so macOS asks you to approve it once. Check a download against the SHA-256 in its release notes before approving it.
