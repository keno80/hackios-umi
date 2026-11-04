#!/bin/bash
# U 步之三：owner-root 档在 QEMU 里只读挂真 APFS 根并取 18 字段观测
# 用法：run-owner-root-qemu <audit|trust> [run 名，默认按官方档名 33-/34-]
# 前置：先跑 run-kernel-owner-root.sh <mode> 出源内核，再跑 run-umi-prelink qemu-owner-root-<mode>
set -u
MODE=${1:-audit}
case "$MODE" in
  audit) NAME=${2:-33-owner-root-audit} ;;
  trust) NAME=${2:-34-owner-root-trust} ;;
  *) echo "mode 只认 audit|trust"; exit 1 ;;
esac
WS=/home/unixnu/code/umi-work-pin
K=$WS/out/umi-xnu/umi/kernel/qemu-owner-root-$MODE.macho
LOG=/mnt/e/Code/HackIos/out/probes/owner-root-$MODE-qemu.log
exec > >(tee "$LOG") 2>&1

[ -f "$K" ] || { echo "缺 prelink 产物：$K（先跑 run-umi-prelink qemu-owner-root-$MODE）"; exit 1; }
echo "== 内核 $K"
sha256sum "$K"
echo "== run 名 $NAME（run_umi_qemu 拒绝覆盖已存在档，重跑请换名）"

tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/run-umi-qemu.sh > /tmp/run-umi-qemu.sh
cd "$WS" || exit 1
# audit 停在 refusal panic；trust 停在 accepted checkpoint 并要求真实函数返回
# （官方 harness 的 function_return_stack_matched / function_entry_arguments 只在 --finish-function 下产出）
# 符号名要带 Mach-O 前导下划线：run_umi_qemu 的 symbol() 直接吃 nm 的第 3 列
if [ "$MODE" = audit ]; then
  STOP=(--stop _panic)
else
  STOP=(--stop _native_owner_root_accepted_checkpoint --finish)
fi
KERNEL=out/umi-xnu/umi/kernel/qemu-owner-root-$MODE.macho \
  bash /tmp/run-umi-qemu.sh "$NAME" \
  --root-volume --no-vmm-property --owned-memory-mib 320 \
  "${STOP[@]}" \
  --timeout 480 --capture-screen \
  --args "-v keepsyms=1 kt_fixed_zones=120 offline-apfs-load=1" \
  --read-symbol _umi_owner_root_observation:0x90 \
  --read-symbol _native_aes_kat_status:4 \
  --read-symbol _native_aes_registered:4 \
  --read-symbol _native_aes_interface_status:4 \
  --read-symbol _native_virtio_verified_blocks:8 \
  --read-symbol _native_virtio_integrity_failures:4 \
  --read-symbol _native_verified_block_root_uuid:37
echo "run_umi_qemu exit=$?"

tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/evaluate-owner-root-evidence.py > /tmp/ev.py
# 判读件要跑 xcrun nm，得用我们工具链里的 cctools
export PATH=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}/CommandLineTools/usr/bin:${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}/bin:/usr/local/bin:/usr/bin:/bin
export LC_ALL=C
python3 /tmp/ev.py "$NAME" "$MODE"
echo "evaluate exit=$?"
