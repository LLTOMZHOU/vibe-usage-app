# Vibe Usage Hardened

A privacy- and supply-chain-hardened public fork of
[`vibe-cafe/vibe-usage-app`](https://github.com/vibe-cafe/vibe-usage-app), a
macOS menu-bar dashboard for AI coding-tool token usage and cost.

**Private by default, useful without an account.** The dashboard reads supported
AI-tool logs on your Mac and refreshes locally every 30 minutes. VibeCafe login
and upload are separate, optional features hidden behind Settings. Security is
the starting point for an independent product, not the end state; see
[the product thesis](THESIS.md).

## What changed

- Bundles reviewed collector source instead of executing an npm `latest` tag.
- Shows the full local dashboard on first launch with no sign-in or network
  connection, including source, model, project, token, cache, and activity data.
- Runs local refresh through a network-free command that never receives the
  VibeCafe API key; the refresh button cannot trigger an upload.
- Stores the VibeCafe API key in macOS Keychain.
- Uses a random device alias instead of your Mac hostname.
- Defaults remote sync, project names, session statistics, and Codex/Claude
  credential-backed quota probes to off.
- Defaults public leaderboard visibility off and verifies the server accepted
  that choice before every upload.
- Removes the Cursor credential/network parser and Antigravity process/RPC
  parser.
- Restricts release credentials to `https://vibecafe.ai`.
- Removes silent in-app updates; update checks open this fork's release page.
- Provides public CI packaging, hashes, a security policy, and an upstream
  review policy.

See [the hardening design](docs/HARDENING.md) for the threat model and residual
trust. These changes improve the client; they do not audit VibeCafe's private
server implementation.

## Download and install

Download the latest `VibeUsage.dmg` and `SHA256SUMS` from
[this fork's Releases](https://github.com/LLTOMZHOU/vibe-usage-app/releases).
Verify the hash before opening it:

```bash
shasum -a 256 ~/Downloads/VibeUsage.dmg
```

The initial personal release is ad-hoc signed because upstream's Apple signing
credentials do not—and must not—transfer to a fork. macOS will therefore show a
Gatekeeper warning. After verifying the published SHA-256 against the release,
open System Settings → Privacy & Security and choose **Open Anyway**. A
warning-free public build requires the fork owner to add their own Apple
Developer ID and notarization profile.

## First run

Open the app. That is enough: no account setup is required. The dashboard reads
local logs and keeps project names and session activity on your Mac. Node.js 20+
or Bun is required to run the bundled, dependency-free parser.

Local logs generally contain token counts but not authoritative provider
pricing, so this release shows cost as unavailable rather than inventing a
misleading `$0`. Token, cache, project, model, tool, and activity views remain
fully local.

If you later want VibeCafe sync, open Settings → Optional Cloud Sync, connect an
account, review each privacy switch, and then explicitly enable
**允许同步到 VibeCafe**. With project names, session statistics, and leaderboard
visibility left off, uploads contain tool/model identifiers, 30-minute token
buckets, and a random device alias. Raw prompts and responses are not uploaded.

## Build from source

Requirements: macOS 14+, Xcode/Swift 6, and Node.js 20+ or Bun.

```bash
git clone https://github.com/LLTOMZHOU/vibe-usage-app.git
cd vibe-usage-app
./scripts/verify-hardening.sh
node --test collector-tests/*.test.mjs
swift test
./scripts/build-app.sh --package
open "dist/Vibe Usage Hardened.app"
```

`dist/VibeUsage.dmg` and `dist/VibeUsage.zip` are ad-hoc-signed personal
artifacts. For Developer-ID signing and notarization, set
`VIBE_USAGE_SIGN_IDENTITY` and `VIBE_USAGE_NOTARIZE_PROFILE`; see
[the hardening design](docs/HARDENING.md).

## Upstream updates

The original project remains configured as a fetch-only `upstream` remote.
Scheduled updates are review proposals, never automatic merges or releases.
See [the upstream policy](docs/UPSTREAM_POLICY.md).

## License

MIT. See [LICENSE](LICENSE).
