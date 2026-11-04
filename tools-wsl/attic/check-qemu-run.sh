#!/bin/bash
# QEMU 前置检查：xcrun nm 可用、内核无手机 RAM-console 符号、_Assert 在不在
export PATH=/opt/unixnu-linux/CommandLineTools/usr/bin:/opt/unixnu-linux/bin:/usr/local/bin:$PATH
W=/home/unixnu/code/umi-work-pin
K=$W/out/umi-xnu/umi/kernel/source-kernel.macho
echo "xcrun=$(command -v xcrun)"
echo "内核=$K size=$(stat -c%s "$K" 2>/dev/null)"
echo "nm 行数=$(xcrun nm -n "$K" 2>/dev/null | wc -l)"
echo "nm 头三行:"
xcrun nm -n "$K" 2>&1 | head -3
echo "手机 trace 符号数（必须 0）=$(xcrun nm -n "$K" 2>/dev/null | grep -c -E '_umi_early_trace|_umi_trace_console_address')"
echo "_Assert =$(xcrun nm -n "$K" 2>/dev/null | grep -w '_Assert' | head -1)"
for s in _kernel_boot_init _arm_init _main; do
  echo "$s -> $(xcrun nm -n "$K" 2>/dev/null | grep -w "$s" | head -1)"
done
echo "=== 观察脚本依赖 ==="
grep -n "argparse\|def main\|qemu-system-aarch64\|pflash\|QEMU_EFI\|AAVMF\|gdb" \
  "$W/sources/UniXNU/scripts/qemu-entry/gdb-stop.py" 2>/dev/null | head -14
ls -l "$W/sources/UniXNU/scripts/qemu-entry/" 2>/dev/null | head -8
echo "=== gdb 可用 ==="
command -v gdb-multiarch aarch64-linux-gnu-gdb lldb 2>/dev/null
