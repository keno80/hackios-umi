#!/bin/bash
# 编译进度 + 历史 QEMU run 命名与屏幕证据，便于接续自测。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/f-status.txt
: > "$OUT"
exec >>"$OUT" 2>&1
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
L=$(cat $LOGD/kernel-mockfs-latest.txt)
echo "== 最新 kernel 日志：$L =="
ls -la "$L"
echo "-- 尾部 25 行 --"
tail -25 "$L"
echo
echo "== 是否还在跑 =="
if [ -f $LOGD/kernel-mockfs.pid ] && kill -0 "$(cat $LOGD/kernel-mockfs.pid)" 2>/dev/null; then
  echo RUNNING; else echo NOT-RUNNING; fi
echo
echo "== 补丁是否在重放清单里（日志里搜 boot-stage）=="
grep -n "boot-stage\|umi-xnu" "$L" | tail -30
echo
echo "== 历史 umi-qemu run =="
ls -1 /home/unixnu/code/umi-work-pin/out/umi-qemu/ 2>/dev/null | tail -12
echo
echo "== 最新几个 run 的 screen.png sha =="
for d in $(ls -1t /home/unixnu/code/umi-work-pin/out/umi-qemu/ 2>/dev/null | head -6); do
  p=/home/unixnu/code/umi-work-pin/out/umi-qemu/$d/screen.png
  if [ -f "$p" ]; then echo "$d  $(sha256sum "$p" | cut -c1-64)  $(stat -c %y "$p" | cut -c1-19)"; fi
done
