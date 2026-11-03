#!/bin/bash
set -u
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/boot-order2.txt
{
  echo "== ConfigureIOKit callers =="
  grep -rn 'ConfigureIOKit' "$W" --include=*.c --include=*.cpp --include=*.h 2>/dev/null | head
  echo "== STARTUP_SUB_EARLY_BOOT references =="
  grep -rn 'STARTUP_SUB_EARLY_BOOT' "$W" --include=*.c --include=*.cpp --include=*.h 2>/dev/null | head -20
  echo "== startup.c public API =="
  grep -n '^[a-z].*(\|void$\|EXPORT' "$W/osfmk/kern/startup.c" | head -40
  echo "== startup.c stage invocation functions =="
  grep -n 'startup_module_init\|startup_invoke\|kernel_boot_init' "$W/osfmk/kern/startup.c" "$W/osfmk/kern/startup.h" | head -30
  echo "== bootstrap file location =="
  ls "$W/osfmk/kern/" | grep -i boot
  echo "== bootstrap.c ordering of iokit + startup =="
  grep -n 'ConfigureIOKit\|StartIOKitMatching\|IOStartIOKit\|startup_module_init\|kernel_boot_init\|machine_lockdown\|bsd_init' "$W/osfmk/kern/bootstrap.c" | head -40
} > "$O" 2>&1
echo done
