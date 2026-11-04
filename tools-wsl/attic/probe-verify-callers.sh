#!/bin/bash
# 静态验收：桩改接后，mountroot 之后的 TU 是否真的引用 umi_screen_text。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/f-verify-callers.txt
: > "$OUT"
exec >>"$OUT" 2>&1
WS=/home/unixnu/code/umi-work-pin
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
export PATH="$TC/CommandLineTools/usr/bin:$TC/bin:/usr/bin:/bin"
NM=$(command -v llvm-nm || command -v nm)
echo "NM=$NM"
OBJ=$WS/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837
echo
echo "== 内核里 umi_screen_* 定义 =="
"$NM" --format=posix --define-only $WS/out/umi-xnu/umi/kernel/source-kernel.macho 2>&1 | grep -i 'umi_screen\|boot_progress' | head
echo
echo "== 各 TU 是否未引用 umi_screen_text（应为 U=引用）=="
for o in osfmk/DEVELOPMENT/startup.o osfmk/DEVELOPMENT/arm_init.o \
         bsd/DEVELOPMENT/bsd_init.o bsd/DEVELOPMENT/kern_exec.o; do
  f=$OBJ/$o
  if [ -f "$f" ]; then
    printf '%-34s %s\n' "$o" "$("$NM" --format=posix "$f" 2>/dev/null | grep -c umi_screen_text)"
  else
    # 对象可能在子目录里，找一下
    f2=$(find "$OBJ" -name "$(basename $o)" 2>/dev/null | head -1)
    printf '%-34s %s (%s)\n' "$o" "$([ -n "$f2" ] && "$NM" --format=posix "$f2" 2>/dev/null | grep -c umi_screen_text || echo NOFILE)" "${f2:-none}"
  fi
done
echo
echo "== 找 bsd_init.o 的真实路径 =="
find $WS/out/umi-xnu/umi/tree/build -name 'bsd_init.o' 2>/dev/null | head -3
echo
echo "== 上一个内核 sha 对比（镜像里那份 FD 用的 source-kernel）=="
sha256sum $WS/out/umi-xnu/umi/kernel/source-kernel.macho
