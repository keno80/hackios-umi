#!/bin/bash
# P 步之三：run-26 屏上没有 EL0 OUT svc=7，但 run-27 证明 wait4 明明成功返回了。
# 怀疑 23z 的 OUT 探针根本不在「continuation 返回」那条路上。把它的落点找出来。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/n26-el0out-probe-site.txt
: > "$OUT"
exec >>"$OUT" 2>&1

X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== 1. EL0 IN / OUT 两个串各在哪个文件哪一行 =="
grep -rn 'EL0 IN svc=\|EL0 OUT svc=' "$X/osfmk/" "$X/bsd/" 2>/dev/null

echo
echo "== 2. OUT 那行的宿主函数（往上找最近的函数头）=="
for f in $(grep -rl 'EL0 OUT svc=' "$X/osfmk/" 2>/dev/null); do
  echo "-- $f --"
  L=$(grep -n 'EL0 OUT svc=' "$f" | head -1 | cut -d: -f1)
  echo "@$L"
  awk -v t="$L" 'NR<=t && /^[a-zA-Z_].*\(/ {fn=NR": "$0} END{print fn}' "$f"
  grep -n '^[a-zA-Z_].*(' "$f" | awk -v t="$L" -F: '$1<t' | tail -2
  echo "-- 上下文 --"
  sed -n "$((L-25)),$((L+8))p" "$f"
done

echo
echo "== 3. handle_unix_syscall64 的返回处：retval 写回与 return =="
F=$X/osfmk/arm64/sleh.c
A=$(grep -n 'handle_unix_syscall64' "$F" | head -3)
echo "$A"
L=$(grep -n 'static void.*$' "$F" >/dev/null; echo)
echo "-- unix syscall 分派尾部 60 行 --"
N=$(grep -n 'unix_syscall64\|handle_unix_syscall' "$F" | tail -3 | head -1 | cut -d: -f1)
echo "@$N"
[ -n "$N" ] && sed -n "$((N-5)),$((N+70))p" "$F"

echo
echo "== 4. continuation 型 syscall 怎么回用户态（set_result / machine_set_syscall_return_value）=="
grep -n 'set_result\|machine_set_syscall_return_value' "$F" | head -20
echo done
