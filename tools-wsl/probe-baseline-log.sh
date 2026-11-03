#!/bin/bash
cd /home/unixnu/code/umi-work-pin || exit 1
U=/home/unixnu/code/uefi-umi-b
echo "=== umiPkg Application 清单 ==="
ls $U/Platforms/Xiaomi/umiPkg/Application/ 2>/dev/null
echo
echo "=== out/umi 基线文件 ==="
ls -la out/umi/*.json 2>/dev/null | head -20
for f in out/umi/xnu-source-baseline.json out/umi/adt-baseline.json; do
  echo "--- $f"; [ -f "$f" ] && head -c 600 "$f" || echo MISSING; echo
done
echo "=== ramoops 基址/格式 ==="
grep -rn "amoops\|RamConsole\|ramconsole\|pstore" $U/Platforms/Xiaomi/umiPkg/ sources/UniXNU/drivers/DarwinBoot/ tools/prepare_umi_uefi.py tools/decode_umi_xnu_trace.py 2>/dev/null | grep -v "^Binary" | head -25
