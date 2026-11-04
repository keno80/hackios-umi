set -u
OUT=/mnt/e/Code/HackIos/out/probes/l2-wait-cold.txt
: > "$OUT"
exec >>"$OUT" 2>&1
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/entry-trace-kernel.macho
LOG=$(cat /home/unixnu/code/UniXNU-main/out/unixnu-logs/kernel-cold-latest.txt)
STAMP=/tmp/cold-start-marker
[ -f "$STAMP" ] || touch -d "$(date -d '-6 minutes' +%FT%T)" "$STAMP"
echo "== watch $K  (log $LOG)"
for i in $(seq 1 120); do
  if [ -f "$K" ] && [ "$K" -nt "$STAMP" ]; then
    echo "NEW-KERNEL after ${i} polls"
    break
  fi
  sleep 5
done
echo
echo "== 1. 日志尾 =="
tail -30 "$LOG"
echo
echo "== 2. 三个 kernel 产物 =="
ls -la /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/
echo
echo "== 3. 合并档静态验收 =="
if [ -f "$K" ] && [ "$K" -nt "$STAMP" ]; then
  printf "size=%s\nsha=%s\n" "$(stat -c%s "$K")" "$(sha256sum "$K" | cut -c1-64)"
  printf "red-band(UMI XNU) =%s\n" "$(strings -a "$K" | grep -c 'UMI XNU')"
  printf "mockfs            =%s\n" "$(strings -a "$K" | grep -c mockfs)"
  printf "MR exhausted      =%s\n" "$(strings -a "$K" | grep -c 'MR exhausted last=')"
  for s in 'INIT try' 'INIT exec ok' 'INIT returned' 'EL0 MACH' 'EL0 UNIX'; do
    printf "el0 %-14s=%s\n" "$s" "$(strings -a "$K" | grep -c -F "$s")"
  done
  echo "RESULT $([ "$(strings -a "$K" | grep -c 'UMI XNU')" -ge 1 ] && [ "$(strings -a "$K" | grep -c mockfs)" -ge 50 ] && [ "$(strings -a "$K" | grep -c -F 'EL0 UNIX')" -ge 1 ] && echo ALL-OK || echo INCOMPLETE)"
else
  echo "NO-NEW-KERNEL（还在编或已失败，看日志尾）"
fi
echo "== done $(date -u +%FT%TZ)"
