#!/bin/bash
# K 步静态验收：等 mockfs 档内核构建结束，再用 strings 数探针是否真进了内核。
# 判据分两层：(a) J 步两条不回归（mockfs 驱动 + 挂根探针）；(b) K 步六条新探针各 >=1。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/k7-verify-el0.txt
: > "$OUT"
exec >>"$OUT" 2>&1

LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
KDIR=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel
K=$KDIR/source-kernel.macho
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== 0. 等构建结束 =="
pid=$(cat "$LOGD/kernel-mockfs.pid" 2>/dev/null)
echo "pid=$pid start=$(date +%T)"
t0=$(date +%s)
while [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; do sleep 15; done
echo "end=$(date +%T) elapsed=$(( $(date +%s) - t0 ))s"

LOG=$(cat "$LOGD/kernel-mockfs-latest.txt")
echo "LOG=$LOG"
echo
echo "== 1. 构建日志尾部 =="
tail -30 "$LOG"

echo
echo "== 2. 22z 有没有重放进工作树 =="
printf 'xnu-work INIT try hit=%s\n' "$(grep -c 'INIT try' "$X/bsd/kern/kern_exec.c")"
printf 'xnu-work INIT returned hit=%s\n' "$(grep -c 'INIT returned' "$X/bsd/kern/bsd_init.c")"
printf 'xnu-work EL0 MACH hit=%s\n' "$(grep -c 'EL0 MACH' "$X/osfmk/arm64/sleh.c")"
printf 'xnu-work EL0 UNIX hit=%s\n' "$(grep -c 'EL0 UNIX' "$X/osfmk/arm64/sleh.c")"

echo
echo "== 3. 内核件 =="
ls -la "$K"
sha256sum "$K"
printf 'source-mockfs-mode=%s\n' "$(cat "$X/.source-mockfs-mode" 2>/dev/null || echo NONE)"

echo
echo "== 4. strings 计数（探针真进内核没有）=="
for s in mockfs 'MR exhausted last=' 'INIT try' 'INIT exec ok' 'INIT err=' 'INIT returned' 'EL0 MACH' 'EL0 UNIX'; do
  printf '%-24s hit=%s\n' "$s" "$(strings -a "$K" | grep -c -F "$s")"
done

echo
echo "== 5. 判定 =="
MK=$(strings -a "$K" | grep -c mockfs)
MP=$(strings -a "$K" | grep -c -F 'MR exhausted last=')
I1=$(strings -a "$K" | grep -c -F 'INIT try')
I2=$(strings -a "$K" | grep -c -F 'INIT exec ok')
I3=$(strings -a "$K" | grep -c -F 'INIT err=')
I4=$(strings -a "$K" | grep -c -F 'INIT returned')
E1=$(strings -a "$K" | grep -c -F 'EL0 MACH')
E2=$(strings -a "$K" | grep -c -F 'EL0 UNIX')
if [ "$MK" -ge 50 ] && [ "$MP" -eq 1 ] && [ "$I1" -ge 1 ] && [ "$I2" -ge 1 ] && \
   [ "$I3" -ge 1 ] && [ "$I4" -ge 1 ] && [ "$E1" -ge 1 ] && [ "$E2" -ge 1 ]; then
  echo "EL0-PROBE-IN-KERNEL OK (mockfs=$MK init=$I1/$I2/$I3/$I4 el0=$E1/$E2)"
else
  echo "EL0-PROBE-IN-KERNEL FAIL mockfs=$MK mr=$MP init=$I1/$I2/$I3/$I4 el0=$E1/$E2"
fi
echo done
