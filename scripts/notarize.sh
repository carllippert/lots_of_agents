#!/bin/sh
# Developer ID sign + notarytool + staple. Requires:
#   CODESIGN_IDENTITY   e.g. "Developer ID Application: Your Name (TEAMID)"
#   NOTARY_PROFILE      notarytool keychain profile (xcrun notarytool store-credentials)
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -z "${CODESIGN_IDENTITY:-}" ]; then
  echo "error: CODESIGN_IDENTITY is not set." >&2
  echo "This Mac currently has no Developer ID certificate." >&2
  echo "Create one in the Apple Developer portal, install it in Keychain, then:" >&2
  echo "  export CODESIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)'" >&2
  echo "  export NOTARY_PROFILE='lotsofagents'" >&2
  echo "  xcrun notarytool store-credentials \"\$NOTARY_PROFILE\" --apple-id YOU --team-id TEAMID --password app-specific-password" >&2
  echo "  ./scripts/build-app.sh && ./scripts/notarize.sh && ./scripts/make-dmg.sh" >&2
  exit 1
fi

if [ -z "${NOTARY_PROFILE:-}" ]; then
  echo "error: NOTARY_PROFILE is not set (notarytool keychain profile name)." >&2
  exit 1
fi

./scripts/build-app.sh

APP="dist/Lots of Agents.app"
ZIP="dist/Lots-of-Agents-notarize.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Submitting to notarytool…"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
spctl --assess --type execute -v "$APP"

./scripts/make-dmg.sh
DMG="dist/Lots-of-Agents-1.0.0.dmg"
xcrun stapler staple "$DMG"
echo "Stapled $DMG — this is the public download."
