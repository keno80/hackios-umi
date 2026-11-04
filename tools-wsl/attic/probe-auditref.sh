#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
UP=/home/unixnu/code/UniXNU-pin
OUT=/mnt/e/Code/HackIos/out/probes/auditref-probe.txt
{
  echo "== 仓里有没有随附的 interface-audit / static-audit json"
  find /home/unixnu/code /mnt/e/Code/HackIos -name '*interface-audit*' -o -name '*static-audit*' 2>/dev/null | head -20
  echo
  echo "== 有没有随附的 xnu-entry/attempt-* 归档"
  find /home/unixnu/code /mnt/e/Code/HackIos -maxdepth 6 -type d -name 'xnu-entry' -o -maxdepth 6 -type d -name 'attempt-*' 2>/dev/null | head -10
  echo
  echo "== 引用 qemu-storage-apfs.macho 的地方"
  grep -rn "qemu-storage-apfs" "$WS/tools" "$WS/docs" 2>/dev/null | head -15
  echo
  echo "== 有没有取参照二进制/归档的脚本（fetch/download/provenance）"
  ls "$WS/tools" | head -60
  echo
  echo "== 文档里提到 candidate / Hello / 参考内核 的段落"
  grep -rln "audit_umi_storage\|interface-audit\|attempt-55" "$WS" --include='*.md' 2>/dev/null | head -10
  echo
  echo "== umi 设备仓 README 里的构建顺序"
  grep -n "build_umi\|audit_umi\|--native-ufs\|--owner-root" "$WS/README.md" 2>/dev/null | head -40
  echo
  echo "== 所有 umi 文档清单"
  find "$WS" -maxdepth 3 -name '*.md' 2>/dev/null | head -20
  echo
  echo "== upstream（非 umi 设备）的 build-native-virtio-bindings.py 可选缓存逻辑"
  grep -n "interface-audit\|kernel_path.exists\|optional" "$UP/scripts/build-native-virtio-bindings.py" 2>/dev/null | head -20
  echo
  echo "== NativeVirtioBlock / NativeAES kit 是否走内核内建（Kconfig）"
  grep -rn "NATIVE_VIRTIO_BLOCK\|NATIVE_AES\|OWNER_ROOT" "$UP" --include='Kconfig*' 2>/dev/null | head -20
  find "$UP" -name 'Kconfig*' 2>/dev/null | head -10
} > "$OUT" 2>&1
echo WROTE
