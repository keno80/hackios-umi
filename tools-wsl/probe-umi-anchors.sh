#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/umi-patch-anchors.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
U=/home/unixnu/code/UniXNU
W=/home/unixnu/code/umi-work-pin

say "== 1. RamdiskLayout / CopyRamdisk =="
grep -rn 'RamdiskLayout' "$U/drivers/DarwinBoot/DarwinBootPkg/" 2>/dev/null | head -6 >> "$OUT"
F=$(grep -rl 'RamdiskLayout (' "$U/drivers/DarwinBoot/DarwinBootPkg/" 2>/dev/null | grep -v DarwinBoot.c | head -1)
say "F=$F"
grep -n -A28 'RamdiskLayout (CONST\|RamdiskLayout (' "$F" 2>/dev/null | head -45 >> "$OUT"

say
say "== 2. make_umi_payload.py 150-200（initrd 注入锚点）=="
sed -n '150,200p' "$W/tools/make_umi_payload.py" >> "$OUT" 2>&1
say "-- argparse 段 --"
grep -n 'add_argument' "$W/tools/make_umi_payload.py" | head -20 >> "$OUT"

say
say "== 3. run_umi_qemu.py 110-160 =="
sed -n '110,160p' "$W/tools/run_umi_qemu.py" >> "$OUT" 2>&1
say "-- 调用 make_umi_payload 的命令行 --"
grep -n -B4 -A16 'make_umi_payload' "$W/tools/run_umi_qemu.py" | head -40 >> "$OUT"

say
say "== 4. umi_adt.py 位置与 at()/Node API =="
find /home/unixnu/code -maxdepth 5 -name 'umi_adt.py' 2>/dev/null | head -5 >> "$OUT"
A=$(find /home/unixnu/code -maxdepth 5 -name 'umi_adt.py' 2>/dev/null | head -1)
grep -n 'def at\|def encode\|def decode\|class \|def node' "$A" 2>/dev/null | head -20 >> "$OUT"
say done
