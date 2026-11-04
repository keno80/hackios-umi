#!/bin/bash
# 诊断：u95 探测到底卡在哪一步（进程、fd、wchan、loop 表）。
exec > /mnt/e/Code/HackIos/out/probes/u97-diag-hang.txt 2>&1
set -u
echo "== 进程 =="
ps -eo pid,ppid,etimes,stat,cmd | grep -Ei "probe-apfs|python3|losetup|apfsck|dd " | grep -v grep
echo
echo "== 每个 python 的当前位置 =="
for p in $(pgrep python3); do
  echo "-- pid=$p cmd=$(tr '\0' ' ' < /proc/$p/cmdline)"
  echo "   wchan=$(cat /proc/$p/wchan 2>/dev/null)  stat=$(awk '{print $3}' /proc/$p/stat 2>/dev/null)"
  ls -l /proc/$p/fd 2>/dev/null | tail -4
  echo "   io=$(cat /proc/$p/io 2>/dev/null | grep -E 'read_bytes|write_bytes' | tr '\n' ' ')"
  echo "   栈顶=$(cat /proc/$p/stack 2>/dev/null | head -3 | tr '\n' ' ')"
done
echo
echo "== losetup 表 =="
sudo -n losetup -l 2>&1 | head -10
echo
echo "== 内存/IO =="
free -g | head -3
vmstat 1 3 2>&1 | tail -4
echo
echo "== 探测文件当前尾部 =="
tail -c 600 /mnt/e/Code/HackIos/out/probes/u95-apfs-window-layout.txt
echo
echo "== /tmp 里的中间件 =="
ls -la /tmp/apfs-container-rel /tmp/oswin.env /tmp/nxsb.env 2>&1
echo done
