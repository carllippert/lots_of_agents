# Privacy

Lots of Agents runs entirely on your Mac. It does not phone home.

## What it stores

Clone names, icons, and isolation settings live in:

`~/Library/Application Support/LotsOfAgents/`

Each clone’s Grok Bot or Cursor user data lives under that folder. Dock wrappers live in `~/Applications`.

## What it does not do

- No analytics, crash reporters, or accounts of its own
- No upload of chats, tokens, or git credentials
- It never copies Grok Bot.app or Cursor.app into its own bundle
- Git, SSH, and your real home stay yours unless you opt into the full-home overlay (which still symlinks your real home — it does not invent an empty one)

## Sign-in

Grok Bot and Cursor sign-in still goes to Anysphere / xAI. Lots of Agents only pauses sibling clones so `sand://` or `cursor://` hits the clone you are authorizing.

Not affiliated with xAI or Anysphere.
