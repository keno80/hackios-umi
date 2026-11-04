#!/bin/bash
# T 步之三之二：等 30z 内核编完 → 硬证据（反汇编里 amfi 空指针分支真的进了产物）→ QEMU 复测真件套 run-41-real。
set -u
exec > /mnt/e/Code/HackIos/out/probes/t24-wait-30z.txt 2>&1
OLD_SHA=bbfa957fc3aeed3dd8ec0e8c139d660da9d9c27ea1a1d32f3b8b0218bf2db9e6
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho
MARK=/tmp/walk-start-marker
IMG=/mnt/e/Code/HackIos/out/fixtures/root-real.macho
EXPECT_I=9c749e8d5d708bc637b15735452aa6a039b286ef1e3889af9f31a329dd1a2688
NAME=run-41-real
QLOG=/mnt/e/Code/HackIos/out/probes

echo "== 1. 等构建结束（最多 3600s）=="
P=$(cat "$LOGD/kernel-walk.pid" 2>/dev/null)
echo "pid=$P"
for i in $(seq 1 120); do
  kill -0 "$P" 2>/dev/null || { echo "BUILD-DONE after $((i*30))s"; break; }
  sleep 30
done
kill -0 "$P" 2>/dev/null && { echo "BUILD-STILL-RUNNING 放弃"; exit 1; }

echo
echo "== 2. 构建日志尾（去 ANSI）=="
sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' "$(cat "$LOGD/kernel-walk-latest.txt")" 2>/dev/null | tail -16

echo
echo "== 3. 产物新鲜度 =="
ls -la "$K"; sha256sum "$K"
[ "$K" -nt "$MARK" ] && echo "FRESH-OK" || echo "STALE-KERNEL-拒绝"
NEW_SHA=$(sha256sum "$K" | cut -c1-64)
[ "$NEW_SHA" = "$OLD_SHA" ] && { echo "SHA-UNCHANGED：30z 没进产物，拒绝跑"; exit 1; }
echo "NEW-SHA=$NEW_SHA"

echo
echo "== 4. 30z 硬证据：反汇编里 amfi 载入后要有空指针分支 =="
source /usr/local/bin/unixnu-env 2>/dev/null
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
NM=$TC/CommandLineTools/usr/bin/nm
A=$("$NM" "$K" 2>/dev/null | awk '/_accelerate_entitlement_queries$/{print $1}')
echo "addr=$A"
if [ -z "$A" ]; then echo "NO-SYMBOL（可能被内联，改看字符串）"; else
  "$TC/CommandLineTools/usr/bin/objdump" -d --start-address=0x$A --stop-address=$((0x$A + 0x60)) "$K" 2>/dev/null | tail -30
fi
echo "-- 判据：ldr x8,[x8,#0x228] 与 [x8,#0x1a0] 之间必须出现 cbz/cbnz/b.* --"
"$TC/CommandLineTools/usr/bin/objdump" -d --start-address=0x$A --stop-address=$((0x$A + 0x60)) "$K" 2>/dev/null \
  | awk '/0x228/{seen=1} seen && /0x1a0/{print "GUARD-OK(先分支后解引用?)"; exit} seen && /cbz|cbnz|b\.(eq|ne)/{print "HIT "$0; exit}'

echo
echo "== 5. 输入身份 =="
sha256sum "$IMG"
[ "$(sha256sum "$IMG" | cut -c1-64)" = "$EXPECT_I" ] || { echo "拒绝：容器不是真件套"; exit 1; }
python3 - "$IMG" <<'PY'
import struct, sys
d = open(sys.argv[1], 'rb').read()
m, v, c, la, ls, ta, ts = struct.unpack_from('<8sII4Q', d)
print(f'{m} v{v} n{c} launch={la}+{ls} test={ta}+{ts} bytes={len(d)}')
assert (m, v, c, la) == (b'N4KROOT\0', 1, 2, 4096)
print('HEADER-OK')
PY

echo
echo "== 6. 跑 QEMU =="
RUN=/home/unixnu/code/umi-work-pin/out/umi-qemu/$NAME
[ -e "$RUN" ] && rm -rf "$RUN"
cd /mnt/e/Code/HackIos || exit 1
setsid nohup bash tools-wsl/run-umi-qemu.sh "$NAME" \
  --mockfs-initrd "$IMG" \
  --args "-v keepsyms=1 kt_fixed_zones=120" \
  --capture-screen --timeout 240 > "$QLOG/qemu-$NAME.launch.log" 2>&1 &
echo "launcher pid=$!"

echo
echo "== 7. 等退出（最多 1200s）=="
for i in $(seq 1 240); do
  grep -q 'run_umi_qemu exit=' "$QLOG/qemu-$NAME.launch.log" 2>/dev/null && { echo "DONE after $((i*5))s"; break; }
  sleep 5
done
tail -3 "$QLOG/qemu-$NAME.launch.log"

echo
echo "== 8. 取回屏与现场 =="
cp "$RUN/screen.png" /mnt/e/Code/HackIos/out/screens/qemu-$NAME.png 2>/dev/null && \
  sha256sum /mnt/e/Code/HackIos/out/screens/qemu-$NAME.png || echo NO-SCREEN
cp "$RUN/gdb-stop.json" "$QLOG/$NAME-gdb-stop.json" 2>/dev/null && echo "copied json" || echo NO-JSON
echo "== done $(date -u +%FT%TZ)"
