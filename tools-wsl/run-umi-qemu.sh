#!/bin/bash
# 用作者自己的 run_umi_qemu.py 在通用 UEFI/TGC 下验证源码内核基线
# 用法：run-umi-qemu <run 名> [额外参数...]
set -u
NAME=${1:-run-01}
shift || true
WS=/home/unixnu/code/umi-work-pin
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
export PATH="$TC/CommandLineTools/usr/bin:$TC/bin:/usr/local/bin:/usr/bin:/bin"
export LC_ALL=C
cd "$WS" || exit 1
K=${KERNEL:-out/umi-xnu/umi/kernel/source-kernel.macho}
OUT=out/umi-qemu/$NAME
if [ -e "$OUT" ]; then echo "$OUT 已存在（脚本拒绝覆盖），换个名字"; exit 1; fi
mkdir -p "$(dirname "$OUT")"
LOG=/home/unixnu/code/UniXNU-main/out/unixnu-logs/qemu-$NAME.log
echo "== $K sha256=$(sha256sum "$K" | cut -c1-16)  ->  $OUT"
python3 -u tools/run_umi_qemu.py --kernel "$K" --out "$OUT" \
  --accel tcg --stop _Assert --owned-memory-mib 256 --timeout 90 "$@" > "$LOG" 2>&1
echo "run_umi_qemu exit=$?"
tail -5 "$LOG"
echo "-- 证据 --"
ls -l "$OUT" 2>/dev/null | head -12
for f in gdb-stop.json gdb-failure.json; do
  [ -f "$OUT/$f" ] && { echo "== $f (前 60 行)"; head -60 "$OUT/$f"; }
done
[ -f "$OUT/gdb-uart.log" ] && { echo "== uart 尾部"; tail -20 "$OUT/gdb-uart.log"; }
