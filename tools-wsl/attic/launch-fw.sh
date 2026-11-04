#!/bin/bash
# 起跑 #8：Linux 编 SILICIUM_UEFI.fd（run-05），并把面板指到 firmware.log
set -uo pipefail
WS=/home/unixnu/code/umi-work-pin
NAME=run-05
mkdir -p "$WS/out/umi-fw"
if kill -0 176923 2>/dev/null; then
  echo "or-02-bootstrap 仍在跑 (pid 176923)，先看一眼再决定"
  ps -o pid,etime,cmd -p 176923
  exit 3
fi
sed -i 's/\r$//' /usr/local/bin/uefi-fw-build
chmod +x /usr/local/bin/uefi-fw-build 2>/dev/null
nohup bash /usr/local/bin/uefi-fw-build "$NAME" > "$WS/out/umi-fw/$NAME.outer.log" 2>&1 &
PID=$!
sleep 1
cat > "$WS/out/tui-state" <<EOF
PHASE=build
RUN=uefi-fw $NAME
TOOL=edk2 CLANGPDB + LLVM18 farm / -j 4
LOG=$WS/out/umi-fw/$NAME/firmware.log
START_TS=$(date +%s)
NOTE1=已修：Mu_Basecore 软链移出 WORKSPACE（消 FILE_CASE_MISMATCH）+ CLANG_BIN 补尾斜杠
NOTE2=#15 第一趟卡在 storage-abi/interface-audit.json（需作者侧参考 Mach-O）
TASK1=done|#14 userdata-root.img 已产出
TASK2=run|#8 Linux 编 SILICIUM_UEFI.fd（本次 $NAME）
TASK3=wait|作者侧 ABI 审计件（interface-audit.json / attempt-55）
TASK4=wait|#15 第二趟 --owner-root audit 最终链
PID=$PID
EOF
echo "started pid=$PID name=$NAME"
