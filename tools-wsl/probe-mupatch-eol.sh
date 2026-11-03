#!/bin/bash
D=/home/unixnu/code/uefi-umi-b
E=/home/unixnu/code/Mu_Basecore
echo "== 1. edk2 目标源文件行尾"
for f in ArmPkg/Drivers/ArmGicDxe/GicV3/ArmGicV3Dxe.c MdeModulePkg/Core/Dxe/Dispatcher/Dispatcher.c; do
  printf "  %-55s CR行数=%s 总行数=%s\n" "$f" "$(grep -c $'\r' "$E/$f")" "$(wc -l < "$E/$f")"
done
echo "  git 属性: $(git -C "$E" check-attr text eol -- ArmPkg/Drivers/ArmGicDxe/GicV3/ArmGicV3Dxe.c | tr '\n' ' ')"
echo "  core.autocrlf=$(git -C "$E" config core.autocrlf) core.eol=$(git -C "$E" config core.eol)"
echo "== 2. LF 版 vs CRLF 版 apply --check"
for p in Gic-Spurious Dxe-Trace Display-Services-Trace Mac-Bash3; do
  git -C "$D" show "HEAD:Resources/MuPatches/$p.patch" | tr -d '\r' > "/tmp/$p.lf.patch"
  git -C "$D" show "HEAD:Resources/MuPatches/$p.patch" > "/tmp/$p.cr.patch"
  a=FAIL; b=FAIL
  git -C "$E" apply --check "/tmp/$p.lf.patch" 2>/dev/null && a=OK
  git -C "$E" apply --check "/tmp/$p.cr.patch" 2>/dev/null && b=OK
  echo "  $p: LF=$a CRLF=$b  工作区=$( [ -f "$D/Resources/MuPatches/$p.patch" ] && (grep -qc $'\r' "$D/Resources/MuPatches/$p.patch" && echo CRLF || echo LF) )"
done
echo "== 3. run-06 outer 日志的补丁段"
grep -n -E "applied|PRE-CHECK|APPLY|移出|回滚|DONE_ROLLBACK|dirty" /home/unixnu/code/umi-work-pin/out/umi-fw/run-06.outer.log | head -20
