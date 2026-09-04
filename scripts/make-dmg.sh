#!/usr/bin/env bash
#
# Builds a Release .app and wraps it in a distributable .dmg.
# No external tooling — hdiutil ships with macOS.
#
#   ./scripts/make-dmg.sh            # -> dist/ClaudeCodeUsageWidget-<version>.dmg
#
set -euo pipefail

APP_NAME="ClaudeCodeUsageWidget"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
DIST_DIR="$PROJECT_ROOT/dist"
STAGING_DIR="$BUILD_DIR/dmg-staging"

cd "$PROJECT_ROOT"

echo "==> Building Release"
xcodebuild \
    -project "$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    build -quiet

APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"
[ -d "$APP_PATH" ] || { echo "error: $APP_PATH not found"; exit 1; }

# Re-sign with a real identity when one is available.
#
# This is not about distribution — an ad-hoc signature's designated requirement
# is the binary's cdhash, so every rebuild looks like a brand-new application to
# the Keychain and macOS re-prompts for access to the Claude Code credentials.
# Signing with a certificate makes the requirement identity+certificate based,
# which is stable across rebuilds, so "Always Allow" sticks.
#
# Set SIGN_IDENTITY to pick a specific certificate; otherwise the first one
# `security` lists is used, which on a machine with several may not be the one
# you want — the identity actually used is printed below.
if [ -z "${SIGN_IDENTITY:-}" ]; then
    # A machine with no certificates makes `security` print "0 valid identities
    # found" and `grep` exit 1. Under `set -e` an assignment whose value comes
    # from a command substitution inherits that status, which used to kill the
    # script here — silently, and only after the whole Release build. Falling
    # back to the empty string keeps the ad-hoc branch reachable.
    SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
        | grep -m1 -oE '"[^"]+"' | tr -d '"')" || SIGN_IDENTITY=""
fi
if [ -n "$SIGN_IDENTITY" ]; then
    echo "==> Signing as $SIGN_IDENTITY"
    codesign --force --options runtime --sign "$SIGN_IDENTITY" "$APP_PATH"
else
    echo "==> No codesigning identity found; leaving the ad-hoc signature."
    echo "    macOS will re-prompt for Keychain access after every rebuild."
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"

echo "==> Staging $APP_NAME $VERSION"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR" "$DIST_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
# Drag-to-install target.
ln -s /Applications "$STAGING_DIR/Applications"

echo "==> Creating $DMG_PATH"
rm -f "$DMG_PATH"
hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDZO \
    "$DMG_PATH" >/dev/null

rm -rf "$STAGING_DIR"

echo "==> Verifying"
# `hdiutil verify ... && echo` would swallow the failure: under `set -e` the
# left-hand side of `&&` is allowed to fail, so a corrupt image used to be
# reported as a successful build.
if ! hdiutil verify "$DMG_PATH" >/dev/null; then
    echo "error: $DMG_PATH failed verification; left in place for inspection" >&2
    exit 1
fi
echo "    checksum OK"

echo
echo "Built: $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1))"
echo
if [ -z "$SIGN_IDENTITY" ]; then
    echo "NOTE: this build is ad-hoc signed (no codesigning identity was found),"
    echo "so Gatekeeper will block it on any Mac other than the one that built it."
elif [ "${SIGN_IDENTITY#Developer ID Application}" != "$SIGN_IDENTITY" ]; then
    echo "NOTE: signed with \"$SIGN_IDENTITY\" but not notarized, so Gatekeeper"
    echo "will still block it on other Macs until you staple a ticket."
else
    echo "NOTE: signed with \"$SIGN_IDENTITY\" — a local development certificate,"
    echo "not a Developer ID, so Gatekeeper will block it on other Macs."
fi
echo "Recipients must right-click the app and choose Open, or run:"
echo "    xattr -dr com.apple.quarantine /Applications/$APP_NAME.app"
echo "For real distribution, set DEVELOPMENT_TEAM, sign with a Developer ID,"
echo "and notarize with notarytool."
