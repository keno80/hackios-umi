#!/bin/bash
set -u
L=$(cat /home/unixnu/code/UniXNU-main/out/unixnu-logs/unittest-latest.txt)
echo "=== clang 失败原文（第一段 error 上下文） ==="
grep -n "clang:" "$L" | head -10
echo "---"
grep -A3 "CalledProcessError: Command" "$L" | grep -E "error|fatal" | sort | uniq -c | sort -rn | head -10
echo "=== 直接复现：asan 可用性 ==="
printf 'int main(void){return 0;}\n' > /tmp/t.c
clang -std=c11 -fsanitize=address,undefined /tmp/t.c -o /tmp/t 2>&1 | head -5
echo "asan-only exit=$?"
ls /usr/lib/llvm-18/lib/clang/18/lib/ 2>/dev/null | head -8
