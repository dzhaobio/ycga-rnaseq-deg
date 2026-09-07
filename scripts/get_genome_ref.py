#!/usr/bin/env python3
"""List/match genome refs declared in a McCleary rnaseq .rms pipeline file.

Read-only: only greps the given pipeline file, never modifies it. Dejian's
rms pipelines declare genomes as lines like:

    genome['dre']="/gpfs/.../zebrafishGRCz11Rnaseq" #7/1/2021

This script finds those lines and, given a free-text query (a species name,
common name, or a ref code), prints candidate matches so the agent doesn't
have to eyeball a 40-line file by hand each time -- and so the same matching
logic is used every run instead of ad hoc guessing.

Usage:
    get_genome_ref.py <rms_path> [query]

With no query, prints every declared genome. With a query, matches it
case-insensitively against the ref code, the path, and the trailing comment.
Exit code 2 means "no match" -- do not guess; ask Dejian or check if a new
genome needs to be added (see analyis_steps.md's "reference genome not
available" branch).
"""
import argparse
import re
import sys

PATTERN = re.compile(
    r"""genome\[['"](?P<key>[^'"]+)['"]\]\s*=\s*['"](?P<path>[^'"]+)['"](?:\s*#\s*(?P<comment>.*))?"""
)


def load_genomes(rms_path):
    genomes = []
    with open(rms_path) as fh:
        for line in fh:
            m = PATTERN.search(line)
            if m:
                genomes.append((m.group("key"), m.group("path"), (m.group("comment") or "").strip()))
    return genomes


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("rms_path", help="path to the .rms pipeline file to read (never edit it)")
    ap.add_argument("query", nargs="?", default=None, help='free-text hint, e.g. "zebrafish" or "dre"')
    args = ap.parse_args()

    genomes = load_genomes(args.rms_path)
    if not genomes:
        print(f"No genome[...] entries found in {args.rms_path}.", file=sys.stderr)
        sys.exit(1)

    if args.query:
        q = args.query.lower()
        hits = [g for g in genomes if q in g[0].lower() or q in g[1].lower() or q in g[2].lower()]
    else:
        hits = genomes

    if not hits:
        print(f"No match for '{args.query}'. All available refs in {args.rms_path}:")
        for key, path, comment in genomes:
            print(f"  {key}\t{path}\t{comment}")
        sys.exit(2)

    for key, path, comment in hits:
        print(f"{key}\t{path}\t{comment}")


if __name__ == "__main__":
    main()
