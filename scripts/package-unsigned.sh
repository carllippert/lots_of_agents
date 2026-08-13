#!/bin/sh
# Developer-only zip. Not for Reddit. Gatekeeper will reject this unless the
# recipient removes quarantine: xattr -dr com.apple.quarantine "Lots of Agents.app"
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build-app.sh

ZIP="dist/Lots-of-Agents-unsigned.zip"
rm -f "$ZIP"

cat > dist/README-DEVELOPERS.txt <<'TXT'
Lots of Agents — developer build (NOT notarized)

Gatekeeper will block this app. That is expected.

  xattr -dr com.apple.quarantine "Lots of Agents.app"
  open "Lots of Agents.app"

Do not post this zip as the public download. Strangers need the stapled DMG
from GitHub Releases after ./scripts/notarize.sh.

This archive does not contain Grok Bot.app or Cursor.app. Install those
from Anysphere first.
TXT

ditto -c -k --keepParent "dist/Lots of Agents.app" "$ZIP"
# Also tuck the readme next to the zip, not inside the .app.
echo "Wrote $ZIP"
echo "This is developers-only. Do not Reddit this file."
