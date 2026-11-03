#!/bin/bash
set -u
L=$(cat /home/unixnu/code/UniXNU-main/out/unixnu-logs/hostcheck-latest.txt)
echo "日志 $L"
echo "=== 前 25 行（工作区 + repository-check） ==="
sed -n '1,25p' "$L"
echo "=== 失败清单 ==="
grep -E '^(ERROR|FAIL): ' "$L" | sed 's/ \.\.\..*//' | sort | uniq -c
echo "=== 根因统计 ==="
grep -oE "FileNotFoundError: \[Errno 2\] No such file or directory: '[^']*'" "$L" | sed "s/.*: '//;s/'//" | sed 's|.*/out/umi-xnu/||' | head -12
grep -c "CalledProcessError" "$L" | sed 's/^/CalledProcessError: /'
grep -oE "clang: error: [^$]*" "$L" | sort | uniq -c | head -6
