#!/bin/bash
# T 步之二：QEMU 自测「真 Apple 件假根」档，归因第一道闸。
# 判读口径：
#   INIT try /sbin/launchd → exec ok / returned 的走向，加上 EL0 IN/OUT 是否出现，
#   把「CS/AMFI 拒签」「dyld 装载失败」「真 launchd 跑起来了」三种结果分开。
# 内核沿用 29z 那份（未重编）：EL0 逐号探针与 mach 去重表都在内核侧，换件不用重编。
set -u
exec > /mnt/e/Code/HackIos/out/probes/t10-qemu-real.txt 2>&1
NAME=run-40-real
WS=/home/unixnu/code/umi-work-pin/out/umi-qemu
LOGD=/mnt/e/Code/HackIos/out/probes
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho
IMG=/mnt/e/Code/HackIos/out/fixtures/root-real.macho
EXPECT_K=bbfa957fc3aeed3dd8ec0e8c139d660da9d9c27ea1a1d32f3b8b0218bf2db9e6
EXPECT_I=9c749e8d5d708bc637b15735452aa6a039b286ef1e3889af9f31a329dd1a2688

echo "== 1. 输入身份 =="
sha256sum "$K" "$IMG"
[ "$(sha256sum "$K" | cut -c1-64)" = "$EXPECT_K" ] || { echo "拒绝：内核不是 29z 那份"; exit 1; }
[ "$(sha256sum "$IMG" | cut -c1-64)" = "$EXPECT_I" ] || { echo "拒绝：容器不是本轮真件套"; exit 1; }
echo "IDENTITY-OK"

echo
echo "== 2. 容器头自检（与内核 N4KROOT 闸同口径）=="
python3 - "$IMG" <<'PY'
import struct, sys
d = open(sys.argv[1], 'rb').read()
magic, ver, cnt, la, ls, ta, ts = struct.unpack_from('<8sII4Q', d)
print(f'{magic} v{ver} n{cnt} launch={la}+{ls} test={ta}+{ts} bytes={len(d)}')
assert (magic, ver, cnt, la) == (b'N4KROOT\0', 1, 2, 4096)
assert len(d) <= 32 << 20 and not ta & 4095 and ta >= 8192
assert ls <= ta - la and ts <= len(d) - ta
assert d[la:la + ls][:4] == b'\xcf\xfa\xed\xfe' and d[ta:ta + ts][:4] == b'\xcf\xfa\xed\xfe'
print('HEADER-OK')
PY

echo
echo "== 3. 跑 QEMU =="
RUN=$WS/$NAME
[ -e "$RUN" ] && rm -rf "$RUN"
cd /mnt/e/Code/HackIos || exit 1
setsid nohup bash tools-wsl/run-umi-qemu.sh "$NAME" \
  --mockfs-initrd "$IMG" \
  --args "-v keepsyms=1 kt_fixed_zones=120" \
  --capture-screen --timeout 240 \
  > "$LOGD/qemu-$NAME.launch.log" 2>&1 &
echo "launcher pid=$!"

echo
echo "== 4. 等退出（最多 1200s）=="
for i in $(seq 1 240); do
  grep -q 'run_umi_qemu exit=' "$LOGD/qemu-$NAME.launch.log" 2>/dev/null && { echo "DONE after $((i*5))s"; break; }
  sleep 5
done
tail -3 "$LOGD/qemu-$NAME.launch.log"

echo
echo "== 5. 取回屏与现场 =="
cp "$RUN/screen.png" /mnt/e/Code/HackIos/out/screens/qemu-$NAME.png 2>/dev/null && \
  sha256sum /mnt/e/Code/HackIos/out/screens/qemu-$NAME.png || echo NO-SCREEN
cp "$RUN/gdb-stop.json" "/mnt/e/Code/HackIos/out/probes/$NAME-gdb-stop.json" 2>/dev/null && \
  echo "copied $NAME-gdb-stop.json" || echo NO-JSON-COPY
echo "== done $(date -u +%FT%TZ)"
