#!/bin/bash
# G 步：用 trace 档内核 + 新读日志 App 重打真机镜像（FD 保持上机验证过的那份）
set -u
LOG=/mnt/e/Code/HackIos/out/probes/repack-trace.txt
: > "$LOG"
exec >>"$LOG" 2>&1
INITRD=/home/unixnu/code/UniXNU-main/build/native-user-fixture-umi/launchd.macho
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/entry-trace-kernel.macho
echo "== 0. 输入指纹 =="
sha256sum "$K"
sha256sum /home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
ls -la "$INITRD"
echo
echo "== 1. payload 卷 =="
python3 /mnt/e/Code/HackIos/tools-wsl/build-xnu-payload.py \
  --kernel "$K" --title "Mi 10 8G - TRACE" --mockfs-initrd "$INITRD"
echo "payload rc=$?"
echo
echo "== 2. bootimg + 自检 + 交付"
bash /mnt/e/Code/HackIos/tools-wsl/pack-menu-xnu.sh
echo "pack rc=$?"
echo
echo "== 3. 把 trace 档产物改名交付（不留同字节的两份让人猜哪个是新的）=="
XNU=/mnt/e/Code/HackIos/out/images/umi-uefi-menu-xnu.img
TRACE=/mnt/e/Code/HackIos/out/images/umi-uefi-menu-trace.img
if [ -f "$XNU" ] && [ "$XNU" -nt "$K" ]; then
  mv -f "$XNU" "$TRACE"
  ls -l "$TRACE" | sed 's#^# #'
  sha256sum "$TRACE" | sed 's#^# #'
else
  echo "== 跳过：$XNU 不存在或不比内核新（本轮自检未过，别把上一轮的镜像当新的）"
fi
echo "== done =="
