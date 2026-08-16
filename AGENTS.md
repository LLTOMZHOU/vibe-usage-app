# AGENTS.md — hardened fork

This repository is the public hardened fork of `vibe-cafe/vibe-usage-app`.
Security and privacy invariants outrank mechanical upstream compatibility.

## Required reading

Before changing process execution, networking, persistence, parsers, privacy
defaults, updates, or packaging, read:

- `SECURITY.md`
- `docs/HARDENING.md`
- `docs/UPSTREAM_POLICY.md`
- `VibeUsage/Resources/vibe-usage-cli/ORIGIN.md`

## Non-negotiable invariants

- Never execute npm/bun package names or mutable tags at runtime.
- The native app may execute only the collector committed under
  `VibeUsage/Resources/vibe-usage-cli`.
- Do not restore Cursor credential access or Antigravity process/RPC access.
- Never persist `VIBE_USAGE_API_KEY` or the VibeCafe key in JSON, logs, tests,
  workflow output, or release notes.
- Release credentials may go only to the validated `https://vibecafe.ai`
  origin (localhost is debug-only).
- Remote sync, project names, session metadata, and both credential-backed quota
  probes remain opt-in.
- Do not restore a silent or automatic app-update path.
- Do not merge, tag, publish, or release an automated upstream update.

## Architecture

- Swift 6 / SwiftUI macOS 14+ menu-bar app.
- `ConfigManager` stores the API key in macOS Keychain and only non-secret
  metadata under Application Support with owner-only permissions.
- `RuntimeDetector` finds Node or Bun and passes the copied collector entrypoint
  as a local file path.
- `SyncEngine` injects the Keychain secret and privacy policy into that one child
  process.
- The collector is dependency-free ESM. Its import graph for `sync` is the
  runtime attack surface; review it as carefully as Swift code.
- Remote update checks are a browser link to this fork's Releases page.

## Verification

```bash
./scripts/verify-hardening.sh
node --test collector-tests/*.test.mjs
swift test
./scripts/build-app.sh --package
codesign --verify --deep --strict "dist/Vibe Usage Hardened.app"
shasum -a 256 dist/VibeUsage.dmg dist/VibeUsage.zip
```

If SwiftPM cannot write host caches in a restricted environment, redirect only
its module caches to a task-specific directory under `/tmp`; do not change
`HOME`.

## Upstream review

Fetch `upstream/main`, inspect the full diff, and port changes onto a dedicated
`agent/...` branch. Never merge upstream wholesale if that would remove fork
controls. Any collector update must use an explicit 40-character commit, rerun
its upstream tests before copying, update `ORIGIN.md`, and remain a reviewable
commit.

## Packaging

- `./scripts/build-app.sh --package` creates ad-hoc-signed personal artifacts.
- `--notarize` requires the fork owner's `VIBE_USAGE_SIGN_IDENTITY` and
  `VIBE_USAGE_NOTARIZE_PROFILE` environment variables.
- Upstream Apple/Sparkle credentials are not available and must not be copied.
- Verify all release assets and hashes after upload.
