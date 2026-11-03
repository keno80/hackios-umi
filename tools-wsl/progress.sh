#!/bin/bash
# 进度摘要：阶段 / 计数 / 速率 / ETA / 机器占用
set -u
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
LOG=${1:-$(cat "$LOGD/latest.txt" 2>/dev/null)}
PIDF=$LOGD/toolchain.pid
KIDF=$LOGD/kernel.pid
[ -n "${LOG:-}" ] && [ -f "$LOG" ] || { echo "还没有构建日志"; exit 0; }
pid=""
for p in "$KIDF" "$PIDF"; do
  cand=$(cat "$p" 2>/dev/null || true)
  if [ -n "${cand:-}" ] && kill -0 "$cand" 2>/dev/null; then pid=$cand; break; fi
done
if [ -n "$pid" ]; then state="运行中"; else state="已结束"; fi
started=$(grep -m1 -oE 'start 2[0-9-]+T[0-9:+]+' "$LOG" | awk '{print $2}')
elapsed_min=-
if [ -n "${started:-}" ]; then
  s=$(date -d "${started/T/ }" +%s 2>/dev/null || true)
  [ -n "${s:-}" ] && elapsed_min=$(( ( $(date +%s) - s ) / 60 ))
fi
read -r done total <<< "$(grep -oE '\[[0-9]+/[0-9]+\]' "$LOG" | tail -1 | tr -d '[]' | tr '/' ' ')"
done=${done:-0}; total=${total:-0}
rate=-; eta=-
if [ "$done" -gt 0 ] && [ "$elapsed_min" -gt 0 ]; then
  rate=$(( done / elapsed_min ))
  [ "$rate" -gt 0 ] && [ "$total" -gt "$done" ] && eta=$(( (total - done) / rate ))
fi
pct=$(grep -oE '\[ +[0-9]+%\]' "$LOG" | tail -1 | tr -d '[] ')
errs=$(grep -cE 'error:|FAILED:|ninja: build stopped' "$LOG" 2>/dev/null || true)
load=$(awk '{print $1}' /proc/loadavg)
mem=$(free -m | awk '/^Mem/{printf "%d/%dGB", $3, $2}')
echo "状态=$state 阶段=$(basename "$LOG" | sed 's/-[0-9T-]*\.log$//') 进度=${pct:-?}% ($done/$total) 速率=${rate}/min ETA=${eta}min"
echo "已用=${elapsed_min}min 负载=$load 内存=$mem 错误行=$errs"
echo "日志=$LOG"
