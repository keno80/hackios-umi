#!/bin/bash
# 确认 handle_svc 的前置条件：它会不会被 EL1 的 SVC 也打进来（决定 EL0 标记要不要加 cpsr 闸）。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/k5-handle-svc-el.txt
: > "$OUT"
exec >>"$OUT" 2>&1

X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
S=$X/osfmk/arm64/sleh.c

echo "== 1. handle_svc 调用点（分派处看有没有 EL 判定）=="
grep -n 'handle_svc\|sleh_handler\|exception_dispatch' "$S" | head -20

echo
echo "== 2. 文件里 EL0/EL1/PSR mode 的用法 =="
grep -n 'IS_ARM_EL\|ARM_ENABLE_T\|PSR_MODE\|EL0\|EL1' "$S" | head -30

echo
echo "== 3. handle_svc 函数头 20 行 =="
awk '/^handle_svc\(/{f=1} f{printf "%5d\t%s\n", NR, $0; if(++n>20) exit}' "$S"

echo
echo "== 4. syscall_trace 全文（它无条件调用，能反推调用者一定是 EL0）=="
awk '/^syscall_trace\(/{f=1} f{printf "%5d\t%s\n", NR, $0} f&&/^\}/{exit}' "$S"

echo
echo "== 5. sleh.c 有没有现成的 EL 判定宏可用 =="
grep -rn 'IS_ARM_EL1\|IS_ARM_EL0' /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work/mach/arm/psr.h 2>/dev/null | head -10
echo done
