#!/bin/bash
# 等 kernel 步编完（以进程退出为判据），然后核对补丁是否真进了内核。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/f-wait-kernel.txt
: > "$OUT"
exec >>"$OUT" 2>&1
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
L=$(cat $LOGD/kernel-mockfs-latest.txt)
PID=$(cat $LOGD/kernel-mockfs.pid 2>/dev/null || echo "")
echo "等待 pid=$PID 退出，日志 $L"
start=$(date +%s)
while [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; do
  sleep 15
  el=$(( $(date +%s) - start ))
  echo "[$el s] $(tail -1 "$L" 2>/dev/null | cut -c1-120)"
done
el=$(( $(date +%s) - start ))
echo "== 结束，用时 ${el} s =="
echo "-- 日志尾部 40 行 --"
tail -40 "$L"
echo
echo "== 产物 =="
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho
ls -la "$K"
sha256sum "$K"
echo
echo "== 内核里是否还找得到 umi_screen_text（画屏器仍在）=="
NM=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}/llvm/bin/llvm-nm
"$NM" --format=posix --define-only "$K" 2>/dev/null | grep -i 'umi_screen\|boot_progress' | head
echo
echo "== boot_progress.h 在重放后的树里是否带我们的桩 =="
grep -n 'umi_screen_text' /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work/osfmk/kern/boot_progress.h
echo "DONE"
