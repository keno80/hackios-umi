#!/bin/bash
set -u
D=/home/unixnu/code/uefi-umi-b
M=/home/unixnu/code/Mu_Basecore
git -C "$D" checkout -f -- Resources/MuPatches
echo "== 恢复后的 CR 行数（应与 blob 一致）"
for p in Dxe-Trace Gic-Spurious Display-Services-Trace Mac-Bash3; do
  printf "  %-24s cr=%s\n" "$p" "$(grep -c $'\r' "$D/Resources/MuPatches/$p.patch")"
done
echo "== apply --check"
for p in Gic-Spurious Mac-Bash3 Dxe-Trace Display-Services-Trace; do
  f=$D/Resources/MuPatches/$p.patch
  if git -C "$M" apply --check "$f" 2>/dev/null; then echo "  OK    $p"
  elif git -C "$M" apply --reverse --check "$f" 2>/dev/null; then echo "  ALREADY $p"
  else echo "  FAIL  $p"; git -C "$M" apply --check "$f" 2>&1 | head -3 | sed 's/^/      /'; fi
done
echo "== umi.dsc / DXE.inc 现状（prepare 之后是否还在）"
printf "  dsc 行数=%s  DXE.inc Binaries=%s  APRIORI Binaries=%s\n" \
  "$(wc -l < "$D/Platforms/Xiaomi/umiPkg/umi.dsc")" \
  "$(grep -c 'Binaries/umi' "$D/Platforms/Xiaomi/umiPkg/Include/DXE.inc")" \
  "$(grep -c 'Binaries/umi' "$D/Platforms/Xiaomi/umiPkg/Include/APRIORI.inc")"
grep -n 'InheritedFbDxe\|UmiButtonsDxe' "$D/Platforms/Xiaomi/umiPkg/Include/APRIORI.inc" | sed 's/^/  /'
echo DONE
