# Launch posts — Grok first

**Do not post until a notarized, stapled universal DMG is on GitHub Releases v1.0.**
Gatekeeper rejects ad-hoc builds. An unsigned zip is developers-only.

Not affiliated with xAI or Anysphere. Disclose that in every post. 10% promo rule still applies on Reddit — comment helpfully first.

Suggested GIF: create Work + Personal Grok → two Dock apps (`docs/assets/two-grok-clones.svg` until a screen recording exists).

## Order

1. [Cursor forum Grok Bot announcement](https://forum.cursor.com/t/introducing-grok-bot/168053) and any “second Grok Bot account” threads
2. r/grok / xAI Discord or X replies under Grok Bot launch posts
3. r/cursor — Grok Bot in the title, Cursor as also supported
4. r/MacApps — once/30 days; identity + privacy blurb

Do **not** lead the first Reddit post with Cursor.

## Shared pitch

> Grok Bot has no account switcher. I need work and personal Cursor-tier logins on one Mac. Lots of Agents launches the same Grok Bot.app with a separate data dir so both stay signed in. Updates once. Open source. Also clones Cursor. Not affiliated with xAI/Anysphere.

## 1. Cursor forum — Grok Bot thread

**Where:** https://forum.cursor.com/t/introducing-grok-bot/168053

**Title:** (reply, no new title)

Grok Bot has no account switcher, so work Ultra and personal SuperGrok Heavy cannot stay signed in on one Mac.

I built an open-source macOS app, Lots of Agents, that launches the same `/Applications/Grok Bot.app` (bundle ID `com.anysphere.sand`) with `--user-data-dir` / `--extensions-dir`. Two Dock apps, two logins, one binary — update Grok Bot once and both clones pick it up. Sign-in mode pauses the other Grok clone so `sand://` hits the one you are authorizing. Git and SSH still use your real home (not a fake empty `$HOME`).

Not affiliated with Anysphere or xAI. Cursor IDE clones are also supported.

Notarized DMG: \<GitHub Releases v1.0 URL\>
Source: \<repo URL\>

## 2. r/grok / xAI Discord / X reply

**Title (Reddit):** Grok Bot has no account switcher — I made a Mac app for two logins on one machine

Grok Bot has no account switcher. I need work and personal Cursor-tier logins on one Mac.

Lots of Agents launches the same Grok Bot.app with a separate data dir so both stay signed in. Updates once. Open source. Also clones Cursor. Not affiliated with xAI/Anysphere.

Notarized DMG + source: \<URL\>

(If this is a reply under an official Grok Bot launch post: same body, skip the title.)

## 3. r/cursor

**Title:** Two Grok Bot accounts on one Mac (also works for Cursor IDE)

Grok Bot has no account switcher. I need work and personal Cursor-tier logins on one Mac. Lots of Agents launches the same Grok Bot.app with a separate data dir so both stay signed in. Updates once. Open source. Also clones Cursor. Not affiliated with xAI/Anysphere.

If you already clone Cursor with wrappers / Parall: this is the same idea without copying the app bundle or faking `$HOME`.

Notarized DMG: \<URL\>

Comment helpfully in the Grok Bot / two-account threads first. This is the one promo post.

## 4. r/MacApps

**Title:** Lots of Agents — isolated Grok Bot (and Cursor) clones on macOS

Native Swift app. It does not ship Grok Bot or Cursor. It launches whatever you already installed, each clone with its own data directory and Dock icon.

Privacy: everything stays on your Mac (`~/Library/Application Support/LotsOfAgents/`). No analytics. Sign-in still goes to Anysphere. MIT. Not affiliated with xAI/Anysphere.

Notarized universal DMG: \<URL\>
Privacy: \<repo\>/PRIVACY.md

Once per 30 days.

## After Grok launch (not the first posts)

Cursor forum two-account / Parall threads, a README “also Cursor” section (already in the README), maybe a v1.0.1 note. Do not lead with Cursor until Grok posts are up.
