#!/bin/bash
# A/B 双路构建之前的状态总览
set -u
L=/home/unixnu/code/UniXNU-main/out/unixnu-logs
echo "== 日志目录 =="
ls -1t "$L" | head -8
echo "== latest/pid =="
echo "latest=$(cat "$L/latest.txt" 2>/dev/null)"
tp=$(cat "$L/toolchain.pid" 2>/dev/null)
echo "toolchain.pid=$tp $( [ -n "$tp" ] && (kill -0 "$tp" 2>/dev/null && echo alive || echo dead) )"
echo "== 工具链产物 =="
for t in /opt/unixnu-linux/llvm/bin/clang \
         /opt/unixnu-linux/CommandLineTools/usr/bin/ld \
         /opt/unixnu-linux/CommandLineTools/usr/bin/xnu-host-cc \
         /opt/unixnu-linux/CommandLineTools/libexec/migcom \
         /opt/unixnu-linux/XcodeDefault.xctoolchain/usr/bin/iig \
         /opt/unixnu-linux/bin/lzfse /usr/bin/xcrun; do
  [ -e "$t" ] && echo "OK   $t" || echo "缺失 $t"
done
echo "== 工作区 =="
for w in /home/unixnu/code/umi-work /home/unixnu/code/umi-work-pin; do
  [ -d "$w" ] && echo "存在 $w -> $(ls "$w/sources" 2>/dev/null | tr '\n' ' ')" || echo "缺失 $w"
done
echo "== 等待器 =="
wp=$(cat "$L/wait.pid" 2>/dev/null)
echo "wait.pid=${wp:-none} $( [ -n "${wp:-}" ] && (kill -0 "$wp" 2>/dev/null && echo alive || echo dead) )"
echo "== 占用 =="
free -m | awk '/^Mem/{printf "内存 %d/%dMB ", $3, $2}'
awk '{print "负载", $1, $2}' /proc/loadavg
nproc | awk '{print "核心", $1}'
