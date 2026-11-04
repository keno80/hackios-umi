#!/bin/bash
# R 步之二：等 28z 内核编完，并把它是不是真带上了新判据一次核清。
# 编完不核串就出图 = 白跑一趟手机；这条闸和出图闸同理。
# 等的是 run-kernel-walk.sh（--stage kernel --profile phone --mockfs-root）；
# 别用 run-kernel-pin.sh：那条不带 --mockfs-root 且只重链，会在 crypto kit 上挂 Undefined symbols。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/r9-wait-kernel-28z.txt
: > "$OUT"
exec >> "$OUT" 2>&1
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho
OLD_SHA=efc54c86ef0046296e339d1a02891758e3a16f207a75a01f7b7862d40caf99d7
L=$(cat "$LOGD/kernel-walk-latest.txt")
PID=$(cat "$LOGD/kernel-walk.pid" 2>/dev/null || echo "")

echo "start $(date -Is)  pid=$PID  log=$L"
echo "编前内核 sha=$(sha256sum "$K" | cut -c1-16)"
start=$(date +%s)
deadline=$(( start + 90 * 60 ))
while [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; do
  sleep 30
  el=$(( $(date +%s) - start ))
  echo "[$el s] $(tail -1 "$L" 2>/dev/null | cut -c1-140)"
  [ "$(date +%s)" -gt "$deadline" ] && { echo "!! 超 90 分钟仍在跑，退出等待（不杀进程）"; exit 2; }
done
echo "== 结束，用时 $(( $(date +%s) - start )) s =="
echo "-- 日志尾部 25 行 --"
tail -25 "$L"
echo
echo "== 1. 新内核指纹（必须与 $OLD_SHA 不同）=="
NEW=$(sha256sum "$K")
echo "$NEW"
printf '%s' "$NEW" | grep -q "$OLD_SHA" && { echo "!! sha 没变：编译没产出新内核"; exit 1; }
echo
echo "== 2. 判据串核账（缺任何一条都不配上机）=="
S=$(strings -a "$K")
for pat in 'UMI28 nz=' 'EL0 IN svc=' 'EL0 OUT svc=' 'FORK cx0=0' 'REAP cpid=' 'WAIT4 reaped-return' 'MR exhausted last=' 'INIT exec ok'; do
  printf '%-24s %s\n' "$pat" "$(printf '%s' "$S" | grep -c "$pat")"
done
MISS=0
for pat in 'UMI28 nz=' 'EL0 IN svc=' 'EL0 OUT svc=' 'FORK cx0=0' 'REAP cpid=' 'WAIT4 reaped-return' 'INIT exec ok'; do
  c=$(printf '%s' "$S" | grep -c "$pat")
  [ "$c" -ge 1 ] || { echo "MISSING $pat"; MISS=1; }
done
[ "$MISS" -eq 0 ] && echo "== 全绿：28z 判据已进内核" || { echo "== 拒绝出图：28z 判据没进内核"; exit 1; }
echo done $(date -Is)
