#!/bin/bash
set -u
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/probes/startup-stages.txt
{
  echo "== startup subystem enum =="
  sed -n '55,110p' "$W/osfmk/kern/startup.h" | cat -n
  echo "== where stages are invoked =="
  grep -rn 'startup_invoke_stage_functions\|STARTUP_FUNCTION_STAGE' "$W/osfmk" "$W/bsd" "$W/iokit" 2>/dev/null | grep -v '\.h:' | head -30
  echo "== kmem_crypto_init body =="
  sed -n '2555,2600p' "$W/osfmk/vm/vm_kern.c" | cat -n
  echo "== configureDefaults call site =="
  grep -rn 'configureDefaults' "$W/iokit/Kernel"/*.cpp "$W/pexpert" 2>/dev/null | head -10
  echo "== generatePlatformUUID =="
  grep -rn -A25 'generatePlatformUUID' "$W/iokit/Kernel/IOPlatformExpert.cpp" | head -60
} > "$O" 2>&1
echo done
