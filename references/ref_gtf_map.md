# Mapping alignment `--ref` codes to DESeq2 `-g`/`--GTFinfo` keys

These two files are maintained independently and use **different naming
schemes for the same genome**, so the alignment ref code is not always a
valid GTFinfo key:

- Alignment ref codes: `genome[...]` in `/home/dz288/rms/rnaseq-HISAT2-RF_McCleary.rms`
  (read with `scripts/get_genome_ref.py`; canonical path per
  `references/environment.md`, `assets/rnaseq-HISAT2-RF_McCleary.rms` as
  fallback)
- DEG GTFinfo keys: `gtf_dict` in Dejian's copy of
  `~/bin/deseq2_one-factor_dynamic_slice_refit.R` (see that file's
  "1. DEFINE GTF DICTIONARY" section for the current list)

As of the last time this was checked (2026-09-07), the correspondence was:

| alignment `--ref` | DEG `-g` GTFinfo key | confidence |
|---|---|---|
| `hg38v27` | `hg38v27` | exact |
| `hg38v43` | `hg38v43` | exact |
| `mm39vM35` | `mm39vM35` | exact |
| `mm10_ZsGreen` | `mm10_ZsGreen` | exact |
| `dre` | `dre_GRCz11` | high (both point at Ensembl GRCz11) |
| `mm10` | `mm10v15` | medium (only mm10 GTF entry available) |
| `rn6` | `rn6v98` | medium (only rn6 GTF entry available) |
| `S288C` | `Scerevisiae_S288C` | medium |
| `hg19`, `hg38mmubglobin`, `hg38mm10virus`, `hg38HPV16`, `S288C_CUTs_SUTs` | none known | **no mapping** |

**Rule:** for "exact" or "high" confidence rows, proceed but note the mapping
used in the run log. For "medium" confidence rows, proceed but flag it
prominently in the run log and the completion email so Dejian double-checks
it. For "no mapping" (or a `--ref` code not in this table at all, since both
files get new entries over time), stop and ask Dejian which GTFinfo key to
use rather than guessing -- a wrong annotation file silently produces wrong
gene IDs/names in every DEG table, and would not show up as an error.

If you hit a `--ref` code missing from this table, first re-read both source
files (they may have added a matching entry since this table was written)
before treating it as unmapped.
