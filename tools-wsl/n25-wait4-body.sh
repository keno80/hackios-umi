#!/bin/bash
# P 步之二：REAP 探针之后到底还跑不跑。
# 拉出 reap_child_locked 尾段与 wait4_nocancel 全貌，找返回用户态前的每一个阻塞点。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/n25-wait4-body.txt
: > "$OUT"
exec >>"$OUT" 2>&1

X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work/bsd/kern/kern_exit.c

echo "== 1. reap_child_locked：REAP 探针之后到函数尾 =="
sed -n '2860,2945p' "$X" | grep -n '' | sed 's/^/  /'

echo
echo "== 2. wait4_nocancel 全文（2950-3180）=="
sed -n '2950,3180p' "$X" | grep -n '' | sed 's/^/  /'

echo
echo "== 3. 2447 / 2711 两处 reap_child_locked 调用点上下文 =="
for L in 2447 2711; do
  echo "-- @$L --"
  sed -n "$((L-12)),$((L+6))p" "$X"
done

echo
echo "== 4. wait4 里 reap 之后的 return 路径关键字 =="
awk 'NR>=2950 && NR<=3180 && /return|reap_child_locked|thread_block|wakeup|p_stat|retval/ {print NR": "$0}' "$X"
echo done
