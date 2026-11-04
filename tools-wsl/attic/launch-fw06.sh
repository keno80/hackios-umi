#!/bin/bash
# 重跑 #8（run-06，增量）并把面板指过去
set -uo pipefail
WS=/home/unixnu/code/umi-work-pin
NAME=run-06
mkdir -p "$WS/out/umi-fw"
sed -i 's/\r$//' /usr/local/bin/uefi-fw-build
nohup bash /usr/local/bin/uefi-fw-build "$NAME" > "$WS/out/umi-fw/$NAME.outer.log" 2>&1 &
PID=$!
sleep 1
cat > "$WS/out/tui-state" <<EOF
PHASE=build
RUN=uefi-fw $NAME（增量）
TOOL=edk2 CLANGPDB + LLVM18 farm / -j 4
LOG=$WS/out/umi-fw/$NAME/firmware.log
START_TS=$(date +%s)
NOTE1=已修：Mu_Basecore 软链移出 WORKSPACE + CLANG_BIN 补尾斜杠（121 个模块已过）
NOTE2=闸：FatPkg Info.obj 并行改名竞态（单跑 rc=0），重跑即过
TASK1=done|#14 userdata-root.img 已产出
TASK2=run|#8 Linux 编 SILICIUM_UEFI.fd（本次 $NAME）
TASK3=block|#15 需 Apple 参考件（packed APFS .dbr seed / 参考内核 Mach-O）
TASK4=wait|#10 上机引导（需你确认写操作）
PID=$PID
EOF
echo "started pid=$PID name=$NAME"
