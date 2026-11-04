#!/bin/bash
# 出补丁前最后一轮核对：snprintf 的真实实现支持哪些转换、rootdev 在哪被写、上屏画器一行能吃多少字符。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/i-snprintf-screen.txt
: > "$OUT"
exec >>"$OUT" 2>&1

X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== 1. snprintf/vsnprintf 的实现文件 =="
grep -rn "^snprintf\|^vsnprintf\|^__vsnprintf\|_Snprintf" "$X/osfmk" "$X/libkern" "$X/bsd" 2>/dev/null | head -20

echo
echo "== 2. 内核里 snprintf 的实际用法样本（有没有用 %.Ns）=="
grep -rn 'snprintf(' "$X/bsd/kern" 2>/dev/null | head -12

echo
echo "== 3. rootdev 的写入点（含 tab 形式）=="
grep -rnE "^[^/]*rootdev[[:space:]]*=[^=]" "$X/bsd" "$X/osfmk" "$X/security" 2>/dev/null | head -25

echo
echo "== 4. rootdev 声明 =="
grep -rn "rootdev;" "$X/bsd" "$X/osfmk" 2>/dev/null | head -10

echo
echo "== 5. umi_screen_text 的实现 =="
grep -rln "umi_screen_text" "$X" 2>/dev/null | head
for f in $(grep -rln "void.*umi_screen_text" "$X" 2>/dev/null | head -3); do
  echo "--- $f ---"
  grep -n -A40 "umi_screen_text" "$f" | head -70
done

echo
echo "== 6. 画器一行字符数/滚动 =="
grep -rn "SCREEN_COLS\|cols\|per_line\|line_len\|MAX_COL\|1080\|2340" "$X"/osfmk/arm/*.c 2>/dev/null | head -20

echo
echo "== 7. bsd_init_kprintf 的定义 =="
grep -n "define bsd_init_kprintf" -A3 "$X/bsd/kern/bsd_init.c" | head -20

echo
echo "== 8. 内核 printf 的实现与它最终落到哪 =="
ls "$X/osfmk/libsa/" | head -20
grep -rn "^printf(\|^kprintf(\|^vprintf(\|^console_print(" "$X/osfmk" 2>/dev/null | head -10

echo
echo "== 9. umi_screen_text 里有没有 UMI 前缀 =="
grep -rn "UMI \.\." "$X" 2>/dev/null | head -10
echo done

