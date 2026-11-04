#!/bin/bash
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/qemu-cmd.txt
D=/home/unixnu/code/umi-work-pin/out/umi-qemu/run-06-root
: > "$OUT"
echo "== runner.log ==" >> "$OUT"
cat "$D/runner.log" >> "$OUT" 2>&1
echo "== provenance.json ==" >> "$OUT"
head -c 2500 "$D/provenance.json" >> "$OUT" 2>&1
echo >> "$OUT"
echo "== run_umi_qemu.py CLI ==" >> "$OUT"
grep -n 'add_argument' /home/unixnu/code/umi-work-pin/tools/run_umi_qemu.py >> "$OUT" 2>&1
