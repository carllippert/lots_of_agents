#!/bin/sh
# Universal (arm64 + x86_64) Lots of Agents.app
# Default: ad-hoc signed. Set CODESIGN_IDENTITY to a Developer ID for notarization.
set -euo pipefail
cd "$(dirname "$0")/.."

PRODUCT_NAME="Lots of Agents"
BUNDLE_ID="app.lotsofagents.macos"
APP="dist/${PRODUCT_NAME}.app"
IDENTITY="${CODESIGN_IDENTITY:--}"

echo "Building arm64 and x86_64 release binaries…"
# Combined --arch arm64 --arch x86_64 needs full Xcode xcbuild. CLT can
# cross-compile one arch at a time; we lipo afterward.
swift build -c release --arch arm64
swift build -c release --arch x86_64

BIN_ARM="$(swift build -c release --arch arm64 --show-bin-path)"
BIN_X86="$(swift build -c release --arch x86_64 --show-bin-path)"

lipo_or_copy() {
  local name="$1"
  local dest="$2"
  if [ -f "${BIN_ARM}/${name}" ] && [ -f "${BIN_X86}/${name}" ]; then
    lipo -create "${BIN_ARM}/${name}" "${BIN_X86}/${name}" -output "${dest}"
  elif [ -f "${BIN_ARM}/${name}" ]; then
    echo "warning: x86_64 ${name} missing; arm64-only" >&2
    cp "${BIN_ARM}/${name}" "${dest}"
  else
    echo "error: ${name} not built" >&2
    exit 1
  fi
}

rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

lipo_or_copy TwoCursors "$APP/Contents/MacOS/TwoCursors"
lipo_or_copy TwoCursorsLauncher "$APP/Contents/MacOS/TwoCursorsLauncher"
chmod +x "$APP/Contents/MacOS/TwoCursors" "$APP/Contents/MacOS/TwoCursorsLauncher"

if [ -f docs/assets/two-grok-clones.svg ]; then
  cp docs/assets/two-grok-clones.svg "$APP/Contents/Resources/" || true
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>TwoCursors</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${PRODUCT_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>${PRODUCT_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.developer-tools</string>
  <key>LSArchitecturePriority</key>
  <array>
    <string>arm64</string>
    <string>x86_64</string>
  </array>
</dict>
</plist>
PLIST

# Entitlements: none beyond the defaults. Hardened runtime is required for notarization.
ENTITLEMENTS="$(mktemp)"
cat > "$ENTITLEMENTS" <<'ENT'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.cs.allow-jit</key>
  <false/>
</dict>
</plist>
ENT

if [ "$IDENTITY" = "-" ]; then
  codesign --force --sign - --deep "$APP" >/dev/null 2>&1 || true
  echo "Ad-hoc signed $APP (Gatekeeper will reject this for strangers)."
else
  codesign --force --options runtime --timestamp --sign "$IDENTITY" --entitlements "$ENTITLEMENTS" \
    "$APP/Contents/MacOS/TwoCursorsLauncher"
  codesign --force --options runtime --timestamp --sign "$IDENTITY" --entitlements "$ENTITLEMENTS" \
    "$APP/Contents/MacOS/TwoCursors"
  codesign --force --options runtime --timestamp --sign "$IDENTITY" --entitlements "$ENTITLEMENTS" \
    "$APP"
  echo "Developer ID signed $APP with $IDENTITY"
fi
rm -f "$ENTITLEMENTS"

echo "Architectures:"
lipo -info "$APP/Contents/MacOS/TwoCursors" || true
echo "Run: open \"$APP\""
