#!/bin/bash
# Characterise the DTB blobs unpacked from the umi capture.
set -u
cd /mnt/e/Code/HackIos/out/phone3/dt || exit 1
out=/mnt/e/Code/HackIos/out/probes/phone3-dt.txt
: > "$out"
for f in boot-dtb dtbo-0 dtbo-8 dtbo-14 running; do
  dtc -I dtb -O dts "$f.dtb" -o "$f.dts" 2>/dev/null
  {
    echo "== $f  dtb=$(stat -c %s "$f.dtb")  dts_lines=$(wc -l < "$f.dts")"
    echo "   fragments=$(grep -c 'fragment {' "$f.dts")  __symbols__=$(grep -c '__symbols__' "$f.dts")"
    echo "   model=$(grep -m1 'model = ' "$f.dts" | cut -c1-90)"
    echo "   board-id=$(grep -m1 'qcom,board-id' "$f.dts" | cut -c1-90)"
    echo "   board-name=$(grep -m1 'qcom,msm-id' "$f.dts" | cut -c1-90)"
    echo "   panel=$(grep -o 'qcom,mdss_dsi_j2[a-z0-9_]*' "$f.dts" | sort -u | head -2 | tr '\n' ' ')"
    echo "   reserved=$(grep -c 'reserved-memory' "$f.dts")"
  } >> "$out" 2>&1
done
dtc -I dtb -O dts boot-dtb.dtb -o /tmp/b.dts 2>/dev/null
dtc -I dtb -O dts dtbo-8.dtb -o /tmp/o8.dts 2>/dev/null
{
  echo
  echo '=== boot-dtb 根属性'
  awk '/^\/ \{/,/^\tmemory/' /tmp/b.dts | head -20
  echo
  echo '=== dtbo-8 顶层结构（前 24 行）'
  head -24 /tmp/o8.dts
} >> "$out" 2>&1
echo done >> "$out"
