#!/bin/bash
# #16：ram 档（内存诊断）重编 FD，run-07 增量；把面板指过去
set -uo pipefail
WS=/home/unixnu/code/umi-work-pin
NAME=run-07
mkdir -p "$WS/out/umi-fw"
sed -i 's/\r$//' /usr/local/bin/uefi-fw-build
nohup bash /usr/local/bin/uefi-fw-build "$NAME" > "$WS/out/umi-fw/$NAME.outer.log" 2>&1 &
PID=$!
sleep 1
cat > "$WS/out/tui-state" <<EOF
PHASE=build
RUN=uefi-fw $NAME（ram 档增量）
TOOL=edk2 CLANGPDB + LLVM18 farm / -j 4
LOG=$WS/out/umi-fw/$NAME/firmware.log
START_TS=$(date +%s)
NOTE1=树已切 payload=ram：UmiRamPayloadDxe + Fat/DiskIo/English + UmiMemoryDiag
NOTE2=坑：MuPatches 必须 CRLF（edk2 源文件全 CRLF），LF 化会让 apply 失败
TASK1=done|#10 菜单镜像已上机（fastboot boot，零写盘）
TASK2=run|#16 ram 档 FD 重编（本次 $NAME）
TASK3=block|#15 需 Apple 参考件（packed APFS seed / 参考内核）
TASK4=wait|#16 出镜像后你跑 fastboot boot 读内存图
PID=$PID
EOF
echo "started pid=$PID name=$NAME"
