#!/bin/bash
D=/home/unixnu/code/uefi-umi-b
git -C "$D" checkout -- Resources/MuPatches
echo "MuPatches dirty=$(git -C "$D" status --porcelain -- Resources/MuPatches | wc -l)"
echo "== 全树状态"
git -C "$D" status --porcelain
echo "== ram 模块仍在（应为 1/1/1）"
grep -c UmiRamPayloadDxe "$D/Platforms/Xiaomi/umiPkg/Include/DXE.inc" "$D/Platforms/Xiaomi/umiPkg/Include/APRIORI.inc"
grep -c UmiMemoryDiag "$D/Platforms/Xiaomi/umiPkg/umi.dsc"
echo "== 补丁 pre-check（HEAD 版，按顺序累积）"
E=/home/unixnu/code/Mu_Basecore
git -C "$E" checkout -- .
for p in Gic-Spurious Mac-Bash3 Dxe-Trace Display-Services-Trace; do
  if git -C "$E" apply --check "$D/Resources/MuPatches/$p.patch" 2>/dev/null; then
    git -C "$E" apply "$D/Resources/MuPatches/$p.patch" && echo "  OK    $p"
  else
    echo "  FAIL  $p"
  fi
done
echo "  edk2 dirty=$(git -C "$E" status --porcelain | wc -l)"
for p in Display-Services-Trace Dxe-Trace Mac-Bash3 Gic-Spurious; do
  git -C "$E" apply --reverse "$D/Resources/MuPatches/$p.patch" 2>/dev/null
done
echo "  回滚后 dirty=$(git -C "$E" status --porcelain | wc -l)"
