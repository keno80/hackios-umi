#!/bin/bash
# 在你 Windows 桌面上开一个真实的 QEMU 图形窗口（WSLg + SDL），
# 直接跑上一次验证过的 ESP（UniXNU.efi 菜单 + DarwinBoot + source-kernel.macho），不带调试器停点。
set -u
export DISPLAY=${DISPLAY:-:0}
W=/home/unixnu/code/umi-work-pin
SRC=$W/out/umi-qemu/run-02-screen/esp
LIVE=$W/out/umi-qemu/live
UART=/mnt/e/Code/HackIos/out/qemu-live-uart.log
CODE=/usr/share/qemu/edk2-aarch64-code.fd
VARS_T=/usr/share/AAVMF/AAVMF_VARS.fd
[ -d "$SRC" ] || { echo "没有已验证的 ESP：$SRC"; exit 1; }
rm -rf "$LIVE"
mkdir -p "$LIVE"
cp -a "$SRC" "$LIVE/esp"
cp "$VARS_T" "$LIVE/vars.fd"
: > "$UART" 2>/dev/null || UART=$LIVE/uart.log
setsid nohup qemu-system-aarch64 \
  -M virt,virtualization=off,secure=off,gic-version=3 \
  -accel tcg -cpu cortex-a710 -m 1024 -smp 1 \
  -display sdl,show-cursor=yes \
  -device ramfb \
  -serial "file:$UART" \
  -monitor none -nic none \
  -qmp "unix:$LIVE/qmp.sock,server=on,wait=off" \
  -drive if=pflash,format=raw,readonly=on,file=$CODE \
  -drive if=pflash,format=raw,file=$LIVE/vars.fd \
  -drive if=none,id=esp,format=raw,readonly=on,file=fat:$LIVE/esp \
  -device virtio-blk-pci,drive=esp > "$LIVE/qemu.out" 2>&1 &
echo $! > "$LIVE/qemu.pid"
sleep 3
pid=$(cat "$LIVE/qemu.pid")
kill -0 "$pid" 2>/dev/null && echo "QEMU 窗口已起 pid=$pid（SDL，标题一般是 QEMU；内核 panic 后会自动重启回菜单，窗口不关）" || { echo "QEMU 立即退出"; cat "$LIVE/qemu.out"; exit 1; }
qemu-system-aarch64 --version | head -1
