#!/bin/bash
# 判清两件事：25z 到底进没进产物内核；现在还有没有在跑构建。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/n5-kernel-check.txt
: > "$OUT"
exec >>"$OUT" 2>&1
WS=/home/unixnu/code/umi-work-pin
K=$WS/out/umi-xnu/umi/kernel/source-kernel.macho
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs

echo "== 1. 产物 =="
ls -la "$K"
sha256sum "$K"
date -u +now=%FT%TZ
echo
echo "== 2. 还有没有构建在跑 =="
pgrep -af 'build_umi_xnu|ninja|make' | head -10
echo "count=$(pgrep -c -f build_umi_xnu 2>/dev/null)"
echo
echo "== 3. 25z 探针串在不在产物里 =="
S=$(strings -a "$K")
for pat in 'FORK cpid=' 'FORK deadparent-reap' 'FORK child-woken' 'REAP cpid=' 'WAIT4 A none' 'WAIT4 B none' 'EL0 IN svc=' 'EL0 OUT svc='; do
  printf '%-26s %s\n' "$pat" "$(printf '%s' "$S" | grep -c "$pat")"
done
echo
echo "== 4. 内核源文件里有没有 25z（打过补丁的工作树）=="
grep -c 'FORK cpid=' $WS/out/umi-xnu/umi/tree/.cache/xnu-work/bsd/kern/kern_fork.c
grep -c 'REAP cpid=' $WS/out/umi-xnu/umi/tree/.cache/xnu-work/bsd/kern/kern_exit.c
echo
echo "== 5. 所有 kernel-walk 日志按时间 =="
ls -lt "$LOGD" | grep kernel-walk | head -6
echo "== done $(date -u +%FT%TZ)"
