#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

search_lines() {
    local pattern="$1"
    shift
    if command -v rg >/dev/null 2>&1; then
        rg -n "$pattern" "$@"
    else
        grep -R -n -E "$pattern" "$@"
    fi
}

search_quiet() {
    local pattern="$1"
    shift
    if command -v rg >/dev/null 2>&1; then
        rg -q "$pattern" "$@"
    else
        grep -R -q -E "$pattern" "$@"
    fi
}

./scripts/check-version.sh
plutil -lint VibeUsage/Info.plist >/dev/null
node --check VibeUsage/Resources/vibe-usage-cli/bin/vibe-usage.js
node --check VibeUsage/Resources/vibe-usage-cli/src/api.js
node --check VibeUsage/Resources/vibe-usage-cli/src/sync.js
node --check VibeUsage/Resources/vibe-usage-cli/src/local-snapshot.js

if search_lines '@vibe-cafe/vibe-usage@latest|\["--yes"|\["x", packageSpecifier' \
    VibeUsage/Services Tests; then
    fail "runtime package-manager execution returned"
fi

[[ ! -e VibeUsage/Resources/vibe-usage-cli/src/parsers/cursor.js ]] \
    || fail "credential-reading Cursor parser returned"
[[ ! -e VibeUsage/Resources/vibe-usage-cli/src/parsers/antigravity.js ]] \
    || fail "Antigravity process/RPC parser returned"

if search_lines 'parseCursor|parseAntigravity' VibeUsage/Resources/vibe-usage-cli/src/parsers/index.js; then
    fail "a prohibited parser is registered"
fi

if search_lines "node:(http|https|net|tls|dgram)|fetch[[:space:]]*\\(|WebSocket" \
    VibeUsage/Resources/vibe-usage-cli/src/parsers; then
    fail "a local parser gained network access"
fi

if search_lines "from './(api|sync|config|state)\\.js'" \
    VibeUsage/Resources/vibe-usage-cli/src/local-snapshot.js; then
    fail "the local snapshot imports cloud or upload code"
fi

search_quiet 'localCollectorEnvironment' \
    VibeUsage/Services/LocalUsageProvider.swift \
    || fail "the local dashboard no longer uses the credential-free environment"

if search_lines 'SUFeedURL|SUPublicEDKey|SUEnableAutomaticChecks' VibeUsage/Info.plist; then
    fail "automatic remote update configuration returned"
fi

search_quiet '6c72607286b125488003c741c280d4cce6263d1f' \
    VibeUsage/Resources/vibe-usage-cli/ORIGIN.md \
    || fail "vendored collector provenance is missing"

search_quiet 'VIBE_USAGE_SHOW_IN_RANK' \
    VibeUsage/Models/AppConfig.swift \
    VibeUsage/Resources/vibe-usage-cli/src/sync.js \
    || fail "public leaderboard privacy policy is not passed to the collector"

search_quiet 'enforceShowInRank' \
    VibeUsage/Resources/vibe-usage-cli/src/sync.js \
    || fail "server leaderboard privacy is not enforced before sync"

echo "Hardening invariants verified."
