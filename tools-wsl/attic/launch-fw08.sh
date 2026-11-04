#!/bin/bash
# #16：上屏补丁后重编，run-08
set -uo pipefail
WS=/home/unixnu/code/umi-work-pin
NAME=run-08
sed -i 's/\r$//' /usr/local/bin/uefi-fw-build
nohup bash /usr/local/bin/uefi-fw-build "$NAME" > "$WS/out/umi-fw/$NAME.outer.log" 2>&1 &
PID=$!
sleep 1
cat > "$WS/out/tui-state" <<EOF
PHASE=build
RUN=uefi-fw $NAME（UmiMemoryDiag 上屏补丁）
TOOL=edk2 CLANGPDB + LLVM18 farm / -j 4
LOG=$WS/out/umi-fw/$NAME/firmware.log
START_TS=$(date +%s)
NOTE1=DEBUG 只走串口；已加 MemOut.h 同时上屏 + 结尾 SUMMARY + 按键停留
NOTE2=真机无串口/无 USB 日志，屏是唯一出口
TASK1=done|#10 菜单镜像已上机（零写盘）
TASK2=run|#16 ram 档镜像（本次编 $NAME）
TASK3=block|#15 需 Apple 参考件
TASK4=wait|#16 上机：fastboot boot + 拍屏
PID=$PID
EOF
echo "started pid=$PID name=$NAME"
