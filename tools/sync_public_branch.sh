#!/usr/bin/env bash
# Regenerate the `public` branch from the current `master`, with real names/
# identifiers redacted via redact_for_public.sh. PRIVATE-ONLY: run this from
# master; it must never itself end up committed on the public branch.
#
# Usage: run from the repo root, on master, with a clean working tree.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

if [[ "$(git branch --show-current)" != "master" ]]; then
  echo "Must be run from master." >&2
  exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree not clean -- commit or stash first." >&2
  exit 1
fi

MASTER_SHA=$(git rev-parse --short master)

git checkout -B public master

# Redact every tracked file except tools/ itself (while it's still present
# on disk from the master checkout).
mapfile -t FILES < <(git ls-files | grep -v '^tools/')
./tools/redact_for_public.sh "${FILES[@]}"

# tools/ is private-only: it contains this script and the redaction map
# itself (real identifiers as literal substitution patterns) -- never let it
# reach the public branch.
git rm -r --cached tools >/dev/null
# This filesystem sometimes reports a just-emptied directory as "not empty"
# for a moment (a stale directory-entry cache) -- retry rmdir rather than
# treat it as fatal; an untracked empty tools/ left behind is harmless
# either way since git never tracks empty directories.
for i in 1 2 3 4 5; do
  rm -rf tools 2>/dev/null && break
  sleep 0.5
done
rmdir tools 2>/dev/null || true

git add -A
git commit -m "Redact real names/identifiers for public release (from master@${MASTER_SHA})"

git checkout master
echo "public branch regenerated from master@${MASTER_SHA}."
