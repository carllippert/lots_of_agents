# Notarize Lots of Agents

Public downloads must be a **Developer ID signed, notarized, stapled universal DMG**. Ad-hoc `codesign --sign -` is rejected by Gatekeeper.

This machine had **0 valid signing identities** when the scripts were added. Until a Developer ID Application certificate is installed, `./scripts/notarize.sh` exits with instructions instead of producing a fake “signed” build.

## One-time Apple setup

1. Enroll in the Apple Developer Program.
2. Create a **Developer ID Application** certificate and install it in Keychain.
3. Create an [app-specific password](https://appleid.apple.com).
4. Store notary credentials:

```bash
xcrun notarytool store-credentials "lotsofagents" \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"
```

## Build, notarize, staple

```bash
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="lotsofagents"
./scripts/build-app.sh
./scripts/notarize.sh
```

That signs with hardened runtime, submits via `notarytool`, staples the app, builds `dist/Lots-of-Agents-1.0.0.dmg`, and staples the DMG.

Confirm:

```bash
spctl --assess --type execute -v "dist/Lots of Agents.app"
spctl --assess --type open --context context:primary-signature -v "dist/Lots-of-Agents-1.0.0.dmg"
```

Attach the stapled DMG to GitHub Releases **v1.0.0**. That is the only artifact strangers should download.

## What not to ship

- Unsigned or ad-hoc zip as the public download
- Grok Bot.app or Cursor.app inside the DMG
- A Mac App Store build (not in scope)
