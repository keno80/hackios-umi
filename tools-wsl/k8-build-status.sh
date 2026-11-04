#!/bin/bash
# 看一眼 mockfs 档构建还在不在跑、日志走到哪。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/k8-build-status.txt
: > "$OUT"
exec >>"$OUT" 2>&1
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
date -u +== %T ==
pid=$(cat "$LOGD/kernel-mockfs.pid" 2>/dev/null || echo NOPIDFILE)
echo "pid=$pid alive=$(kill -0 "$pid" 2>/dev/null && echo YES || echo NO)"
echo "latest=$(cat "$LOGD/kernel-mockfs-latest.txt" 2>/dev/null || echo EMPTY)"
ls -la "$LOGD"/kernel-mockfs-*.log 2>/dev/null | tail -3
L=$(cat "$LOGD/kernel-mockfs-latest.txt" 2>/dev/null)
if [ -n "$L" ] && [ -f "$L" ]; then
  echo "log-size=$(stat -c %s "$L")"
  echo "-- tail 15 --"
  tail -15 "$L"
fi
echo "== 工作树里 22z 打点重放没有 =="
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
grep -c 'INIT try' "$X/bsd/kern/kern_exec.c" 2>/dev/null || echo "no-worktree-yet"
echo done
