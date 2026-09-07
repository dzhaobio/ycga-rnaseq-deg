# ycga-rnaseq-deg

A Claude Code [skill](https://code.claude.com/docs) that automates Dejian
Zhao's YCGA bulk RNA-seq alignment + DESeq2 DEG service on Yale McCleary --
from a client's intake email through alignment, differential expression
analysis, results-sharing, and notification.

This repo is meant to be read by an *agent* (Claude Code), not run directly
by hand. If you're a human looking at this on GitHub, `SKILL.md` is the
actual runbook -- it's written as step-by-step instructions for an AI agent
to follow, not documentation in the usual sense.

## Layout

- `SKILL.md` -- the operational runbook: read inputs, resolve where a
  project's files should live, run alignment, run DEG analysis, share
  results, log, and notify. Also documents the checkpoints where the agent
  should stop and ask rather than guess.
- `scripts/` -- small deterministic helpers (genome-ref lookup,
  user-subfolder resolution, `sample_setup.txt` generation, project
  directory naming) so the agent doesn't re-derive this logic, or make
  inconsistent judgment calls, on every run.
- `references/` -- supporting docs loaded as needed:
  - `environment.md` -- every McCleary/YCGA-specific fact this skill
    depends on (paths, modules, Slurm partition/account, etc.) in one
    place, plus what has to change to deploy this on a different HPC.
  - `ref_gtf_map.md` -- the alignment pipeline's genome codes and the DEG
    script's annotation-file keys are maintained independently and don't
    line up 1:1; this reconciles them with a confidence rating.
  - `examples.md` -- pointers to real past projects used as reference
    while building this skill.
- `assets/` -- versioned copies of two scripts Dejian owns and maintains
  himself (the alignment pipeline definition and the DEG R script). These
  are fallbacks for when the live canonical copies aren't reachable (a
  different machine/account); see `environment.md` for why they aren't a
  complete portability solution on their own.

## Status

Built 2026-09-06/07 from `analyis_steps.md`, a by-hand walkthrough of the
xpo7 zebrafish mutant project (Jillian Petrocelli / Ellen Hoffman lab), and
refined against that project's first live run. Everything here targets
McCleary specifically today -- see `references/environment.md` for what
deploying this elsewhere would actually require.
