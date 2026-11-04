#!/bin/bash
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/prep-check.txt
: > "$OUT"
ROOT=/home/unixnu/code/umi-work-pin
XNU=$ROOT/out/umi-xnu/umi/tree/.cache/xnu-work
echo "== locate scripts ==" >> "$OUT"
find "$ROOT" -maxdepth 6 -name 'build_umi_xnu.py' -o -maxdepth 6 -name 'prepare-xnu-source.py' >> "$OUT" 2>&1
echo "== reverse-check each umi-xnu patch against current tree ==" >> "$OUT"
PDIR=$(find "$ROOT" -maxdepth 8 -type d -path '*patches/umi-xnu' | head -1)
echo "patchdir=$PDIR" >> "$OUT"
for p in "$PDIR"/*.patch; do
  if git -C "$XNU" apply --reverse --check "$p" >/dev/null 2>&1; then
    echo "APPLIED  $(basename "$p")" >> "$OUT"
  else
    echo "NOTAPPLY $(basename "$p")" >> "$OUT"
  fi
done
echo "== does --stage kernel re-prepare? ==" >> "$OUT"
BS=$(find "$ROOT" -maxdepth 6 -name 'build_umi_xnu.py' | head -1)
grep -n 'stage\|prepare' "$BS" | head -60 >> "$OUT" 2>&1
