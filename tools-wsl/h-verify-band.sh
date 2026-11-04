#!/bin/bash
# H 步核对：trace 档内核里三条色带是否真编进 start.o
set -u
OUT=/mnt/e/Code/HackIos/out/probes/h-verify-band.txt
: > "$OUT"
exec >>"$OUT" 2>&1
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
L=$(cat $LOGD/kernel-trace-latest.txt)
echo "== 构建日志收尾 6 行 =="
tail -6 "$L"
echo "== 日志里的 error/failed（前 10 条）=="
grep -inE "error:|failed|malformed|hunk|Traceback" "$L" | head -10
echo
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/entry-trace-kernel.macho
echo "== 产物 =="
ls -la "$K"; sha256sum "$K"
O=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/osfmk/DEVELOPMENT/start.o
echo "== start.o =="
ls -la "$O"
for OD in /opt/unixnu-linux/llvm/bin/llvm-objdump /usr/bin/llvm-objdump /usr/bin/llvm-objdump-18; do
  [ -x "$OD" ] && { echo "使用 $OD"; break; }
done
OD=${OD:-/usr/bin/llvm-objdump-18}
"$OD" -d --triple=arm64 "$O" > /tmp/start-band.s 2>&1 || { head -3 /tmp/start-band.s; }
echo "-- 色带立即数 --"
grep -nE '0xffff|0xff00' /tmp/start-band.s | head -12
echo "-- boot args framebuffer 偏移 --"
grep -nE '#0x(28|38|48)\]' /tmp/start-band.s | head -12
echo "-- 4 字节 post-index 填充 --"
grep -nE 'str\s+w[0-9]+, \[x11\], #0x4|b\.hi' /tmp/start-band.s | head -12
echo "-- 环地址 --"
grep -icE 'b0000000' /tmp/start-band.s
echo "DONE"
