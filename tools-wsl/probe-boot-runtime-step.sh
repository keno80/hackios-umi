#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/boot-runtime-step.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
S=/home/unixnu/code/UniXNU-main
U=/home/unixnu/code/UniXNU-umi

say "== 1. 谁跑 build-boot-runtime.py（步骤名）=="
grep -rn 'build-boot-runtime' "$S/scripts" 2>/dev/null | head -20 >> "$OUT"

say
say "== 2. build-boot-runtime.py 的 request 来源与 data_gib 判定 =="
sed -n '100,175p' "$S/scripts/build-boot-runtime.py" >> "$OUT" 2>&1

say
say "== 3. board.toml 里管 seed 的键（上游示例板）=="
grep -rn 'data_gib\|data-gib\|\[boot' "$S/devices"/*/board.toml 2>/dev/null | head -20 >> "$OUT"
say "-- umi 板 --"
grep -nE 'data_gib|data|\[boot|\[payload|\[userdata' "$U/board.toml" 2>/dev/null | head -30 >> "$OUT"

say
say "== 4. boot-runtime 需要的输入（IPSW OS 卷挂载方式）=="
grep -n 'mount\|hdiutil\|attach\|Ipsw\|ipsw\|OS\b' "$S/scripts/build-boot-runtime.py" 2>/dev/null | head -30 >> "$OUT"
say done
