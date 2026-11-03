#!/bin/bash
set -u
M=/home/unixnu/code/Mu_Basecore
D=/home/unixnu/code/uefi-umi-b
CR=$(printf '\r')
echo "== 目标源文件的 CRLF 情况（ext4 克隆）"
for f in ArmPkg/Drivers/ArmGicDxe/GicV3/ArmGicV3Dxe.c MdeModulePkg/Core/Dxe/Dispatcher/Dispatcher.c; do
  printf "  %-55s lines=%-6s cr_lines=%s\n" "$f" "$(wc -l < "$M/$f")" "$(grep -c "$CR" "$M/$f")"
done
echo "== .gitattributes"
ls -a "$M" | grep -i -c gitattributes
head -5 "$M/.gitattributes" 2>/dev/null
echo "== 补丁 blob（git 对象里原始版本）与当前工作树版本的 CR 行数"
for p in Dxe-Trace Gic-Spurious Display-Services-Trace Mac-Bash3; do
  o=$(git -C "$D" show "48bc4121:Resources/MuPatches/$p.patch" | grep -c "$CR")
  w=$(grep -c "$CR" "$D/Resources/MuPatches/$p.patch")
  printf "  %-24s blob_cr=%-6s worktree_cr=%s\n" "$p" "$o" "$w"
done
echo "== Dxe-Trace 第一个 hunk 头 + 目标文件对应行"
sed -n '1,24p' "$D/Resources/MuPatches/Dxe-Trace.patch"
echo "-- Dispatcher.c:515-522"
sed -n '515,522p' "$M/MdeModulePkg/Core/Dxe/Dispatcher/Dispatcher.c" | cat -A | sed 's/\$$/<LF>/' | head -8
echo "== Mu_Basecore 是否脏（此前 DarwinBoot 构建有没有留残留）"
git -C "$M" status --porcelain | head -5
echo DONE
