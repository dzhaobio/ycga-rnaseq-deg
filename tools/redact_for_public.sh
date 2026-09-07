#!/usr/bin/env bash
# Rewrite real names/identifiers in the given files to placeholders, for the
# public mirror of this repo. PRIVATE-ONLY: this script embeds the real
# identifiers in its substitution patterns, so it must never be committed to
# the `public` branch itself -- only used from `master` to generate that
# branch's content. See tools/sync_public_branch.sh for the orchestration.
#
# Usage: redact_for_public.sh <file> [file...]
set -euo pipefail

for f in "$@"; do
  [[ -f "$f" ]] || continue
  perl -0777 -pi -e '
    # Compound names first (longest match wins), then leftover standalone parts.
    s/Dejian\s+Zhao\x27s/the pipeline author\x27s/g;
    s/Dejian\s+Zhao/the pipeline author/g;
    s/\bDejian\x27s\b/the analyst\x27s/g;
    s/\bDejian\b/the analyst/g;
    s/dejian\.zhao\@yale\.edu/author\@example.edu/g;

    s/Sayantan_Jana\.George_Tellides/Researcher_A.PI_A/g;
    s/Bo_Jiang\.George_Tellides/Researcher_E.PI_A/g;
    s/\bGeorge_Tellides\b/PI_A/g;
    s/\bSayantan_Jana\b/Researcher_A/g;
    s/\bBo_Jiang\b/Researcher_E/g;

    s/Elizabeth_Davidson\.Ellen_Hoffman/Researcher_C.PI_B/g;
    s/Jillian_Petrocelli\.Ellen_Hoffman/Researcher_D.PI_B/g;
    s/Jillian Petrocelli \/ Ellen Hoffman/Researcher_D \/ PI_B/g;
    s/Jillian Petrocelli\/Ellen Hoffman/Researcher_D\/PI_B/g;
    s/Jillian Petrocelli/Researcher_D/g;
    s/\bEllen_Hoffman\b/PI_B/g;
    s/\bEllen Hoffman\b/PI_B/g;
    s/\bElizabeth_Davidson\b/Researcher_C/g;

    s/\bMengfei_Liu\b/Researcher_B/g;

    s/Qin Yan\x27s/PI_C\x27s/g;

    s/\bjk2269\b/COLLEAGUE1/g;
    s/\bjfl27\b/COLLEAGUE2/g;
    s/\bdz288\b/USERID/g;
  ' "$f"
done
