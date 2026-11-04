#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
LOG=/mnt/e/Code/HackIos/out/probes/xnu-console.txt
{
  echo "== 1. DarwinBoot 里的 stdout-path / chosen / console"
  grep -rn -E 'stdout|chosen|console|serial' "$WS/sources/UniXNU/drivers/DarwinBoot/DarwinBootPkg/Driver/DarwinBoot.c" | head -20
  echo "== 2. make-umi-adt.py 写出的 chosen 节点"
  grep -rn -E 'stdout|serial|console|framebuffer' "$WS/devices/umi/scripts/"*.py | head -20
  echo "== 3. umi 文档里关于日志/串口/panic 的说法"
  grep -rn -i -E 'uart|serial|console|panic|ramoops|log' "$WS/devices/umi/docs/"*.md | head -25
  echo "== 4. XNU 树里有没有 framebuffer/simple-framebuffer 控制台驱动"
  ls "$WS/sources/UniXNU/drivers" 2>/dev/null | head -30
  grep -rln -i 'simple-framebuffer\|SimpleFramebuffer' "$WS/sources/UniXNU" 2>/dev/null | head -10
} > "$LOG" 2>&1
