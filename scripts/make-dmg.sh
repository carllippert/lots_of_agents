#!/bin/sh
# Wrap dist/Lots of Agents.app in a compressed DMG. Run after notarize.sh so
# the app is already stapled, then optionally staple the DMG too.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="dist/Lots of Agents.app"
if [ ! -d "$APP" ]; then
  echo "error: $APP missing. Run ./scripts/build-app.sh first." >&2
  exit 1
fi

VOL="Lots of Agents"
DMG="dist/Lots-of-Agents-1.0.0.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$STAGE/$VOL"
ditto "$APP" "$STAGE/$VOL/Lots of Agents.app"
ln -s /Applications "$STAGE/$VOL/Applications"

rm -f "$DMG"
hdiutil create -volname "$VOL" -srcfolder "$STAGE/$VOL" -ov -format UDZO "$DMG"
echo "Wrote $DMG"
echo "If the app was notarized, staple the DMG with:"
echo "  xcrun stapler staple \"$DMG\""
