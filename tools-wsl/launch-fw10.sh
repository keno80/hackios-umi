#!/bin/bash
# #18b：修 CopyMem 头文件后续编，run-10
set -uo pipefail
WS=/home/unixnu/code/umi-work-pin
NAME=run-10
python3 /mnt/e/Code/HackIos/tools-wsl/install-bootlog.py > /tmp/bootlog-install.log 2>&1
echo "install rc=$?"
sed -i 's/\r$//' /usr/local/bin/uefi-fw-build
nohup bash /usr/local/bin/uefi-fw-build "$NAME" > "$WS/out/umi-fw/$NAME.outer.log" 2>&1 &
PID=$!
sleep 1
cat > "$WS/out/tui-state" <<EOF
PHASE=build
RUN=uefi-fw $NAME（ram+darwinboot，修 UmiBootLog 后）
TOOL=edk2 CLANGPDB + LLVM18 farm / -j 4
LOG=$WS/out/umi-fw/$NAME/firmware.log
START_TS=$(date +%s)
NOTE1=run-09 缺 BaseMemoryLib 头已修；编 DarwinBoot 进 APRIORI
NOTE2=编完立刻打 64MiB XNU payload 卷
TASK1=done|#17 契约核对（ADT 0x1fbb00000）
TASK2=run|#18 编 $NAME
TASK3=wait|#19 payload 卷 + bootimg
TASK4=wait|#20 上机 fastboot boot
PID=$PID
EOF
echo "started pid=$PID name=$NAME"
