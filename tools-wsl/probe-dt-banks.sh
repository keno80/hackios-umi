#!/bin/bash
cd /home/unixnu/code/umi-work-pin || exit 1
D=out/umi/dtb/umi-running.dtb
echo "sha256: $(sha256sum $D | cut -c1-64)"
echo "=== /memory 节点 ==="
dtc -I dtb -O dts "$D" 2>/dev/null | grep -E "memory@[0-9a-f]+ \{" -A 2 | head -20
echo "=== cpu 节点 affinity ==="
dtc -I dtb -O dts "$D" 2>/dev/null | grep -E "cpu@[0-9a-f]+ \{" -A 3 | grep -E "cpu@|reg = " | head -20
echo "=== msm-id / board-id ==="
dtc -I dtb -O dts "$D" 2>/dev/null | grep -E "msm-id|qcom,board-id" | head -4
echo "=== 本机 cpu 数（/proc 对照）==="
grep -c processor /proc/cpuinfo 2>/dev/null
