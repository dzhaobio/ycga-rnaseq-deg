# Deployment environment: Yale McCleary (current)

Last verified: 2026-09-07, against:
- `assets/rnaseq-HISAT2-RF_McCleary.rms` (synced from
  `/home/dz288/rms/rnaseq-HISAT2-RF_McCleary.rms`, source last modified
  2026-01-27)
- `assets/deseq2_one-factor_dynamic_slice_refit.R` (synced from
  `~/bin/deseq2_one-factor_dynamic_slice_refit.R`, source last modified
  2026-07-18)

This file is the single source of truth for every McCleary/YCGA-specific
fact this skill depends on. `SKILL.md`'s "Fixed reference points" section is
a quick-reference mirror of the same values for convenience during a normal
run -- **when deploying to a different environment, edit this file first,
then update `SKILL.md` to match.**

## Cluster
- HPC: Yale McCleary
- Scheduler: Slurm
- Partition: `ycga`
- Account: `mane`

## Canonical (live) file locations -- prefer these when reachable
- Base work directory: `/gpfs/gibbs/pi/ycga/mane/dz288`
- `rms` engine (YCGA-maintained, expected on `PATH`):
  `/gpfs/gibbs/pi/ycga/mane/ycga_bioinfo/bin_May2023/rms`
- `ycgaFastq` (YCGA-maintained, expected on `PATH`):
  `/gpfs/gibbs/pi/ycga/mane/ycga_bioinfo/bin_May2023/ycgaFastq`
- Canonical alignment pipeline definition:
  `/home/dz288/rms/rnaseq-HISAT2-RF_McCleary.rms`
- Canonical DEG R script: `~/bin/deseq2_one-factor_dynamic_slice_refit.R`
- External share-link tool:
  `python /ycga-gpfs/project/fas/lsprog/tools/externalAccess/createAccessPoint.py`

## Bundled fallback copies (this repo's `assets/`)
Use these ONLY if the canonical live path above isn't reachable -- a
different HPC, a different account, or the canonical file having moved:
- `assets/rnaseq-HISAT2-RF_McCleary.rms`
- `assets/deseq2_one-factor_dynamic_slice_refit.R`

If a run actually falls back to a bundled copy, say so explicitly in that
run's Step 9 log -- it may be stale relative to Dejian's live, actively
maintained copy. Neither bundled file is self-sufficient on its own (see
"Deep coupling" below) -- bundling them buys reproducibility and a fallback,
not portability by itself.

## Compute
- `rms` queue flag: `-n ycgak,ycgalk`
- DEG step compute request:
  `srun --mem=50G -p ycga --time=2-00:00:00 --cpus-per-task=16`
- DEG R module: `R-bundle-Bioconductor/3.15-foss-2020b-R-4.2.0`
- R library path (baked into the DEG script itself, not overridable via a
  flag): `/gpfs/gibbs/project/mane/dz288/R/4.2`

## Notification
- Completion/exception-notification recipient: `dejian.zhao@yale.edu`
- Note: the bundled alignment pipeline ALSO sends its own completion email
  from inside its `sendEmail` step (hardcoded `CC dejian.zhao@yale.edu`) --
  that's separate from this skill's own Step 9 email, not a duplicate to
  remove.

## Deep coupling inside the bundled pipeline file itself
`assets/rnaseq-HISAT2-RF_McCleary.rms` hardcodes far more McCleary-specific
facts than just genome paths: environment modules for HISAT2, StringTie,
BEDTools, Picard, Trim_Galore, FastQC, Quip, Java, and two different Python
versions, plus absolute paths into other YCGA staff's home directories for
utility scripts (e.g. `/gpfs/gibbs/pi/ycga/mane/jk2269/...`,
`/gpfs/ycga/home/jfl27/...`). None of that is reachable or portable outside
this specific McCleary/YCGA environment -- deploying the *pipeline itself*
(not just this skill) elsewhere means rewriting those internals, not just
copying this file.

## Deploying this skill to a different HPC: what actually has to change
1. Everything in "Canonical (live)" above -- point at that HPC's real paths,
   or rely entirely on bundled fallback copies if nothing canonical exists
   there yet.
2. `rms` (the engine) and `ycgaFastq` are YCGA-owned tools. A non-Yale HPC
   almost certainly doesn't have them. Either that HPC has an equivalent
   workflow/queue manager and Steps 4/6/7 in `SKILL.md` need re-deriving
   around it, or this skill only ever targets Yale/YCGA-managed clusters.
3. `createAccessPoint.py` (external share-link tool) is YCGA-specific too --
   a different HPC needs its own way to expose results externally, or this
   step gets dropped/replaced with something else.
4. Every module name above, and every module name embedded inside the
   bundled `.rms` pipeline file -- Lmod module names/versions are specific
   to each cluster's software stack and will not carry over as-is.
5. Genome/GTF reference paths in `references/ref_gtf_map.md` and inside the
   bundled `.rms` file's `genome[...]` dict point at index files that only
   exist on this filesystem. See `SKILL.md` Step 5's "genome not available"
   branch for what to do when a species isn't already indexed on the new
   cluster.
6. Slurm partition/account names (`ycga`/`mane`) are specific to this
   cluster's allocation and won't exist elsewhere.
