#!/bin/bash
OUT=/mnt/e/Code/HackIos/out/probes/menu-pack-pre.txt
: > "$OUT"
WS=/home/unixnu/code/umi-work-pin
UEFI=/home/unixnu/code/uefi-umi-b

echo "== 1. cmd_bootimg 实现（要哪些入参）" >> "$OUT"
sed -n '130,160p' "$WS/sources/UniXNU/scripts/unixnu/cli.py" >> "$OUT" 2>&1

echo "== 2. devices/umi board.toml 的 bootimg/firmware 段" >> "$OUT"
grep -nA 12 -E "^\[firmware\]|^\[bootimg\]|^\[\[bootimg\.dtb_node\]\]" "$WS/devices/umi/board.toml" 2>/dev/null | head -60 >> "$OUT"

echo "== 3. 依赖工具齐不齐" >> "$OUT"
for t in clang llvm-objcopy llvm-nm fdtput fdtget mkbootimg.py; do
  case "$t" in
    *.py) printf "%-14s %s\n" "$t" "$(ls $UEFI/Resources/Scripts/mkbootimg.py 2>/dev/null || echo MISSING)";;
    *)    printf "%-14s %s\n" "$t" "$(command -v $t || echo MISSING)";;
  esac
done >> "$OUT"
ls "$UEFI/BootShim/BootShim.S" >> "$OUT" 2>&1
grep -nE "def |uefiplat|verify|expect" "$WS/tools/verify_umi_fd.py" 2>/dev/null | head -25 >> "$OUT"

echo "== 4. BootShim.S 是否已有 umi 版（sha 对照 prepare.json）" >> "$OUT"
sha256sum "$UEFI/BootShim/BootShim.S" >> "$OUT" 2>&1
echo "expect b5c9e4b8fa8a03f3e79f0b242a0fb000d47e55cd936a9c27fb880ed69a217c48" >> "$OUT"

echo "== 5. running.dtb 合法性 + 大小" >> "$OUT"
for p in /mnt/e/Code/HackIos/out/phone3/running.dtb /mnt/e/Code/HackIos/out/phone3/dt/running.dtb; do
  printf "%s " "$p"; python3 -c "
import struct,sys
d=open('$p','rb').read()
print(len(d), hex(struct.unpack_from('>I',d,4)[0]))" >> "$OUT" 2>&1
done

echo "== 6. Resources/Configs/umi.toml 全量（fd base/size 是否还是 0x9fc00000）" >> "$OUT"
cat "$UEFI/Resources/Configs/umi.toml" >> "$OUT" 2>&1
echo "WROTE"
