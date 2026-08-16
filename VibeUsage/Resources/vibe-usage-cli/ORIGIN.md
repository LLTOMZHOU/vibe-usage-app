# Vendored collector provenance

- Upstream repository: https://github.com/vibe-cafe/vibe-usage
- Audited commit: `6c72607286b125488003c741c280d4cce6263d1f`
- Upstream package/version: `@vibe-cafe/vibe-usage@0.10.11`
- Vendored on: 2026-08-16

This source snapshot is bundled so the app never downloads or executes the
mutable npm `latest` tag at runtime. The fork removes the Cursor parser (which
reads a local Cursor auth token and contacts Cursor's service) and the
Antigravity parser (which may inspect a running process and call a local RPC).
It also enforces privacy choices supplied by the native app and an owner-only
process umask. Before any upload, the fork applies the app's explicit public
leaderboard choice through the settings API and reads it back; failure to
confirm cancels the sync. The fork also adds a `snapshot` command for the
account-free dashboard. It reads parser output locally, preserves project and
session details on-device, imports no upload client, and receives no API key.
The entrypoint accepts only `sync` and `snapshot`; upstream setup, daemon,
reset, summary, status, and skill-management commands are not bundled. Future
updates must be reviewed and committed as source changes.
