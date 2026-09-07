#!/usr/bin/env bash
# Regenerate the `public` branch from the current `master`, with real names/
# identifiers redacted via redact_for_public.sh. PRIVATE-ONLY: run this from
# master; redact_for_public.sh (the sensitive one, with the real-name
# mapping) must never end up committed on the public branch -- see below
# for why this script itself is fine to leave there.
#
# Usage: run from the repo root, on master, with a clean working tree.
# The public branch is always regenerated from scratch (its history is not
# meant to be preserved across runs) -- push it with --force.
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

# redact_for_public.sh is the actually sensitive file here -- it embeds the
# real-name-to-placeholder mapping as literal substitution patterns, and
# must never reach the public branch. It has already finished running (it
# was invoked as a separate process above, which has exited), so deleting
# it here is safe.
#
# Deliberately NOT deleting this script (sync_public_branch.sh) itself: it
# has no real identifiers in it, so leaving it is not a privacy issue --
# and trying to unlink the script file while bash still has it open (we're
# mid-execution) causes an NFS "silly rename" on this filesystem (creates a
# stray tools/.nfs* file that then gets committed by mistake). Don't
# reintroduce that by trying to remove tools/ wholesale here.
git rm --cached tools/redact_for_public.sh >/dev/null
rm -f tools/redact_for_public.sh

git add -A
git commit -m "Redact real names/identifiers for public release (from master@${MASTER_SHA})"

git checkout master
echo "public branch regenerated from master@${MASTER_SHA}."
