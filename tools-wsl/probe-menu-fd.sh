#!/bin/bash
OUT=/mnt/e/Code/HackIos/out/menu-fd-content.txt
: > "$OUT"
WS=/home/unixnu/code/umi-work-pin
UEFI=/home/unixnu/code/uefi-umi-b

echo "== 1. reg_ranges 签名" >> "$OUT"
grep -n "def reg_ranges" -A 14 "$WS/tools/analyze_umi.py" >> "$OUT" 2>&1

echo "== 2. 新 FD 里有哪些模块（Build 目录 efi）" >> "$OUT"
find "$UEFI/Build/umiPkg/DEBUG_CLANGPDB" -maxdepth 3 -name "*.efi" 2>/dev/null | sed 's#.*/##' | sort >> "$OUT" 2>&1
echo "-- 菜单关键模块在不在 DSC/FD 里" >> "$OUT"
grep -nE "UmiMemoryDiag|UmiPayloadCheck|UmiPayload64Check|InheritedFb|UmiButtons" "$UEFI/Platforms/Xiaomi/umiPkg/umi.dsc" "$UEFI/Platforms/Xiaomi/umiPkg/umi.fdf" 2>/dev/null | head -30 >> "$OUT"

echo "== 3. run-06 日志里这几个模块有没有被编" >> "$OUT"
L=$(ls -t $WS/out/umi-fw/run-06*.log 2>/dev/null | head -1)
echo " log: $L" >> "$OUT"
grep -oE "(UmiMemoryDiag|UmiPayloadCheck|UmiPayload64Check|InheritedFbDxe|UmiButtonsDxe)" "$L" 2>/dev/null | sort | uniq -c >> "$OUT"

echo "== 4. uefi-umi-b 是不是就是被 overlay 过的树（看文件在不在）" >> "$OUT"
for f in Platforms/Xiaomi/umiPkg/Application/UmiMemoryDiag/UmiMemoryDiag.c Platforms/Xiaomi/umiPkg/Drivers/UmiButtonsDxe/UmiButtons.c Platforms/Xiaomi/umiPkg/Drivers/InheritedFbDxe/InheritedFb.c; do
  printf "%-70s " "$f" >> "$OUT"; ls -la "$UEFI/$f" 2>/dev/null | awk '{print $5, $6, $7, $8}' >> "$OUT" || echo MISSING >> "$OUT"
done

echo "== 5. out/umi-menu-package 内容" >> "$OUT"
ls -R "$WS/out/umi-menu-package" 2>/dev/null | head -40 >> "$OUT"

echo "== 6. bootimg.py 全文关键段" >> "$OUT"
sed -n '1,70p' "$WS/sources/UniXNU/scripts/unixnu/bootimg.py" >> "$OUT" 2>&1

echo "== 7. fd 元信息" >> "$OUT"
sha256sum "$UEFI/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd" 2>/dev/null >> "$OUT"
ls -la "$UEFI/Build/umiPkg/DEBUG_CLANGPDB/FV/" 2>/dev/null >> "$OUT"
echo "WROTE"
