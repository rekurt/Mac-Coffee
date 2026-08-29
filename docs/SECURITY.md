# Security Policy

## Supported versions

Security fixes target the latest published Mac Coffee 2.x release and the current `main` branch. The original 1.x privileged-helper design is not supported by this fork; use the [legacy cleanup guide](LEGACY_CLEANUP.md) if it was previously installed.

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability. Use GitHub's **Report a vulnerability** form in the repository Security tab:

<https://github.com/rekurt/Mac-Coffee/security/advisories/new>

Include affected versions, macOS version and architecture, Direct or App Store edition, reproduction steps, impact, and a minimal proof of concept. Remove credentials and unrelated personal information from logs. You may suggest a mitigation, but please allow coordinated disclosure before publishing details.

If private vulnerability reporting is unavailable, contact the maintainer through the private contact options on the [rekurt GitHub profile](https://github.com/rekurt).

## Security model

Mac Coffee uses public, process-owned IOKit assertions; no privileged helper, daemon, persistent `pmset` mutation, activity simulation, analytics, or backend is present. The Direct edition can contact its signed Sparkle update feed. The sandboxed App Store edition contains no alternate updater.
