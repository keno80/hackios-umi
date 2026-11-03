#!/bin/bash
OUT=/mnt/e/Code/HackIos/out/menu-mem3.txt
: > "$OUT"
WS=/home/unixnu/code/umi-work-pin
cd "$WS" || exit 1

echo "== 1. FD 窗口 vs reserved-memory（用仓库自带 reg_ranges）" >> "$OUT"
python3 - <<'PY' >> "$OUT" 2>&1
import sys, json
sys.path.insert(0, "/home/unixnu/code/umi-work-pin/tools")
from analyze_umi import fdt_nodes, reg_ranges
FD_BASE, FD_SIZE = 0x9fc00000, 0x300000
lo, hi = FD_BASE, FD_BASE + FD_SIZE
for name, p in (("phone3/dt", "/mnt/e/Code/HackIos/out/phone3/dt/running.dtb"),
                ("phone3", "/mnt/e/Code/HackIos/out/phone3/running.dtb"),
                ("phone2", "/mnt/e/Code/HackIos/out/phone2/running.dtb")):
    try:
        data = open(p, "rb").read()
    except OSError as e:
        print(name, "SKIP", e); continue
    tree = fdt_nodes(data)
    print(f"-- {name} ({len(data)} B)")
    for path in sorted([k for k in tree if k.startswith("/reserved-memory/")]):
        for (base, size) in reg_ranges(tree, path):
            flag = "  <== OVERLAP FD" if base < hi and base + size > lo else ""
            print(f"   {path.split('/')[-1]:44s} {base:#012x}..{base+size:#012x}{flag}")
    for (base, size) in reg_ranges(tree, "/memory" if "/memory" in tree else "/memory@80000000"):
        print(f"   memory {base:#x} + {size:#x} = ..{base+size:#x}")
PY

echo "== 2. 采集件身份 + RAM 大小（判断哪台是本机 8+256）" >> "$OUT"
for d in /mnt/e/Code/HackIos/out/phone2 /mnt/e/Code/HackIos/out/phone3; do
  echo "-- $d" >> "$OUT"
  python3 -c "
import json,sys
m=json.load(open('$d/manifest.json'))
def g(*ks):
    x=m
    for k in ks:
        x=x.get(k,{}) if isinstance(x,dict) else {}
    return x
print(' keys:', list(m)[:20])
print(' identity:', json.dumps(m.get('identity', m.get('properties',{})))[:400])
" 2>&1 | head -20 >> "$OUT"
  grep -E "MemTotal" "$d/meminfo.txt" 2>/dev/null >> "$OUT"
  grep -oE "androidboot\.(dtb_idx|dtbo_idx|slot_suffix|board_id)=[^ ]*" "$d/cmdline.txt" 2>/dev/null >> "$OUT"
  echo "   soc: $(cat $d/soc.txt 2>/dev/null) kernel: $(cat $d/kernel.txt 2>/dev/null)" >> "$OUT"
done

echo "== 3. unixnu bootimg CLI 参数" >> "$OUT"
grep -nE "add_argument|def cmd_bootimg|bootimg" "$WS/sources/UniXNU/scripts/unixnu/cli.py" 2>/dev/null | head -40 >> "$OUT"
grep -nE "add_argument" "$WS/sources/UniXNU/scripts/unixnu/bootimg.py" | head -40 >> "$OUT"

echo "== 4. Windows 侧有没有 fastboot / platform-tools" >> "$OUT"
ls /mnt/e/Code/HackIos 2>/dev/null | head -30 >> "$OUT"
find /mnt/e -maxdepth 3 -iname "fastboot.exe" 2>/dev/null | head -5 >> "$OUT"

echo "== 5. phone3/dt 里 merged/running 的差异还在不在" >> "$OUT"
ls -la /mnt/e/Code/HackIos/out/phone3/dt/ >> "$OUT" 2>&1
wc -l /mnt/e/Code/HackIos/out/phone3/dt/merge-vs-running.diff 2>/dev/null >> "$OUT"
echo "WROTE"
