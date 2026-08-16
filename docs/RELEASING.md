# Releasing the hardened fork

## Personal / CI package

```bash
./scripts/verify-hardening.sh
node --test collector-tests/*.test.mjs
swift test
./scripts/build-app.sh --package
shasum -a 256 dist/VibeUsage.dmg dist/VibeUsage.zip > dist/SHA256SUMS
```

This output is ad-hoc signed and is appropriate for a verified personal build.
It will trigger Gatekeeper after an Internet download.

## Notarized public package

Use Apple credentials owned by this fork's publisher:

```bash
VIBE_USAGE_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
VIBE_USAGE_NOTARIZE_PROFILE='VibeUsageHardened' \
./scripts/build-app.sh --notarize
```

Never import, request, rotate, or reuse the upstream maintainer's Developer ID
or Sparkle key. This fork does not use Sparkle.

## Publish

Create a tag only after review and CI pass. Upload `VibeUsage.dmg`,
`VibeUsage.zip`, and `SHA256SUMS`, then verify the release page lists all three
and that downloaded hashes match. Automated upstream-review tasks may prepare a
draft pull request but may not perform this step.
