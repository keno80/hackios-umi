#!/bin/bash
# 比较所有 build_umi_xnu.py 副本里 bootstrap 步的 env 覆写，找上游是否把 VERIFIED_ROOT_PROBE 也归零
set -u
for f in $(find /home/unixnu/code -name build_umi_xnu.py -not -path '*/umi-xnu/umi/tree/*' 2>/dev/null | sort); do
  echo "--- $f"
  grep -n -A4 'run("bootstrap", build' "$f" | head -10
done
echo
echo "== 上游 baseline 脚本里闸门上下文（UniXNU-main）"
sed -n '270,285p' /home/unixnu/code/UniXNU-main/scripts/build-xnu-4k-baseline.sh
echo
echo "== 上游有没有自己的 umi 内核构建入口"
ls /home/unixnu/code/UniXNU-main/devices/umi/tools/ 2>/dev/null | head -20
find /home/unixnu/code/UniXNU-umi -maxdepth 3 -name 'build_umi_xnu.py' 2>/dev/null
