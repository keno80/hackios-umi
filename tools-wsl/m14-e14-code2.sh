#!/bin/bash
# 上一版 find 没吃到路径（G 为空）。这次用字面路径。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/m14-e14-code2.txt
: > "$OUT"
exec >>"$OUT" 2>&1

WS=/home/unixnu/code/umi-work-pin
G=$WS/sources/UniXNU/scripts/qemu-entry/gdb-stop.py
R=$WS/out/umi-qemu

echo "== 0. 文件在不在 =="
ls -la "$G"; wc -l "$G"

echo
echo "== 1. read-memory 处理段 =="
awk 'NR>=1440 && NR<=1560' "$G" | nl -ba -v1440

echo
echo "== 2. 读内存相关函数定义 =="
grep -n 'def [a-z_]*' "$G" | grep -i 'mem\|read\|byte\|gdb\|cmd' | head -40

echo
echo "== 3. E14 字面来源：搜 E + 数字 的构造 =="
grep -n 'E%d\|f"E\|"E{"\|error_code\|E1\|E2\|E3\|E4\|E5\|E6\|E7\|E8\|E9\|E10\|E11\|E12\|E13\|E14' "$G" | head -40

echo
echo "== 4. run-19 的 memory 段（成功值长啥样）=="
python3 -c "
import json
for n in ['run-17-el0-read','run-18-boot-stage','run-19-probe-mockfs']:
    try:
        r=json.load(open('$R/'+n+'/gdb-stop.json'))
        print(n, json.dumps(r.get('memory',{}))[:600])
    except Exception as e: print(n,'ERR',e)
"

echo
echo "== 5. 走查件 __text 尾部反汇编（0x100003f80-0x100004000）=="
F=/mnt/e/Code/HackIos/out/fixtures/launchd-walk.macho
/opt/unixnu-linux/CommandLineTools/usr/bin/otool -tvV "$F" 2>/dev/null | tail -40

echo
echo "== 6. 上游件同区间对照（native-user 原版）=="
U=$(ls $WS/out/umi-xnu/umi/fixtures/*/launchd.macho 2>/dev/null | head -1)
echo "U=$U"
[ -n "$U" ] && /opt/unixnu-linux/CommandLineTools/usr/bin/otool -tvV "$U" 2>/dev/null | tail -20
echo "== done $(date -u +%FT%TZ)"
