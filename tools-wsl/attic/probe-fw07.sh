#!/bin/bash
D=/home/unixnu/code/uefi-umi-b
B=$D/Build/umiPkg/DEBUG_CLANGPDB
W=/home/unixnu/code/umi-work-pin
echo "== 1. 构建结论"
grep -n -E "^\- Done \-$|error [0-9]|BUILD: Done|FAILED|build rc" "$W/out/umi-fw/run-07.outer.log" 2>/dev/null | head -8
tail -3 "$W/out/umi-fw/run-07/firmware.log" | sed 's#^#  | #'
echo "== 2. FD 与三个诊断 App"
ls -l "$B/FV/SILICIUM_UEFI.fd" | sed 's#^#  #'
for a in UmiMemoryDiag UmiPayloadCheck UmiPayload64Check UmiRamPayloadDxe; do
  f=$(find "$B/AARCH64" -name "$a.efi" 2>/dev/null | head -1)
  printf "  %-22s %s\n" "$a" "${f:-未产出}"
done
echo "== 3. DebugLib 实例（DEBUG 会不会上屏）"
grep -n -E "DebugLib" "$D/Platforms/Xiaomi/umiPkg/umi.dsc" | head -8
echo "== 4. 平台 DebugLib 实现去处"
find "$D/Silicon" -iname "*DebugLib*" -maxdepth 6 -type d 2>/dev/null | sed 's#^#  #'
echo "== 5. FDT/SMEM 之外，菜单是否会把日志显示到屏幕"
grep -rn -l -E "DebugLog|LogBuffer|serial.log|UnixnuLog" "$W/out/umi-menu-package/UniXNUPkg" 2>/dev/null | head -10 | sed 's#^#  #'
echo "== 6. FD 里是否已含 UmiRamPayloadDxe（模块计数）"
ls -l "$B/FV/FVMAIN.Fv" 2>/dev/null | sed 's#^#  #'
grep -c "" "$B/FV/FVMAIN.Fv.txt" 2>/dev/null | sed 's#^#  FVMAIN.Fv.txt 行数=#'
