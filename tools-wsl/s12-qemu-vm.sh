#!/bin/bash
# S 步 QEMU 自测：内核不重编（29z 的 mach 去重表覆盖 0..127，新号 -10/-12/-14/-21 天然有探针），
# 只换件。判据口径：屏上应多出 4 对负号 IN/OUT——
#   svc=-10 vm_allocate、svc=-14 vm_protect、svc=-21 port_insert_right、svc=-12 vm_deallocate。
# run-32-vm 已实测：三发 vm 面全回 0（说明 vm_map 在 EL0 真能用，且出参 _vmaddr 能读回），
# 但 -21 回 0xf=KERN_INVALID_NAME（本树 kern_return.h:143）——查出来是件的用法错：
# poly 传了 0（MACH_PORT_NULL），标准写法是 poly=name 本身。本轮（run-33-vm）就是改完这一发的复测：
# -21 若回 0，同时反证 R 步 -19/-18 的 0x11=KERN_INVALID_RIGHT 是 mod_refs 加不出 send right，
# 而不是内核 IPC 通道坏了。
# run-33-vm 实测（17:47）：-10/-14/-21/-12 四发全回 0，上面这条反证成立。
# 注意 _nz 基址随 _walk 扩容挪到了 0x100004180，读地址必须跟着改，否则读回全 0 是采样错了窗口。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s12-qemu-vm.txt 2>&1
NAME=run-33-vm
WS=/home/unixnu/code/umi-work-pin/out/umi-qemu
LOGD=/mnt/e/Code/HackIos/out/probes
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho
IMG=/mnt/e/Code/HackIos/out/fixtures/launchd-walk.macho
EXPECT_K=bbfa957fc3aeed3dd8ec0e8c139d660da9d9c27ea1a1d32f3b8b0218bf2db9e6
EXPECT_I=ee0fda866c47cf2192e4e768016cc592340f398fe57ee1e26f61c1822341bb5c
source /usr/local/bin/unixnu-env 2>/dev/null
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
NM=$TC/CommandLineTools/usr/bin/nm

echo "== 1. 输入身份 =="
sha256sum "$K" "$IMG"
[ "$(sha256sum "$K" | cut -c1-64)" = "$EXPECT_K" ] || { echo "拒绝：内核不是 29z 那份"; exit 1; }
[ "$(sha256sum "$IMG" | cut -c1-64)" = "$EXPECT_I" ] || { echo "拒绝：件不是 S 版那份"; exit 1; }
echo "IDENTITY-OK"

echo
echo "== 2. 内核侧探针仍在（nm 查函数内静态表，strings 看不见）=="
MS=$("$NM" "$K" 2>/dev/null | grep -c 'umi_el0_mach_seen')
MO=$("$NM" "$K" 2>/dev/null | grep -c 'umi_el0_mach_out_seen')
echo "mach_seen=$MS mach_out_seen=$MO（都>=1 才放行）"
[ "$MS" -ge 1 ] && [ "$MO" -ge 1 ] || { echo "拒绝：内核没有 mach 去重表"; exit 1; }

echo
echo "== 3. 件侧 S 段硬证据 =="
W2=$(strings -a "$IMG" | grep -c -F 'UMI-WALK-S-VM-PAYLOAD')
echo "S标记=$W2"
[ "$W2" -ge 1 ] || { echo "拒绝：件不是 S 版（没有 S 标记串）"; exit 1; }

echo
echo "== 4. 跑 QEMU（读 _walk 0x100004040:320 与 _nz 0x100004180:320）=="
RUN=$WS/$NAME
[ -e "$RUN" ] && rm -rf "$RUN"
cd /mnt/e/Code/HackIos || exit 1
setsid nohup bash tools-wsl/run-umi-qemu.sh "$NAME" \
  --mockfs-initrd "$IMG" \
  --args "-v keepsyms=1 kt_fixed_zones=120" \
  --read-user-address 100004040:320 \
  --read-user-address 100004180:320 \
  --capture-screen --timeout 170 \
  > "$LOGD/qemu-$NAME.launch.log" 2>&1 &
echo "launcher pid=$!"

echo
echo "== 5. 等退出（最多 900s）=="
for i in $(seq 1 180); do
  grep -q 'run_umi_qemu exit=' "$LOGD/qemu-$NAME.launch.log" 2>/dev/null && { echo "DONE after $((i*5))s"; break; }
  sleep 5
done
tail -3 "$LOGD/qemu-$NAME.launch.log"

echo
echo "== 6. 取回屏与现场 =="
cp "$RUN/screen.png" /mnt/e/Code/HackIos/out/screens/qemu-$NAME.png 2>/dev/null && \
  sha256sum /mnt/e/Code/HackIos/out/screens/qemu-$NAME.png || echo NO-SCREEN
cp "$RUN/gdb-stop.json" "/mnt/e/Code/HackIos/out/probes/$NAME-gdb-stop.json" 2>/dev/null && \
  echo "copied $NAME-gdb-stop.json" || echo NO-JSON-COPY
echo "== done $(date -u +%FT%TZ)"
