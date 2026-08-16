#!/bin/bash
set -euo pipefail

# Build Vibe Usage.app from SPM release binary
# Usage: ./scripts/build-app.sh [--package] [--notarize]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="Vibe Usage Hardened"
BUNDLE_ID="io.github.lltzhou.vibe-usage-hardened"
EXECUTABLE="VibeUsage"
BUILD_DIR="$PROJECT_DIR/.build/release"
DIST_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/VibeUsage.zip"
DMG_PATH="$DIST_DIR/VibeUsage.dmg"
ICON_SOURCE_DIR="$PROJECT_DIR/VibeUsage/Resources/Assets.xcassets/AppIcon.appiconset"
SIGN_IDENTITY="${VIBE_USAGE_SIGN_IDENTITY:-}"
NOTARIZE_PROFILE="${VIBE_USAGE_NOTARIZE_PROFILE:-}"

NOTARIZE=false
PACKAGE=false
for arg in "$@"; do
    case "$arg" in
        --package) PACKAGE=true ;;
        --notarize) NOTARIZE=true; PACKAGE=true ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

# Fall back to ad-hoc signing when Developer ID is unavailable (e.g. local dev install).
# Notarization obviously cannot work in that mode, and hardened runtime's library
# validation rejects ad-hoc dylib loads across bundles, so the ad-hoc path also
# drops --options runtime.
#
# Identity detection captures the keychain listing into a variable first, rather than
# piping into `grep -q`: under `set -o pipefail`, grep exits on first match and
# `security` gets SIGPIPE (141), which would mark the pipeline failed and silently
# switch a valid Developer ID build to ad-hoc.
IDENTITIES=$(security find-identity -v -p codesigning 2>/dev/null || true)
if [ -n "$SIGN_IDENTITY" ] && printf '%s\n' "$IDENTITIES" | grep -Fq -- "$SIGN_IDENTITY"; then
    codesign_args=(--force --options runtime --timestamp --sign "$SIGN_IDENTITY")
else
    if $NOTARIZE; then
        echo "ERROR: --notarize requires VIBE_USAGE_SIGN_IDENTITY naming a Developer ID present in the keychain." >&2
        exit 1
    fi
    echo "==> Developer ID not found — falling back to ad-hoc signing."
    SIGN_IDENTITY="-"
    codesign_args=(--force --sign "$SIGN_IDENTITY")
fi

echo "==> Checking version sync..."
"$SCRIPT_DIR/check-version.sh"

echo "==> Building release binary..."
cd "$PROJECT_DIR"
swift build -c release

echo "==> Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/"

cp "$PROJECT_DIR/VibeUsage/Info.plist" "$APP_BUNDLE/Contents/"

RESOURCE_BUNDLE="$BUILD_DIR/VibeUsage_VibeUsage.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
    echo "    Copied SPM resource bundle"
else
    echo "    WARNING: SPM resource bundle not found at $RESOURCE_BUNDLE"
fi

echo "==> Generating AppIcon.icns..."
ICONSET_DIR=$(mktemp -d)/AppIcon.iconset
mkdir -p "$ICONSET_DIR"

cp "$ICON_SOURCE_DIR/icon_16x16.png"      "$ICONSET_DIR/icon_16x16.png"
cp "$ICON_SOURCE_DIR/icon_16x16@2x.png"   "$ICONSET_DIR/icon_16x16@2x.png"
cp "$ICON_SOURCE_DIR/icon_32x32.png"       "$ICONSET_DIR/icon_32x32.png"
cp "$ICON_SOURCE_DIR/icon_32x32@2x.png"    "$ICONSET_DIR/icon_32x32@2x.png"
cp "$ICON_SOURCE_DIR/icon_128x128.png"     "$ICONSET_DIR/icon_128x128.png"
cp "$ICON_SOURCE_DIR/icon_128x128@2x.png"  "$ICONSET_DIR/icon_128x128@2x.png"
cp "$ICON_SOURCE_DIR/icon_256x256.png"     "$ICONSET_DIR/icon_256x256.png"
cp "$ICON_SOURCE_DIR/icon_256x256@2x.png"  "$ICONSET_DIR/icon_256x256@2x.png"
cp "$ICON_SOURCE_DIR/icon_512x512.png"     "$ICONSET_DIR/icon_512x512.png"
cp "$ICON_SOURCE_DIR/icon_512x512@2x.png"  "$ICONSET_DIR/icon_512x512@2x.png"

iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
rm -rf "$(dirname "$ICONSET_DIR")"
echo "    Generated AppIcon.icns"

echo "==> Codesigning ($SIGN_IDENTITY)..."
codesign "${codesign_args[@]}" "$APP_BUNDLE"
echo "    Signed with: $SIGN_IDENTITY"

codesign --verify --deep --strict "$APP_BUNDLE"

if $PACKAGE; then
    echo "==> Creating distribution ZIP..."
    rm -f "$ZIP_PATH"
    ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

    echo "==> Creating distribution DMG..."
    rm -f "$DMG_PATH"
    DMG_STAGING=$(mktemp -d)
    cp -R "$APP_BUNDLE" "$DMG_STAGING/"
    ln -s /Applications "$DMG_STAGING/Applications"
    hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_PATH"
    rm -rf "$DMG_STAGING"
fi

if $NOTARIZE; then
    if [ -z "$NOTARIZE_PROFILE" ]; then
        echo "ERROR: --notarize requires VIBE_USAGE_NOTARIZE_PROFILE." >&2
        exit 1
    fi
    # Zip for notarization submission
    echo "==> Zipping for notarization..."
    rm -f "$ZIP_PATH"
    ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

    echo "==> Submitting for notarization (this may take a few minutes)..."
    xcrun notarytool submit "$ZIP_PATH" \
        --keychain-profile "$NOTARIZE_PROFILE" \
        --wait

    echo "==> Stapling notarization ticket..."
    xcrun stapler staple "$APP_BUNDLE"

    # Recreate distribution ZIP with the stapled app.
    echo "==> Recreating distribution ZIP..."
    rm -f "$ZIP_PATH"
    ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

    echo "==> Recreating distribution DMG..."
    rm -f "$DMG_PATH"
    DMG_STAGING=$(mktemp -d)
    cp -R "$APP_BUNDLE" "$DMG_STAGING/"
    ln -s /Applications "$DMG_STAGING/Applications"

    hdiutil create -volname "$APP_NAME" \
        -srcfolder "$DMG_STAGING" \
        -ov -format UDZO \
        "$DMG_PATH"
    rm -rf "$DMG_STAGING"

    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"

    echo "==> Notarizing DMG..."
    xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$NOTARIZE_PROFILE" \
        --wait
    xcrun stapler staple "$DMG_PATH"

    echo ""
    echo "==> Done! Signed + notarized:"
    echo "    $APP_BUNDLE"
    echo "    $DMG_PATH (initial download)"
    echo "    $ZIP_PATH"
else
    echo ""
    echo "==> Done! Signed app bundle at:"
    echo "    $APP_BUNDLE"
    echo ""
    if $PACKAGE; then
        echo "    $DMG_PATH (initial download)"
        echo "    $ZIP_PATH"
    else
        echo "    To package:  $0 --package"
    fi
    echo "    To notarize: VIBE_USAGE_SIGN_IDENTITY='Developer ID Application: ...' VIBE_USAGE_NOTARIZE_PROFILE='...' $0 --notarize"
    echo "    To install:  cp -R \"$APP_BUNDLE\" /Applications/"
    echo "    To run:      open \"$APP_BUNDLE\""
fi
