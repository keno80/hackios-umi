#!/bin/bash
# 等 trace 档内核编完，核对画屏进度带真进了 start.o，再把判读证据落盘
set -u
OUT=/mnt/e/Code/HackIos/out/probes/h-wait-kernel.txt
: > "$OUT"
exec >>"$OUT" 2>&1
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
L=$(cat $LOGD/kernel-trace-latest.txt)
PID=$(cat $LOGD/kernel-trace.pid 2>/dev/null || echo "")
echo "等待 pid=$PID 退出，日志 $L"
start=$(date +%s)
while [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; do
  sleep 20
  el=$(( $(date +%s) - start ))
  echo "[$el s] $(tail -1 "$L" 2>/dev/null | cut -c1-120)"
done
echo "== 结束，用时 $(( $(date +%s) - start )) s =="
echo "-- 日志尾部 30 行 --"
tail -30 "$L"
echo
echo "== 产物 =="
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/entry-trace-kernel.macho
ls -la "$K" 2>/dev/null
sha256sum "$K" 2>/dev/null
echo
echo "== start.o 里的三条色带立即数（0xFFFF0000/0xFF0000FF/0xFFFFFF00）与 fb 偏移 =="
O=$(find /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj -name 'start.o' 2>/dev/null | head -1)
echo "obj=$O"
OD=/opt/unixnu-linux/llvm/bin/llvm-objdump
if [ -n "$O" ] && [ -x "$OD" ]; then
  "$OD" -d --triple=aarch64 "$O" 2>/dev/null > /tmp/start-band.s
  echo "mov #0xffff / #0xff00 立即数行："
  grep -nE '0xffff|0xff00|0xffffff' /tmp/start-band.s | head -12
  echo "boot args 取 framebuffer 的偏移行（#0x28/#0x38/#0x48）："
  grep -nE '\[x[0-9]+, #0x(28|38|48)\]' /tmp/start-band.s | head -12
  echo "环地址 0xB0000000 命中=$(grep -ic 'b0000000' /tmp/start-band.s)"
fi
echo
echo "== 内核字符串里的打点前缀 =="
strings -a "$K" 2>/dev/null | grep -c 'UMI XNU'
echo "DONE"
