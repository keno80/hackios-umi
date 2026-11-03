#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/md0-chain7.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree

say "== 0. 找可用的 Mach-O nm =="
ls /opt/unixnu-linux/llvm/bin/ 2>/dev/null | head -30 >> "$OUT"
say "-- xcrun -find nm --"
tr -d '\r' < /dev/null
source /usr/local/bin/unixnu-env 2>/dev/null
export PATH=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/scripts/linux:$PATH
ls -l /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/scripts/linux/xcrun 2>&1 >> "$OUT"

say
say "== 1. memdev.c 的 ifdef 区间（确认 mdevadd/mdevlookup 在区间外）=="
grep -n '^#if\|^#endif\|^#else\|^mdevadd\|^mdevlookup\|^mdevgetrange\|^mdevinit\|^mdevstrategy\|^mdevrw\|^mdevopen\|^mdevioctl\|^mdevsize\|^const struct bdevsw\|^static const struct' "$W/bsd/dev/memdev.c" >> "$OUT" 2>&1

say
say "== 2. 我们的 ADT/DT 里有没有 /chosen/memory-map =="
D=/home/unixnu/code/umi-work-pin/devices/umi
python3 - <<'PY' >> "$OUT" 2>&1
import sys
sys.path.insert(0, "/home/unixnu/code/umi-work-pin/devices/umi/scripts")
src = open("/home/unixnu/code/umi-work-pin/devices/umi/scripts/umi_adt.py").read()
import re
for i, ln in enumerate(src.splitlines(), 1):
    if "memory-map" in ln or "RAMDisk" in ln or "ephemeral" in ln:
        print(f"{i}: {ln.strip()[:160]}")
PY
say "-- 现用 DT 来源（running.dtb / 合并后的 adt）--"
find /home/unixnu/code/umi-work-pin -maxdepth 5 -name '*.adt' -o -maxdepth 5 -name 'running.dtb' -o -maxdepth 5 -name 'kernel.macho.adt*' 2>/dev/null | head -10 >> "$OUT"
say "-- 用 dtc 反解当前 ADT，看 chosen/memory-map --"
ADT=$(find /home/unixnu/code/umi-work-pin/out -maxdepth 6 -name '*.adt' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2)
say "ADT=$ADT"
if [ -n "${ADT:-}" ]; then
  (command -v dtc >/dev/null && dtc -I dtb -O dts "$ADT" 2>/dev/null | grep -A 12 'chosen' | head -40) >> "$OUT" 2>&1
fi

say
say "== 3. DarwinBoot 是否真的填 RAMDisk 占位 =="
grep -rn 'RAMDisk' /home/unixnu/code/UniXNU/drivers/DarwinBoot/DarwinBootPkg --include='*.c' --include='*.h' 2>/dev/null | head -20 >> "$OUT"

say
say "== 4. didRam 的定义与首次调用位置 =="
grep -n 'didRam' "$W/iokit/bsddev/IOKitBSDInit.cpp" >> "$OUT" 2>&1
say "-- IOFindBSDRoot 开头 740..790 --"
sed -n '740,760p' "$W/iokit/bsddev/IOKitBSDInit.cpp" >> "$OUT" 2>&1
say done
