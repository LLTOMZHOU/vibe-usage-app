# Hardened fork design

This fork starts from upstream app commit
`9c762033be1a1109019840495432930d873669ec` and vendors collector commit
`6c72607286b125488003c741c280d4cce6263d1f` (`0.10.11`).

## Threats addressed

| Concern | Control in this fork |
| --- | --- |
| Mutable npm `latest` executes every 30 minutes | Collector source is copied into the app resource bundle and invoked directly with Node/Bun. |
| Cursor token and network access | Cursor parser is removed. |
| Antigravity process token / local RPC | Antigravity parser is removed. |
| Plaintext VibeCafe key | Native app stores it in macOS Keychain and passes it only to the bundled child process. |
| Child inherits shell/cloud secrets | Collector environment is allowlisted and excludes ambient credentials plus `NODE_OPTIONS`. |
| Config/state permissions | Dedicated Application Support directory plus owner-only umask, directory mode `0700`, and file mode `0600`. |
| Hostname disclosure | Stable random `Mac-XXXXXXXX` alias. |
| Project and session disclosure | Both uploads default off and have separate settings toggles. |
| Upload before privacy review | Remote sync itself defaults off; the UI directs the user to review VibeCafe's server-side public leaderboard first. |
| Silent Codex/Claude credential use | Both quota probes default off and disclose their access before opt-in. |
| Codex token redirected by local proxy config | Quota fetch ignores custom `chatgpt_base_url` and uses only the official ChatGPT HTTPS origin. |
| Upstream update replacing hardening | Sparkle and the upstream appcast are removed. Update checks open this fork's release page. |
| Untraceable builds | Public CI runs tests, creates an ad-hoc-signed package, emits SHA-256 checksums, and creates GitHub artifact attestations from each main-branch commit. |

## Residual trust

Token totals still come from local AI-tool logs and, after explicit consent,
are uploaded to VibeCafe. The service controls storage, account settings, public
leaderboard behavior, and server-side cost calculation. This fork cannot prove
or change those server-side properties. Review and disable public listing on the
VibeCafe website before enabling sync.

The app is not sandboxed because it must read logs belonging to several tools.
Bundling and parser removal reduce the code-execution and credential blast
radius but do not make arbitrary local-file access impossible. Build from source
if that remaining trust is unacceptable.

This fork never edits Claude's `settings.json`, including the upstream legacy
status-line cleanup path. If an older upstream release installed that hook,
remove it with that upstream release before switching apps.

## Release classes

- CI/personal package: ad-hoc signed, reproducibly built from public source, but
  macOS Gatekeeper will warn after download.
- Public consumer package: requires the fork owner to configure an Apple
  Developer ID and notarization profile through local environment variables.
  Those credentials must never be committed or copied from upstream.
