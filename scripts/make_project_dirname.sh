#!/usr/bin/env bash
# Build the standard YCGA RNAseq project directory name Dejian uses.
# Usage: make_project_dirname.sh <ref_code> <n_samples> [libprep]
#   ref_code   the --ref code used for alignment (e.g. dre, hg38v43, mm39vM35)
#   n_samples  number of samples in this batch
#   libprep    optional: polyA | rRNAdepl -- omit entirely if the client's
#              inputs didn't state a lib prep method (don't guess it)
set -euo pipefail
ref="${1:?ref_code required}"
n="${2:?n_samples required}"
libprep="${3:-}"
date_str=$(date +%Y%m%d)
if [[ -n "$libprep" ]]; then
  echo "${date_str}_RNAseq_${libprep}_${ref}_n${n}"
else
  echo "${date_str}_RNAseq_${ref}_n${n}"
fi
