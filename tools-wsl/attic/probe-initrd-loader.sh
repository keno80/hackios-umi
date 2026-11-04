#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/initrd-loader.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
say "== 0. /home/unixnu/code 顶层 =="
ls -1 /home/unixnu/code 2>/dev/null | head -20 >> "$OUT"

say
say "== 1. 谁解析 unixnu.toml =="
timeout 120 grep -rl 'unixnu\.toml' /home/unixnu/code --include='*.c' --include='*.py' --include='*.md' --include='*.toml' --include='*.h' \
  --exclude-dir=out --exclude-dir=.cache --exclude-dir=.git 2>/dev/null | head -20 >> "$OUT"

say
say "== 2. 谁读 initrd 这个键 =="
timeout 120 grep -rn 'initrd' /home/unixnu/code --include='*.c' --include='*.h' --include='*.py' \
  --exclude-dir=out --exclude-dir=.cache --exclude-dir=.git 2>/dev/null | head -25 >> "$OUT"

say
say "== 3. RAMDisk 填写点（非 DarwinBoot.c）=="
timeout 120 grep -rn 'RamdiskOffset\|RAMDisk' /home/unixnu/code --include='*.c' --include='*.h' \
  --exclude-dir=out --exclude-dir=.cache --exclude-dir=.git 2>/dev/null | head -25 >> "$OUT"
say done
