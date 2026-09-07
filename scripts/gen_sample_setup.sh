#!/usr/bin/env bash
# Build sample_setup.txt (tab-delimited: sample<TAB>label) for the
# rnaseq-HISAT2-RF_McCleary.rms pipeline's --sampleFile argument.
#
# Usage: gen_sample_setup.sh <project_dir> [label_map_tsv]
#   project_dir    directory containing one subfolder per sample (each with
#                  an Unaligned/ subdir, created by ycgaFastq)
#   label_map_tsv  optional TSV (sample<TAB>label) to override the default
#                  label (label == sample name), one line per sample
#
# Every sample folder gets a row with an identical sample/label pair.
# Do NOT add a row for ruddle_paths.txt itself -- an earlier version of this
# script did (copying a typo from the original by-hand walkthrough), and the
# alignment pipeline errors trying to treat that file as a sample directory
# (confirmed 2026-09-07 on the Jillian Petrocelli/xpo7 project: "touch:
# cannot touch 'ruddle_paths.txt/.QP2FQ.done': Not a directory"). It's a
# single isolated failed command, not fatal to the real samples, but avoid it.
set -euo pipefail
proj_dir="${1:?project_dir required}"
label_map="${2:-}"

out="$proj_dir/sample_setup.txt"
printf 'sample\tlabel\n' > "$out"

declare -A labels
if [[ -n "$label_map" ]]; then
  while IFS=$'\t' read -r s l; do
    [[ -z "$s" ]] && continue
    labels["$s"]="$l"
  done < "$label_map"
fi

for entry in "$proj_dir"/*; do
  name=$(basename "$entry")
  if [[ -d "$entry" && -d "$entry/Unaligned" ]]; then
    printf '%s\t%s\n' "$name" "${labels[$name]:-$name}" >> "$out"
  fi
done

echo "Wrote $out:" >&2
cat "$out" >&2
