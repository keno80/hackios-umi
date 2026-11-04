#!/bin/bash
# 摸清上游 boot-progress 套件：谁把 XNU_BOOT_PROGRESS 置 1、bind 能不能绑我们的 FB。
set -u
OUT=/mnt/e/Code/HackIos/out/f-upstream-kit.txt
: > "$OUT"
exec >>"$OUT" 2>&1
echo "== kits/umi/boot-progress 目录 =="
ls -la /home/unixnu/code/UniXNU-main/kits/umi/boot-progress/ 2>&1 | head -40
echo
echo "== devices/umi/package/boot-progress 目录 =="
ls -la /home/unixnu/code/UniXNU-main/devices/umi/package/boot-progress/ 2>&1 | head -40
echo
echo "== build-boot-progress.py 全文 =="
cat /home/unixnu/code/UniXNU-main/scripts/build-boot-progress.py 2>&1 | head -120
echo
echo "== XNU_BOOT_PROGRESS 由谁定义（构建侧，非 patch/树内源码）=="
grep -rn "XNU_BOOT_PROGRESS" /home/unixnu/code/UniXNU-main/scripts/ \
  /home/unixnu/code/UniXNU-main/kits/ 2>/dev/null | grep -v "\.patch" | head -40
echo
echo "== boot-progress= boot-arg 的读取方 =="
grep -rn "boot-progress" /home/unixnu/code/UniXNU-main/scripts/ \
  /home/unixnu/code/UniXNU-main/kits/ 2>/dev/null | head -40
