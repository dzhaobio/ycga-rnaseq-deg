#!/usr/bin/env bash
# Find existing YCGA user subfolders under the base work directory that might
# match a given user/PI name pair, so the agent doesn't have to eyeball
# hundreds of "First_Last.PI_First_Last" folder names by hand each run.
#
# Usage: resolve_user_subfolder.sh <base_dir> <user_name> [pi_name]
#
# Prints one candidate per line, tagged by match strength:
#   USER_MATCH:<folder>   the client's own name matched -- this is the real
#                         signal; a PI (e.g. a lab head) usually has many
#                         students, so PI name alone is not enough to pick
#                         a folder
#   PI_ONLY:<folder>      only the PI name matched (a sibling under the same
#                         PI, e.g. a labmate) -- informational only
#
# Rule of thumb: exactly one USER_MATCH line -> use it, ignore any PI_ONLY
# lines. Zero USER_MATCH lines -> no existing subfolder, "User_Name.PI_Name"
# is probably new (PI_ONLY lines just confirm the PI/lab is already known
# here). More than one USER_MATCH line, or the client's own name is itself
# ambiguous/missing -> stop and ask rather than guessing: this decides where
# real client data and results land.
set -euo pipefail
base_dir="${1:?base_dir required}"
user_name="${2:?user_name required}"
pi_name="${3:-}"

norm() { echo "$1" | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9'; }

u_key=$(norm "$user_name")
p_key=$(norm "$pi_name")

cd "$base_dir"
for d in */; do
  d="${d%/}"
  d_key=$(norm "$d")
  if [[ -n "$u_key" && "$d_key" == *"$u_key"* ]]; then
    echo "USER_MATCH:$d"
  elif [[ -n "$p_key" && "$d_key" == *"$p_key"* ]]; then
    echo "PI_ONLY:$d"
  fi
done | sort -u
