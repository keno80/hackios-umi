#!/bin/bash
# 一次性取证：owner-root 第一趟为什么撞 crypto 闸门
set -u
W=/home/unixnu/code/umi-work-pin
D=$(ls -t $W/out/umi-xnu/umi/logs | head -1)
echo "== 最新 log 目录: $D"
ls -l $W/out/umi-xnu/umi/logs/$D
echo
echo "== bootstrap.log 尾部 40 行"
tail -40 $W/out/umi-xnu/umi/logs/$D/bootstrap.log
echo
echo "== 该步实际 env（environment.json 里 crypto 相关）"
grep -E "CRYPTO|CORECRYPTO|VERIFIED|NATIVE_UFS|OWNER" $W/out/umi-xnu/umi/logs/$D/environment.json
echo
echo "== 打印这条报错的脚本与行号（三处副本）"
for f in $W/sources/UniXNU/scripts/build-xnu-4k-baseline.sh \
         $W/out/umi-xnu/umi/tree/scripts/build-xnu-4k-baseline.sh; do
  echo "--- $f"
  [ -e "$f" ] && grep -n "qualified original prelinked" -B4 "$f" | head -20 || echo "  (不存在)"
done
echo
echo "== 调用方式：build_umi_xnu.py 里怎么起这个脚本的"
grep -n "build-xnu-4k-baseline\|baseline" $W/tools/build_umi_xnu.py | head -12
echo
echo "== 脚本里 OWNER_ROOT_PROBE 用到的变量名（是否有第二个闸门）"
grep -n "OWNER_ROOT_PROBE\|XNU_VERIFIED_ROOT_PROBE" $W/out/umi-xnu/umi/tree/scripts/build-xnu-4k-baseline.sh | head
