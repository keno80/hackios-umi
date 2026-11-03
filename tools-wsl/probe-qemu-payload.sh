#!/bin/bash
cd /home/unixnu/code/umi-work-pin || exit 1
echo "=== QEMU esp 上的 boot 配置（run-06-root）==="
cat out/umi-qemu/run-06-root/esp/EFI/UniXNU/unixnu.toml 2>/dev/null
echo
echo "=== 该 run 的 ADT 报告 ==="
ls out/umi-qemu/run-06-root/esp/EFI/UniXNU/Payloads/ 2>/dev/null
find out/umi-qemu/run-06-root -maxdepth 2 -name "*.json" | head -12
echo
echo "=== 我们生成 QEMU payload 的脚本 ==="
grep -ln "esp/EFI/UniXNU\|make-umi-adt\|kernel.macho.adt" /mnt/e/Code/HackIos/tools-wsl/*.sh /mnt/e/Code/HackIos/tools-wsl/*.py 2>/dev/null | head -12
