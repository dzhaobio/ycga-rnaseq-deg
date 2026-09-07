#!/usr/bin/env bash
# Regenerate a copy of master's full history, re-authored to the dzhaobio
# GitHub account's identity, and force-push it as dzhaobio's master.
#
# Why this exists: GitHub attributes commit "Contributors" by matching the
# commit author's email to a GitHub account's verified email -- not by
# which remote/account you happen to push from. zhaodj81@hotmail.com
# (master/tianping's commit identity) is verified on the tianping account,
# so pushing those exact commits to dzhaobio still showed "tianping" as the
# contributor there. Since dejian.zhao@yale.edu is verified on the
# dzhaobio account, re-authoring a copy of the same history to that email
# makes dzhaobio's own repo attribute correctly to "Dejian Zhao" (dzhaobio's
# display name) instead.
#
# This preserves full commit history (unlike the old redacted public
# branch, which had to be squashed to an orphan commit) since there's no
# content transformation happening here -- just different author/committer
# metadata on otherwise-identical commits.
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

git branch -D dzhaobio-mirror >/dev/null 2>&1 || true
git checkout -b dzhaobio-mirror master

FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch --force --env-filter '
export GIT_AUTHOR_NAME="Dejian Zhao"
export GIT_AUTHOR_EMAIL="dejian.zhao@yale.edu"
export GIT_COMMITTER_NAME="Dejian Zhao"
export GIT_COMMITTER_EMAIL="dejian.zhao@yale.edu"
' -- dzhaobio-mirror

git checkout master
git push --force dzhaobio dzhaobio-mirror:master
git branch -D dzhaobio-mirror

echo "dzhaobio master updated from master@$(git rev-parse --short master), re-authored."
