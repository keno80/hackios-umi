#!/bin/bash
cd /home/unixnu/code/umi-work-pin || exit 1
echo "=== 源码内核产物 ==="
ls -la out/umi-xnu/umi/kernel/ 2>/dev/null | head -20
find out -maxdepth 4 -name "*.macho" -printf "%s %p\n" 2>/dev/null | sort -rn | head -12
echo
echo "=== QEMU 上一次用的内核/payload 记录 ==="
ls out/umi-qemu/ 2>/dev/null | tail -8
for f in out/umi-qemu/run-06-root/*.json out/umi-qemu/run-06-root/**/*.json; do
  [ -f "$f" ] && { echo "--- $f"; head -c 700 "$f"; echo; }
done 2>/dev/null | head -60
echo
echo "=== 我们自己的 qemu 启动脚本里的内核路径 ==="
grep -rn "kernel.macho\|source-kernel" /mnt/e/Code/HackIos/tools-wsl/*.sh 2>/dev/null | head -20
