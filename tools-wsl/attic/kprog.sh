#!/bin/bash
# 路A 内核构建进度：阶段 + 对象文件计数 + 负载，用于给 ETA
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi
O=$W/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837
LOG=$(cat /home/unixnu/code/UniXNU-main/out/unixnu-logs/kernel-pin-latest.txt)
PID=$(cat /home/unixnu/code/UniXNU-main/out/unixnu-logs/kernel-pin.pid)
RUN=$(ls -1t "$W/logs" | grep '^2026' | head -1)
echo "pid=$PID $(kill -0 "$PID" 2>/dev/null && echo 运行中 || echo 已退出)"
echo "主日志=$LOG size=$(stat -c%s "$LOG")"
echo "本次运行=$RUN"
echo "-- 主日志尾部 --"
tail -4 "$LOG"
if [ -n "$RUN" ]; then
  for name in bootstrap kernel package; do
    f="$W/logs/$RUN/$name.log"
    [ -f "$f" ] || continue
    echo "-- $name.log size=$(stat -c%s "$f") mtime=$(stat -c%y "$f" | cut -d. -f1) --"
    tail -3 "$f"
  done
fi
echo "-- 产物计数 --"
echo "osfmk .o = $(find "$O/osfmk" -name '*.o' 2>/dev/null | wc -l)"
echo "bsd  .o = $(find "$O/bsd" -name '*.o' 2>/dev/null | wc -l)"
echo "iokit .o = $(find "$O/iokit" -name '*.o' 2>/dev/null | wc -l)"
echo "libsa/libkern .o = $(find "$O" -name '*.o' -path '*libsa*' 2>/dev/null | wc -l)"
echo "总 .o = $(find "$O" -name '*.o' 2>/dev/null | wc -l)"
echo "总 .po = $(find "$O" -name '*.po' 2>/dev/null | wc -l)"
echo "load=$(cat /proc/loadavg)"
echo "clang 进程数=$(pgrep -c clang)"
echo "-- 内核链接产物 --"
ls -l "$O"/*.unstripped* 2>/dev/null | tail -3
