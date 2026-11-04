#!/bin/bash
# 等 run-10-kit 结束（QEMU 进程退出或产出 stop/failure 证据），最多 360s
O=/home/unixnu/code/umi-work-pin/out/umi-qemu/run-10-kit
OUT=/mnt/e/Code/HackIos/out
i=0
while [ $i -lt 72 ]; do
  if [ -f "$O/gdb-stop.json" ] || [ -f "$O/gdb-failure.json" ]; then break; fi
  if ! pgrep -f 'run-10-kit' > /dev/null 2>&1; then
    # QEMU 命令行里含 run-10-kit，进程没了就是跑完/超时
    if ! pgrep -f 'qemu-system-aarch64' > /dev/null 2>&1; then break; fi
  fi
  sleep 5; i=$((i+1))
done
echo "waited=$((i*5))s" > "$OUT/qemu-run10-wait.txt"
bash /tmp/pq10.sh
cat "$OUT/qemu-run10.txt" >> "$OUT/qemu-run10-wait.txt"
