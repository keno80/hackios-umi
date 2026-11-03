#!/bin/bash
D=/home/unixnu/code/uefi-umi-b
E=/home/unixnu/code/Mu_Basecore
echo "== 1. MuPatches 相对 HEAD 的改动"
git -C "$D" diff --stat -- Resources/MuPatches
echo "== 2. Gic-Spurious 详细报错"
git -C "$E" apply --check -v "$D/Resources/MuPatches/Gic-Spurious.patch" 2>&1 | head -12
echo "== 3. 该文件前 8 行（工作区）"
head -c 400 "$D/Resources/MuPatches/Gic-Spurious.patch" | cat -A | head -10
echo "== 4. HEAD 版前 8 行"
git -C "$D" show HEAD:Resources/MuPatches/Gic-Spurious.patch | head -c 400 | cat -A | head -10
echo "== 5. overlay 源文件前几行"
head -c 400 /home/unixnu/code/umi-work-pin/devices/umi/overlay/Resources/MuPatches/Gic-Spurious.patch 2>/dev/null | cat -A | head -10
echo "== 6. 其余三个补丁的报错首行"
for p in Dxe-Trace Display-Services-Trace Mac-Bash3; do
  echo "-- $p"
  git -C "$E" apply --check -v "$D/Resources/MuPatches/$p.patch" 2>&1 | head -4
done
echo "== 7. run-06 日志里的补丁痕迹"
grep -n -E "applied|PRE-CHECK|APPLY|error" /home/unixnu/code/umi-work-pin/out/umi-fw/run-06/firmware.log 2>/dev/null | head -12
echo "-- outer"
grep -n -E "applied|PRE-CHECK|FAIL" /home/unixnu/code/umi-work-pin/out/umi-fw/run-06.outer.log 2>/dev/null | head -12
