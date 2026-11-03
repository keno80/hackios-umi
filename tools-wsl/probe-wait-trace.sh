#!/bin/bash
set -u
L=$(cat /home/unixnu/code/UniXNU-main/out/unixnu-logs/unittest-latest.txt)
echo "=== wait_trace 的 clang 原始报错 ==="
awk '/setUpClass \(test_umi_wait_trace/,/^=+$/' "$L" | grep -E "error|warning|note|\.c:[0-9]" | head -20
echo "=== 手工复现 ==="
T=$(mktemp -d)
printf '#include <stdio.h>\nint main(void){puts("ok");return 0;}\n' > "$T/t.c"
clang -std=c11 -Wall -Wextra -Werror -Wno-unused-function -fsanitize=address,undefined -I /home/unixnu/code/umi-work/devices/umi/package/boot-progress "$T/t.c" -o "$T/t" 2>&1 | head -6
echo "最小样例 exit=$? （0 说明问题在测试自己的源码）"
grep -n "clang" /home/unixnu/code/umi-work/tests/test_umi_wait_trace.py | head -6
