#!/bin/bash
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/k5b-svc-dispatch.txt
: > "$OUT"
exec >>"$OUT" 2>&1
S=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work/osfmk/arm64/sleh.c

echo "== 1. handle_svc(state) 调用点上下文 760..800 =="
sed -n '760,800p' "$S" | awk '{printf "%5d\t%s\n", NR+759, $0}'

echo
echo "== 2. ESR_EC_SVC64 出现处 =="
grep -n 'ESR_EC_SVC64\|is_user' "$S" | head -20

echo
echo "== 3. is_user 怎么算出来的 =="
grep -n 'bool is_user\|is_user =' "$S" | head -10
echo done
