#!/bin/bash
# R 步之十一：r16 拿到表长（MACH_TRAP_TABLE_COUNT=128）与全表下标，但还没确认
# 「负号→表下标」到底怎么换算（bsd_arm64.c:177 mach_syscall 本体），也不知道越界时内核怎么走。
# 这两条决定走查件的 mach 段该怎么写 x16、能安全打哪些号。
set -u
LOG=/mnt/e/Code/HackIos/out/probes/r17-mach-call-number.txt
: > "$LOG"
exec >> "$LOG" 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
BA=$X/osfmk/arm64/bsd_arm64.c

echo "== 1. mach_syscall 本体（170..245，含换算与越界）=="
sed -n '170,245p' "$BA"

echo
echo "== 2. unix_syscall 对照：正数怎么进 bsd 分派 =="
sed -n '245,300p' "$BA"

echo
echo "== 3. MACH_ARM_TRAP_ABSTIME / CONTTIME / PLATFORM_SYSCALL_TRAP_NO 的值 =="
grep -rn "MACH_ARM_TRAP_ABSTIME\|MACH_ARM_TRAP_CONTTIME\|PLATFORM_SYSCALL_TRAP_NO" "$X" 2>/dev/null | grep -E "define|=" | head -8

echo
echo "== 4. ARM64_SYSCALL_CODE_REG_NUM（x16 是不是寄存器号源）=="
grep -rn "ARM64_SYSCALL_CODE_REG_NUM" "$X" 2>/dev/null | grep define | head -4

echo
echo "== 5. 走查件现在的 svc 发法（walk-user.S 里 mov x16 / svc 原文）=="
grep -n "x16\|svc" /mnt/e/Code/HackIos/tools-wsl/umi-fixture/walk-user.S | head -30
echo "== done $(date -u +%FT%TZ)"
