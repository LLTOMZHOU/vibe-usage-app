# Security policy

## Supported version

Only the latest release from this fork is supported. The upstream Vibe Usage
release and npm package have separate trust and update boundaries.

## Report a vulnerability

Open a private GitHub security advisory for `LLTOMZHOU/vibe-usage-app`. Do not
include API keys, OAuth tokens, local log contents, or other secrets in a public
issue.

## Security invariants

- The app executes only the collector source committed in this repository.
- It never runs an npm package name, version tag, or package-manager install at
  runtime.
- VibeCafe API keys live in macOS Keychain, not JSON.
- Release builds send that key only to `https://vibecafe.ai`.
- The collector child receives a narrow environment allowlist; ambient API
  keys, cloud credentials, and runtime injection variables are not inherited.
- Project names, session metadata, remote sync, public leaderboard visibility,
  and credential-backed quota probes default to off.
- Before uploading, the collector applies the app's explicit leaderboard
  choice to VibeCafe and reads it back. An unavailable or unconfirmed setting
  cancels the sync without uploading data.
- The device name sent to the service is a random local alias.
- Cursor credential access and Antigravity process/RPC inspection are excluded.
- Remote updates are human-reviewed downloads; the app cannot silently replace
  itself from the upstream release feed.
- The app never writes Claude configuration files.

`scripts/verify-hardening.sh` and CI enforce the mechanically checkable subset.
