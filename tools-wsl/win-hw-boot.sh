#!/bin/bash
set -u
ADB=/e/platform-tools/adb.exe
FB=/e/platform-tools/fastboot.exe
IMG='E:\Code\HackIos\out\umi-uefi-menu-xnu.img'
LOG=/e/Code/HackIos/out/hw-boot.log
: > "$LOG"
say() { echo "$(date +%H:%M:%S) $*" >> "$LOG"; }

say "== 1. 等 adb 授权（最多 120 秒）"
st=""
for i in $(seq 1 60); do
  st=$("$ADB" get-state 2>/dev/null | tr -d '\r' | tail -1)
  if [ "$st" = "device" ]; then say "adb 已授权"; break; fi
  sleep 2
done
if [ "$st" != "device" ]; then say "FAIL 仍未授权，退出"; exit 1; fi

say "== 2. adb reboot bootloader"
"$ADB" reboot bootloader >> "$LOG" 2>&1
say "rc=$?"
ok=""
for i in $(seq 1 60); do
  d=$("$FB" devices 2>/dev/null | tr -d '\r' | head -1)
  if [ -n "$d" ]; then say "fastboot 在线: $d"; ok=1; break; fi
  sleep 2
done
if [ -z "$ok" ]; then say "FAIL 120 秒内没进 fastboot"; exit 1; fi

say "== 3. fastboot boot（只加载内存，不写任何分区）"
"$FB" boot "$IMG" >> "$LOG" 2>&1
say "rc=$?"

say "== 4. 之后 60 秒 USB 变化观察"
for i in $(seq 1 30); do
  f=$("$FB" devices 2>/dev/null | tr -d '\r' | head -1)
  a=$("$ADB" devices 2>/dev/null | tr -d '\r' | tail -1)
  say "  fastboot=[$f] adb=[$a]"
  sleep 2
done
say DONE
