#!/bin/bash
D=/home/unixnu/code/uefi-umi-b
E=/home/unixnu/code/Mu_Basecore
echo "== 1. 工作区 DXE.inc/APRIORI.inc 里的 ram 模块"
grep -n -E "UmiRamPayloadDxe|EnglishDxe|DiskIoDxe|Fat" "$D/Platforms/Xiaomi/umiPkg/Include/DXE.inc" "$D/Platforms/Xiaomi/umiPkg/Include/APRIORI.inc"
echo "== 2. HEAD 版本同名字段"
for f in Platforms/Xiaomi/umiPkg/Include/DXE.inc Platforms/Xiaomi/umiPkg/Include/APRIORI.inc; do
  echo "-- $f"
  git -C "$D" show "HEAD:$f" | grep -n -E "UmiRamPayloadDxe|EnglishDxe|DiskIoDxe|Fat"
done
echo "== 3. umi.dsc 里的诊断 App / RamPayload"
grep -n -E "UmiMemoryDiag|UmiPayloadCheck|UmiPayload64Check|UmiRamPayloadDxe|Components" "$D/Platforms/Xiaomi/umiPkg/umi.dsc" | tail -20
echo "== 4. dsc diff"
git -C "$D" diff -- Platforms/Xiaomi/umiPkg/umi.dsc | head -60
echo "== 5. edk2 工作树状态"
echo "  dirty=$(git -C "$E" status --porcelain | wc -l)"
git -C "$E" status --porcelain | head -20
echo "== 6. 4 个补丁的正/反向 check"
for p in Gic-Spurious Mac-Bash3 Dxe-Trace Display-Services-Trace; do
  f="$D/Resources/MuPatches/$p.patch"
  a=FAIL; r=FAIL
  git -C "$E" apply --check "$f" 2>/dev/null && a=APPLIABLE
  git -C "$E" apply --reverse --check "$f" 2>/dev/null && r=ALREADY-APPLIED
  echo "  $p: apply=$a reverse=$r"
done
echo "== 7. 顶层软链位置"
ls -ld "$D/Mu_Basecore" 2>&1 | head -2
ls -ld /home/unixnu/code/umi-work-pin/Mu_Basecore.link-out 2>&1 | head -2
echo "== 8. 上一次 FD 的产出时间"
ls -l "$D/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd" 2>&1 | head -2
ls -l "$D/Build/umiPkg/DEBUG_CLANGPDB/AARCH64/" | head -3
