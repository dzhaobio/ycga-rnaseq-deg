---
name: ycga-rnaseq-deg
description: Run Dejian Zhao's YCGA bulk RNA-seq alignment + DESeq2 DEG service end-to-end on McCleary -- from a client's intake email/form reply through alignment, DEG analysis, results-sharing, and notification. Use whenever Dejian provides new RNA-seq client inputs (an email, pasted form reply, or YCGA data-link message, often with an Excel sample sheet) and wants the routine analysis pipeline run instead of doing each step by hand. Also use to resume/continue a project that's partway through this pipeline, or to add/redo a DEG comparison for a project that's already been through it (e.g. "add a HET vs HOM comparison to the xpo7 project", "redo the HOM vs WT comparison excluding sample X") -- this works from any session, since project state lives on disk, not in conversation history.
---

# YCGA bulk RNA-seq alignment + DEG pipeline

This automates the workflow Dejian documented by hand while running the
`xpo7`/Jillian Petrocelli project (see `references/examples.md`). It is a
recurring service: every new client email triggers the same sequence of
steps, so this skill exists to run that sequence reliably instead of
re-deriving it from scratch each time.

Read this whole file before starting. It's organized as the sequence of
steps to execute; each step says what's mechanical (safe to just do) versus
what requires judgment (read the client's words and decide) versus what
requires stopping to ask Dejian.

## Fixed reference points

These paths/values are stable parts of Dejian's setup. Don't rediscover them
each run, but do treat anything under "originals -- never edit" as read-only.

This section mirrors `references/environment.md`, which is the source of
truth (and has more deployment/portability detail) -- if the two ever
disagree, or you're setting this skill up on a different HPC, trust
`environment.md` and update this section to match.

- Base work directory: `/gpfs/gibbs/pi/ycga/mane/dz288` -- the routine
  default; Step 1 may override this if the client's inputs specify a
  different work directory for that run.
- `rms` program: on PATH (currently resolves to
  `/gpfs/gibbs/pi/ycga/mane/ycga_bioinfo/bin_May2023/rms`); run `rms -h` if
  unsure of current flags. **Original -- never edit.**
- `ycgaFastq` program: on PATH (currently
  `/gpfs/gibbs/pi/ycga/mane/ycga_bioinfo/bin_May2023/ycgaFastq`). **Original -- never edit.**
- Alignment pipeline: `/home/dz288/rms/rnaseq-HISAT2-RF_McCleary.rms`.
  **Original -- never edit.** Copy it into the project directory before use
  (see Step 4).
- DEG R script: `~/bin/deseq2_one-factor_dynamic_slice_refit.R`. **Original --
  never edit.** Copy it into the project's `DESeq2` directory before use
  (see Step 6).
- Default `rms` queue flag: `-n ycgak,ycgalk` (unless the inputs specify
  otherwise).
- Default: `--NoBigWig` (omit this flag, generating bigwig, only if the
  inputs ask for it).
- Compute node request for the DEG step (replaces the interactive `srun50`
  alias, since this runs non-interactively):
  `srun --mem=50G -p ycga --time=2-00:00:00 --cpus-per-task=16 bash -c '...'`
- R module: `module load R-bundle-Bioconductor/3.15-foss-2020b-R-4.2.0`
- External share-link command (replaces the `ycgaPWDURL` alias, run from
  inside `shareResults`):
  `python /ycga-gpfs/project/fas/lsprog/tools/externalAccess/createAccessPoint.py $PWD > .link`
- Notification/completion recipient: `dejian.zhao@yale.edu` (Dejian himself
  -- these emails are self-notifications, not client-facing, so send them
  as a normal part of the run rather than pausing to confirm). Use `mail -s
  "subject" dejian.zhao@yale.edu` (confirmed installed).
- Read-only worked examples (never modify; look here if a step is unclear
  or you need to see what real output looks like):
  `/gpfs/gibbs/pi/ycga/mane/dz288/Sayantan_Jana.George_Tellides`,
  `/gpfs/gibbs/pi/ycga/mane/dz288/Mengfei_Liu`, and the
  `Elizabeth_Davidson.Ellen_Hoffman` folder (same lab as most new xpo7-style
  requests). See `references/examples.md`.

## Step 1 -- Read the inputs

Inputs arrive as an email, pasted text, or an attached file (sometimes
referencing an Excel sheet with per-sample detail). If the skill was invoked
with `args`, that's either a file path or the raw text -- read it. Otherwise
the client's message is probably already pasted earlier in the conversation.

Extract, and note explicitly which of these were *not* stated (don't invent
them):
- Species (needed for `--ref`)
- Lib prep method: polyA vs rRNA depletion (needed for the folder name)
- Sample list / how to group samples into genotypes or conditions
- Requested comparisons between groups
- Whether more samples are coming for this project (affects nothing
  mechanical right now, but worth noting in the log for Dejian)
- Submitter's name+NetID and PI's name+NetID
- The YCGA data-link URL (and/or a McCleary `ycgaFastq` symlink command like
  the one YCGA emails alongside it)
- Whether bigwig output was requested
- Whether the inputs name a specific work directory to use. Default to the
  base work directory in "Fixed reference points" -- but if the inputs
  specify a different location (e.g. Dejian says to use a particular path
  for this run), use that instead of the routine one. Note which was used
  in the summary below and in the Step 9 log.

If species, the data link, or the grouping/comparison intent are missing or
too vague to act on, stop and ask Dejian -- don't guess at what a client
meant.

**Before moving to Step 2, print the extracted info as a short summary** --
species/`--ref` guess, lib prep, sample groups, comparisons, submitter/PI,
data link, work directory (routine or overridden), and anything left
blank/uncertain. This is the point where a wrong read of the client's
intent is cheapest to catch and correct -- posting it lets Dejian spot a
misread group, wrong species guess, etc. and intervene before any real
directories, downloads, or compute jobs happen. Don't wait for explicit
sign-off to continue (per "When to stop and ask instead of proceeding" at
the end of this file) unless something is genuinely missing/ambiguous per
the rule above -- just surface it, then keep going.

## Step 2 -- Resolve the user subfolder

Run `scripts/resolve_user_subfolder.sh /gpfs/gibbs/pi/ycga/mane/dz288
"<submitter name>" "<PI name>"`. It tags each hit `USER_MATCH:` or
`PI_ONLY:` -- a PI often has many students, so a `PI_ONLY` hit alone (e.g.
several labmates sharing one PI) is not a folder match, just confirmation
the lab is already known here.

- Exactly one `USER_MATCH:` line -> use that folder, move on (ignore any
  `PI_ONLY:` lines).
- No `USER_MATCH:` lines at all -> the subfolder will be `User_Name.PI_Name`
  (spaces to underscores, `.` joining user and PI); create it, plus a
  `shareResults` subfolder inside it if one doesn't already exist.
- More than one `USER_MATCH:` line, or the client's own name is itself
  ambiguous or missing -> stop and ask Dejian. This decision determines
  where a real client's data and results live, so don't guess.

## Step 3 -- Create the project directory

Name it `YYYYMMDD_RNAseq_<libprep>_<ref>_n<N>` via
`scripts/make_project_dirname.sh <ref> <N> [libprep]` -- but you need `<ref>`
first, which means doing Step 5's genome lookup before finalizing this name
(you can do the lookup first and create the directory after; don't block
everything else on it).

`cd` into it once created; everything from here on happens inside it unless
stated otherwise.

## Step 4 -- Get the fastq files and build sample_setup.txt

1. `wget`/`curl` the `ruddle_paths.txt` from the client's data-link URL
   (append `/ruddle_paths.txt` to the base link if the client only gave the
   base URL).
2. Run `ycgaFastq ruddle_paths.txt` (or `ycgaFastq <data-link-url>` directly)
   and answer its create-directories prompt with `y`, e.g.:
   `yes y | ycgaFastq ruddle_paths.txt`
   This creates one subfolder per sample, each containing an `Unaligned/`
   dir of symlinked fastq.gz files.
3. Build `sample_setup.txt` with `scripts/gen_sample_setup.sh .` -- by
   convention the label column matches the sample column exactly, so no
   label map file is needed unless the client's inputs specifically ask for
   renamed samples. Only real sample directories get a row -- do not add one
   for `ruddle_paths.txt` itself (that was a typo in the original by-hand
   walkthrough; the alignment pipeline errors trying to treat it as a
   sample directory).

## Step 5 -- Determine the alignment `--ref` code

Run `scripts/get_genome_ref.py /home/dz288/rms/rnaseq-HISAT2-RF_McCleary.rms
"<species>"` with the species text from the client's inputs (canonical live
path, per `references/environment.md`; fall back to
`assets/rnaseq-HISAT2-RF_McCleary.rms` if it's not reachable, noting in the
log that the bundled copy's genome list may be stale).

- A confident single match -> use that ref code.
- No match -> **don't build a reference genome yourself.** Create a
  `reference_genome` subfolder in the project directory, download the latest
  genome FASTA + GTF for that species from Ensembl/UCSC/NCBI into it, and
  send an email (`mail`) to `dejian.zhao@yale.edu` describing the situation
  and asking him to build the indexed reference manually. Then stop this
  project's alignment step -- there's nothing else to automate until that
  reference exists.

## Step 6 -- Run the alignment (background, no tmux)

Copy the pipeline before running it (never point `rms` at the original).
Prefer the canonical live copy from `references/environment.md`; if it's
not reachable (different HPC/account), fall back to this repo's
`assets/rnaseq-HISAT2-RF_McCleary.rms` and note that in the Step 9 log --
the bundled copy may be stale:
```
cp /home/dz288/rms/rnaseq-HISAT2-RF_McCleary.rms ./rnaseq-HISAT2-RF_McCleary.rms
```
Then launch alignment as a backgrounded process rather than in a tmux
session -- a session-tracked background shell command gets you an automatic
notification on completion, which is what tmux was standing in for:
```
rms -n ycgak,ycgalk ./rnaseq-HISAT2-RF_McCleary.rms --ref <ref> \
  --sampleFile sample_setup.txt --NoBigWig
```
Run this with the Bash tool's `run_in_background` option (adjust `-n` and
drop `--NoBigWig` per the inputs as needed). This can take hours; don't poll
for it manually -- you'll be notified when the process exits.

**Don't trust the completion notification/exit status alone -- verify
`DESeq2/gene_count_matrix.csv` actually exists before moving to Step 7.**
The pipeline's final aggregation step (`prepDE.py`, producing that file)
only runs once *every* row in `sample_setup.txt` succeeds through every
prior step; a single bad row anywhere (see the `ruddle_paths.txt` note in
Step 4 for a real example) silently blocks just that one file forever while
every real per-sample output still gets produced -- so per-sample outputs
existing is not proof the run is actually usable, and the run can exit
"completed with failures" while looking, at a glance, like ordinary partial
progress. If `gene_count_matrix.csv` is missing after completion: check
each sample's `.done` marker files, HISAT2 BAM, and `gene_abund.tab` first
(don't assume real samples are broken) -- if those are all present, the fix
is almost certainly in `sample_setup.txt` (a bad row, a wrong name). Fix it
and re-run the exact same `rms` command: completed steps are skipped via
their `.done` markers, so this re-runs only what's actually missing rather
than redoing hours of alignment.

## Step 7 -- DEG analysis

Work inside the `DESeq2` folder created by alignment.

Copy the R script before running it (never point Rscript at the original).
Prefer the canonical live copy from `references/environment.md`; if it's
not reachable, fall back to this repo's
`assets/deseq2_one-factor_dynamic_slice_refit.R` and note that in the
Step 9 log:
```
cp ~/bin/deseq2_one-factor_dynamic_slice_refit.R ./deseq2_one-factor_dynamic_slice_refit.R
```

Look up the GTFinfo key with `references/ref_gtf_map.md` using the `--ref`
code from Step 5. Stop and ask Dejian if it's unmapped (see that file's
rule) -- don't guess an annotation file.

Build the `-s`/`--sampleGroups` string by matching each sample's folder name
against the group tokens the client used (e.g. `HET`, `HOM`, `WT`): e.g.
`HET:071626_xpo7_HET_2,071626_xpo7_HET_3,071626_xpo7_HET_4;HOM:...;WT:...`.
If the naming doesn't let every sample be assigned unambiguously, stop and
ask Dejian rather than guess a grouping -- a wrong group silently produces
a wrong comparison.

Build the `-c`/`--comparisons` string from the client's requested
comparisons, e.g. `HET/WT;HOM/WT`.

Run on a compute node, backgrounded the same way as Step 6:
```
srun --mem=50G -p ycga --time=2-00:00:00 --cpus-per-task=16 bash -c \
  "module load R-bundle-Bioconductor/3.15-foss-2020b-R-4.2.0 && \
   Rscript ./deseq2_one-factor_dynamic_slice_refit.R \
     -g <gtf_key> -m gene_count_matrix.csv \
     -s '<sampleGroups string>' -c '<comparisons string>' -o ."
```
This produces `DESeq2_output/` (for sharing) plus QC plots one level up, per
the R script's own layout -- see the script's "3. DIRECTORY STRUCTURE SETUP"
section if the layout ever changes.

## Amending an existing project (add or redo a comparison)

Triggers on requests like "add a HET vs HOM comparison to the xpo7
project" or "redo the HOM vs WT comparison" for a project that's already
been through Steps 1-9 at least once. No alignment re-run needed here --
`gene_count_matrix.csv` doesn't change just because you want a different
slice of the same samples compared. This can run from any session, not
just the one that did the original run: everything needed lives in the
project directory on disk, not in conversation history.

1. **Identify the project.** If it's not already unambiguous from context,
   resolve it the same way as Steps 2-3 (user/PI subfolder, then the
   project directory under it) rather than guessing.
2. **Read what's already there** before building any flags:
   - `run_log.txt` in the project directory for the `--ref`/GTFinfo key and
     the exact `-s`/`--sampleGroups` string used originally.
   - Existing subfolders under `DESeq2/DESeq2_output/` (e.g. `HET_vs_WT/`,
     `HOM_vs_WT/`) tell you which comparisons already exist -- don't
     re-list one of these in `-c` unless the client actually wants it
     redone (e.g. after excluding an outlier sample), since the script has
     no idempotency check and will silently overwrite that subfolder's
     output if you do.
3. **Build the command** the same way as Step 7, from inside the existing
   `DESeq2/` folder (reuse the copy of the R script already there -- no
   need to re-copy unless you specifically want to refresh it):
   - `-s`: the **same full sampleGroups string as the original run** (all
     groups, not just the two in the new comparison) -- the global QC
     files (`gene_count_matrix.pdf`, `global_samples_PCA.pdf`,
     `global_sample_clustering.pdf`, `sessionInfo.txt`) are rewritten
     unconditionally every run, scoped to whichever samples `-s` lists as
     active. Narrowing `-s` to only the new comparison's groups would
     silently make those shared files stop representing the full cohort.
   - `-c`: **only** the new (or explicitly-to-be-redone) comparison(s) --
     leaving an already-done one out of `-c` is what skips recomputing it.
   - If the request needs a genuinely new sample or group not in the
     original `-s` string, this is bigger than a same-day amendment: that
     sample needs its own alignment (Steps 4-6) before it has a
     `gene_abund.tab` to include at all.

   **Excluding an outlier sample:** use `-e`/`--exclude_outliers
   <sample_name>` (space/comma/slash-separated for multiple). It's
   evaluated before grouping, so an excluded sample is simply absent from
   every group in `-s` for this run -- no need to hand-edit the `-s`
   string to remove it.

   This has a side effect worth knowing about before running it: the
   shared global QC files (`gene_count_matrix.pdf`, `global_samples_PCA.pdf`,
   `global_sample_clustering.pdf`, `sessionInfo.txt`) are computed from
   whatever `-e` leaves behind, and get overwritten every run just like
   with any other amendment -- so this run will also silently update those
   already-shared files to reflect the cohort *without* the outlier, not
   just the new comparison. If that's the intent (the sample really is a
   confirmed outlier and shouldn't be in the project's QC view going
   forward), that's fine and arguably correct. If you instead want the new,
   outlier-excluded comparison without touching anything already shared
   with the client, run this invocation with a different `-o` (e.g.
   `-o outlier_check` instead of `-o .`) so it writes to its own directory,
   then manually copy just the new comparison's subfolder into the
   project's real `DESeq2_output/` afterward.
4. Run it the same way as Step 7 (`srun` on a compute node, backgrounded).
5. Nothing to redo in Step 8 -- the existing `shareResults` symlink already
   points at the whole `DESeq2_output/` folder, so a new comparison
   subfolder is automatically visible there too.
6. Update `run_log.txt` (append, don't overwrite -- keep the original
   run's record) noting what was added/redone and why, and send a
   completion email the same way as Step 9.

## Step 8 -- Share results

With the current `deseq2_one-factor_dynamic_slice_refit.R` script, all
comparisons share one `DESeq2/DESeq2_output/` folder (each comparison is a
subfolder inside it, e.g. `HET_vs_WT/`, `HOM_vs_WT/`) -- there is only ever
one `DESeq2_output` to link per project, not one per comparison. (The older
per-comparison-own-`DESeq2_output` layout in `references/examples.md`'s
Bo_Jiang example is from a previous version of the R script; that linking
pattern doesn't apply here.)

Only link it into the user's `shareResults/` subfolder -- **do not** also
symlink it at the project directory's top level. Dejian's explicit
preference (2026-09-07): exactly one `DESeq2_output` link should exist, in
`shareResults`, not a second copy sitting in the raw-data/analysis folder.

1. Create a subfolder matching the project directory's name (from Step 3)
   under `shareResults/`, if not already present.
2. Inside `shareResults/` (not the per-project subfolder), check for a
   `.link` file; if missing, create it with the external-share-link command
   from "Fixed reference points" above.
3. Inside the `shareResults/<project_name>/` subfolder, symlink
   `DESeq2/DESeq2_output` from the project directory.

## Step 9 -- Log and notify

Write a log file in the project directory documenting: inputs received,
subfolder decision, `--ref`/GTFinfo choices (and confidence, per
`references/ref_gtf_map.md`), sample grouping used, comparisons run, and
timestamps for each major step -- enough for Dejian to sanity-check the run
without re-deriving it.

Send a completion email to `dejian.zhao@yale.edu` (`mail -s ...`) summarizing
the above and pointing at the shareResults link.

## When to stop and ask instead of proceeding

This pipeline runs client data and real compute jobs, and its outputs go
straight to paying clients -- get these right rather than fast:
- Species, data link, or grouping/comparison intent missing or too vague
- Ambiguous or unmatched user/PI subfolder
- No confident genome match for `--ref` (this also has a defined action:
  email Dejian, don't build it yourself)
- No confident `--ref` -> GTFinfo mapping for the DEG step
- Sample names that can't be cleanly assigned to the client's requested
  groups

Everything else in Steps 1-9 is meant to run without pausing for
confirmation each time -- that's the point of automating it.
