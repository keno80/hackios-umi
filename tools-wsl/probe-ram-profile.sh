#!/bin/bash
OUT=/mnt/e/Code/HackIos/out/ram-profile.txt
: > "$OUT"
WS=/home/unixnu/code/umi-work-pin
echo "== 1. prepare 里 payload_profile=ram 会改什么" >> "$OUT"
grep -nE "payload_profile|ram|MemoryDiag|PayloadCheck|DSC|FDF|fv|FV|size" "$WS/tools/prepare_umi_uefi.py" 2>/dev/null | head -40 >> "$OUT"
echo "== 2. FVMAIN 尺寸在哪定义（能不能扩）" >> "$OUT"
grep -rn "FVMAIN\|NumBlocks\|0x1e3\|BlockSize\|EFI_FV_TOTAL" "$WS/sources/uefi-umi/Platforms/Xiaomi/umiPkg/" 2>/dev/null | grep -v Build | head -20 >> "$OUT"
echo "== 3. make_umi_payload 的 diagnostic 档位" >> "$OUT"
grep -nE "def make_payload|diagnostic|memory|payload64|xnu|FAT|ramdisk|size" "$WS/tools/make_umi_payload.py" 2>/dev/null | head -30 >> "$OUT"
echo "== 4. UmiMemoryDiag 会在屏上打什么" >> "$OUT"
grep -nE "Print|UnicodeSPrint|L\"" "$WS/sources/uefi-umi/Platforms/Xiaomi/umiPkg/Application/UmiMemoryDiag/UmiMemoryDiag.c" 2>/dev/null | head -25 >> "$OUT"
echo WROTE >> "$OUT"
