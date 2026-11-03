#!/bin/bash
D=/home/unixnu/code/uefi-umi-b
E=/home/unixnu/code/Mu_Basecore
OV=/home/unixnu/code/umi-work-pin/devices/umi/overlay/Resources/MuPatches
set -u
echo "== 0. 先确保 edk2 干净（只回滚跟踪文件，不 clean，避免删掉已编好的 BaseTools 产物）"
git -C "$E" checkout -- . ; echo "  dirty=$(git -C "$E" status --porcelain | wc -l)"
echo "== 1. HEAD 版 vs overlay 版：是否同一份、行尾如何"
for p in Gic-Spurious Mac-Bash3 Dxe-Trace Display-Services-Trace; do
  git -C "$D" show "HEAD:Resources/MuPatches/$p.patch" > "/tmp/$p.head"
  he=$(grep -c $'\r' "/tmp/$p.head"); ho=$(grep -c $'\r' "$OV/$p.patch" 2>/dev/null || echo -)
  same=$(cmp -s "/tmp/$p.head" "$OV/$p.patch" && echo SAME || echo DIFF)
  printf "  %-26s headCR=%-5s ovlCR=%-5s %s\n" "$p" "$he" "$ho" "$same"
done
echo "== 2. 按 wrapper 顺序用 HEAD 版逐个 apply（累积）"
for p in Gic-Spurious Mac-Bash3 Dxe-Trace Display-Services-Trace; do
  if git -C "$E" apply --check "/tmp/$p.head" 2>/dev/null; then
    git -C "$E" apply "/tmp/$p.head" && echo "  OK    $p"
  else
    echo "  FAIL  $p"; git -C "$E" apply --check "/tmp/$p.head" 2>&1 | head -3 | sed 's#^#      #'
  fi
done
echo "  edk2 dirty=$(git -C "$E" status --porcelain | wc -l)"
git -C "$E" status --porcelain | sed 's#^#    #'
echo "== 3. 全部反向回滚，留干净树"
for p in Display-Services-Trace Dxe-Trace Mac-Bash3 Gic-Spurious; do
  git -C "$E" apply --reverse "/tmp/$p.head" 2>/dev/null && echo "  rolled $p" || echo "  SKIP   $p"
done
echo "  最终 dirty=$(git -C "$E" status --porcelain | wc -l)"
