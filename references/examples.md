# Worked examples (read-only)

These are real past projects. Never edit or create anything inside them --
they're for pattern-matching when a step in SKILL.md is unclear.

- `/gpfs/gibbs/pi/ycga/mane/dz288/Sayantan_Jana.George_Tellides`
- `/gpfs/gibbs/pi/ycga/mane/dz288/Mengfei_Liu`
- `/gpfs/gibbs/pi/ycga/mane/dz288/Elizabeth_Davidson.Ellen_Hoffman` -- same
  lab (Ellen Hoffman) as the xpo7/Jillian Petrocelli project this skill was
  built from; useful for seeing how repeat projects for the same PI/lab
  accumulate as multiple `YYYYMMDD_RNAseq_*` folders under one user
  subfolder, plus a shared `shareResults/` with one entry per project.

## shareResults linking pattern (from `Bo_Jiang.George_Tellides`)

```sh
WD=/gpfs/gibbs/pi/ycga/mane/dz288/Bo_Jiang.George_Tellides/20220206_RNAseq_mm10_n20/DESeq2
for dir in $WD/*/DESeq2_output; do
        targetdir=$(dirname "$dir")
        targetdir=$(basename "$targetdir")
        ln -s "$dir" "$targetdir"
done
```

This is the pattern Step 8 in SKILL.md generalizes: for each comparison
subfolder's `DESeq2_output`, make a symlink named after that comparison at
the destination (project top level, and again inside the matching
`shareResults/<project>` folder).

## The prototype run this skill was extracted from

`/home/dz288/git/rnaseq-deg-ycga/20260907_RNAseq_polyA_dre_n9` (in Dejian's
git-tracked notes folder, not under the base work directory) is the
by-hand walkthrough that produced `analyis_steps.md` -- the xpo7 mutant
zebrafish project for Jillian Petrocelli / Ellen Hoffman. Treat it the same
as the other examples: read-only reference, don't modify it. The real
project this skill should pick up and continue lives at
`/gpfs/gibbs/pi/ycga/mane/dz288/Jillian_Petrocelli.Ellen_Hoffman` (already
created as of 2026-09-05).
