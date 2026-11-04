#!/bin/bash
# 把 run-24 panic 现场的 pc/lr/寄存器值解成内核符号，定位是哪一处探针把 NULL 解引用了。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/n12-panic-symbol.txt
: > "$OUT"
exec >>"$OUT" 2>&1
WS=/home/unixnu/code/umi-work-pin
OBJ=$WS/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/mach.development.bcm2837.unstripped.noctf
[ -f "$OBJ" ] || OBJ=$(ls -t $WS/out/umi-xnu/umi/tree/build/xnu/ios-obj/*/mach.development*.unstripped* 2>/dev/null | head -1)
echo "OBJ=$OBJ"
ls -la "$OBJ"

NM=$(command -v nm || echo llvm-nm)
"$NM" --version 2>/dev/null | head -1 || true
echo
echo "== 1. 取符号表（按地址排序）=="
"$NM" -n "$OBJ" 2>/dev/null | grep -i ' [tT] ' > /tmp/syms.txt
wc -l /tmp/syms.txt

resolve() {
  local addr="$1"
  echo "--- 0x$addr"
  python3 - "/tmp/syms.txt" "$addr" <<'PY'
import sys
path, target = sys.argv[1], int(sys.argv[2], 16)
best = None
with open(path) as f:
    for line in f:
        parts = line.split()
        if len(parts) < 3:
            continue
        try:
            a = int(parts[0], 16)
        except ValueError:
            continue
        if a <= target:
            best = (a, parts[2])
        else:
            break
if best:
    print("  %s + 0x%x  (sym @ 0x%x)" % (best[1], target - best[0], best[0]))
else:
    print("  NOT-FOUND")
PY
}

echo
echo "== 2. 关键地址 =="
for a in fffffff00772c514 fffffff00772c3b0 fffffff00772c2fc fffffff007adcb18 fffffff007adcb10 fffffff0070d4148 fffffff007a6c6a4 fffffff002d3a7d50; do
  resolve "$a"
done

echo
echo "== 3. 我这次改动的函数在符号表里的地址 =="
for s in reap_child_locked fork fork1 cloneproc bsd_wait proc_wait4 umi_screen_text umi_scr_puts snprintf vsprintf boot_progress_stage; do
  printf '%-24s ' "$s"
  grep -w "$s" /tmp/syms.txt | head -2 | tr '\n' ' '
  echo
done
echo "== done $(date -u +%FT%TZ)"
