#!/bin/bash
echo "=== pgrep qemu/python drivers ==="
pgrep -fa "run_umi_qemu|qemu-system-aarch64|run-umi-qemu" | head -5
echo "=== launch log ==="
L=/home/unixnu/code/UniXNU-main/out/unixnu-logs/qemu-run-07-screen.launch.log
ls -la "$L" 2>/dev/null
tail -25 "$L" 2>/dev/null
echo "=== cmdline of python procs ==="
for p in $(pgrep -f python3); do
  printf "%s %s\n" "$p" "$(tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null | cut -c1-160)"
done
