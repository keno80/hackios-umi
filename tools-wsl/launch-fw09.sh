#!/bin/bash
# #18：ram + darwinboot 档重编，run-09
set -uo pipefail
WS=/home/unixnu/code/umi-work-pin
NAME=run-09
python3 /mnt/e/Code/HackIos/tools-wsl/install-bootlog.py > /tmp/bootlog-install.log 2>&1
echo "install rc=$? $(tail -1 /tmp/bootlog-install.log)"
sed -i 's/\r$//' /usr/local/bin/uefi-fw-build
nohup bash /usr/local/bin/uefi-fw-build "$NAME" > "$WS/out/umi-fw/$NAME.outer.log" 2>&1 &
PID=$!
sleep 1
cat > "$WS/out/tui-state" <<EOF
PHASE=build
RUN=uefi-fw $NAME（ram + darwinboot 档）
TOOL=edk2 CLANGPDB + LLVM18 farm / -j 4
LOG=$WS/out/umi-fw/$NAME/firmware.log
START_TS=$(date +%s)
NOTE1=DarwinBoot 装进 APRIORI；新增 UmiBootLog 屏读 ramoops
NOTE2=真机无串口；日志走 0xB0000000 pstore 环（屏读或 Android pstore）
TASK1=done|#17 darwinboot/payload 契约核对（ADT 0x1fbb00000）
TASK2=run|#18 编 $NAME
TASK3=wait|#19 打 64MiB XNU payload + bootimg
TASK4=wait|#20 上机 fastboot boot
PID=$PID
EOF
echo "started pid=$PID name=$NAME"
