#!/bin/bash
# N 步之九：thread_bootstrap_return 到底定义在哪（本地全树 + 上游 locore.s）
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/n22-find-bootret.txt
: > "$OUT"
exec >>"$OUT" 2>&1

X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== 1. 本地：出现该名的文件 =="
grep -rl 'thread_bootstrap_return' "$X" 2>/dev/null | head -20

echo
echo "== 2. 本地：疑似定义行（排除 extern / 取址）=="
grep -rn 'thread_bootstrap_return' "$X" 2>/dev/null | grep -v 'extern\|thread_continue_t' | head -20

echo
echo "== 3. arm64 汇编里找 =="
ls "$X/osfmk/arm64/" | head -30
for f in "$X"/osfmk/arm64/*.s "$X"/osfmk/arm64/*.S; do
  [ -f "$f" ] || continue
  if grep -q 'bootstrap_return' "$f"; then
    echo "-- $f --"
    grep -n -A25 '_thread_bootstrap_return:' "$f" | head -40
  fi
done

echo
echo "== 4. 上游 xnu-12377.121.6：osfmk/arm64/locore.s 里搜 =="
[ -s /tmp/up-locore.s ] || curl -sS -m 120 -H "Accept: application/vnd.github.raw+json" \
  "https://api.github.com/repos/apple-oss-distributions/xnu/contents/osfmk/arm64/locore.s?ref=xnu-12377.121.6" -o /tmp/up-locore.s
echo "size=$(wc -c < /tmp/up-locore.s)"
grep -n 'bootstrap_return' /tmp/up-locore.s | head
A=$(grep -n '_thread_bootstrap_return:' /tmp/up-locore.s | head -1 | cut -d: -f1)
[ -n "$A" ] && sed -n "$((A-4)),$((A+40))p" /tmp/up-locore.s

echo
echo "== 5. 上游 sched_prim.c 里 return_to_user / 相关 =="
grep -n 'bootstrap_return\|return_to_user\|load_context' /tmp/up-sched_prim.c | head -12
echo done
