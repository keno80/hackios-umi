#!/bin/bash
OUT=/mnt/e/Code/HackIos/out/probes/menu-fdf.txt
U=/home/unixnu/code/uefi-umi-b/Platforms/Xiaomi/umiPkg
: > "$OUT"
echo "== umi.fdf 里的 FV/FD 结构" >> "$OUT"
grep -nE "^\s*(Fd|Fv|SECTION EFI_FIRMWARE_VOLUME|INF|FILE|!include|!if|!ifdef)" "$U/umi.fdf" 2>/dev/null | head -70 >> "$OUT"
echo "== DtPlatform/RamManager 在 FDF/DSC 哪一处" >> "$OUT"
grep -rn "DtPlatform\|RamManager" "$U/" 2>/dev/null | grep -v Build | head -20 >> "$OUT"
echo "== InheritedFbDxe 的 Depex / 依赖协议" >> "$OUT"
cat "$U/Drivers/InheritedFbDxe/InheritedFbDxe.inf" >> "$OUT" 2>&1
echo "== InheritedFb 怎么拿到帧缓冲（前 40 行关键）" >> "$OUT"
grep -nE "Dt|libfdt|GetProp|FixedPcd|Pcd|gEfiDx|FrameBuffer|Base|0x" "$U/Drivers/InheritedFbDxe/InheritedFb.c" | head -30 >> "$OUT"
echo "== UmiButtonsDxe 依赖" >> "$OUT"
grep -nA 10 "\[Depex\]" "$U/Drivers/UmiButtonsDxe/UmiButtonsDxe.inf" >> "$OUT" 2>&1
echo WROTE >> "$OUT"
