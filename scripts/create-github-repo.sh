#!/bin/sh
# Create the public GitHub repo and push main. Requires `gh auth login`.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! gh auth status >/dev/null 2>&1; then
  echo "error: GitHub CLI is not logged in." >&2
  echo "Run: gh auth login" >&2
  echo "Then: ./scripts/create-github-repo.sh" >&2
  exit 1
fi

NAME="${GITHUB_REPO_NAME:-lots_of_agents}"
VIS="${GITHUB_REPO_VISIBILITY:-public}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: not a git repo" >&2
  exit 1
fi

if [ -z "$(git rev-parse --verify HEAD 2>/dev/null || true)" ]; then
  echo "error: no commits yet. Commit first, then re-run." >&2
  exit 1
fi

if git remote get-url origin >/dev/null 2>&1; then
  echo "origin already set: $(git remote get-url origin)"
else
  gh repo create "$NAME" --"$VIS" --source . --remote origin --description "Multiple signed-in clones of Grok Bot, Cursor, Claude, and ChatGPT on one Mac."
fi

git push -u origin HEAD
echo "Repo: $(gh repo view --json url -q .url)"
