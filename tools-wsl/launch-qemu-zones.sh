#!/bin/bash
# 后台启动 QEMU 深推（kt_fixed_zones=120），输出落到 E: 供读取
tr -d "\r" < /mnt/e/Code/HackIos/tools-wsl/run-qemu-zones.sh > /usr/local/bin/uefi-qemu-zones
chmod 755 /usr/local/bin/uefi-qemu-zones
setsid nohup uefi-qemu-zones "${1:-run-03-zones}" > /mnt/e/Code/HackIos/out/qemu-zones.txt 2>&1 < /dev/null &
sleep 12
echo "== qemu 进程"
pgrep -fa qemu-system-aarch64 | head -2
echo "== runner 进程"
pgrep -fa run_umi_qemu | head -2
echo "== 状态文件"
cat /home/unixnu/code/umi-work-pin/out/tui-state 2>/dev/null
echo LAUNCHED
