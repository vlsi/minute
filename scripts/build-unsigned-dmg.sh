#!/usr/bin/env bash
set -euo pipefail

# Package Minute.app into a plain, distributable DMG.
#
# This is the headless-safe counterpart to scripts/build-release-dmg.sh: it skips
# the Finder/AppleScript window styling (background image, icon layout), which
# needs an interactive GUI session and is unreliable on CI runners. The result is
# a compressed read-only DMG with the app and an /Applications symlink, so the
# user can drag Minute.app across.
#
# The app is expected to be ad-hoc signed but not notarised, so macOS quarantines
# it on download. The release notes tell users how to clear the quarantine.
#
# Usage:
#   scripts/build-unsigned-dmg.sh <app-or-xcarchive-path> [output-dir]
#
# The app is resolved from:
#   <path>/Products/Applications/Minute.app   (when given an .xcarchive)
#   <path>                                     (when given a .app directly)

ARCHIVE_PATH="${1:-}"
OUTPUT_DIR="${2:-dist}"

if [ -z "$ARCHIVE_PATH" ]; then
  echo "usage: scripts/build-unsigned-dmg.sh <app-or-xcarchive-path> [output-dir]" >&2
  exit 1
fi

if [ -d "$ARCHIVE_PATH" ] && [[ "$ARCHIVE_PATH" == *.xcarchive ]]; then
  APP_PATH="$ARCHIVE_PATH/Products/Applications/Minute.app"
else
  APP_PATH="$ARCHIVE_PATH"
fi

if [ ! -d "$APP_PATH" ]; then
  echo "error: app not found at: $APP_PATH" >&2
  exit 1
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || true)"
if [ -z "$VERSION" ]; then
  VERSION="0.0.0"
fi
FILE_VERSION="${VERSION// /-}"
VOL_NAME="Minute $VERSION"
DMG_FINAL="$OUTPUT_DIR/Minute-$FILE_VERSION.dmg"

STAGING="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/minute-dmg.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT

mkdir -p "$OUTPUT_DIR"
rm -f "$DMG_FINAL"

cp -R "$APP_PATH" "$STAGING/Minute.app"
ln -s /Applications "$STAGING/Applications"

# UDZO is the standard compressed, read-only DMG format.
hdiutil create \
  -volname "$VOL_NAME" \
  -srcfolder "$STAGING" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  "$DMG_FINAL" >/dev/null

echo "$DMG_FINAL"
