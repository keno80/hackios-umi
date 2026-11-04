#!/bin/bash
cd /home/unixnu/code/umi-work-pin || exit 1
echo "=== unixnu-memory.toml（菜单条目语法）==="
cat devices/umi/package/unixnu-memory.toml
echo
echo "=== RamoopsSerialPortLib.c 头部与格式 ==="
sed -n '1,60p' /home/unixnu/code/uefi-umi-b/Platforms/Xiaomi/umiPkg/Library/RamoopsSerialPortLib/RamoopsSerialPortLib.c
echo
echo "=== 本机 running.dtb: msm-id / cpu opp / mpdm ==="
dtc -I dtb -O dts out/umi/dtb/umi-running.dtb 2>/dev/null | grep -E "msm-id|qcom,board-id|reg = <0x[0-9a-f]* 0x[0-9a-f]*>;$" | head -0
dtc -I dtb -O dts out/umi/dtb/umi-running.dtb 2>/dev/null | awk '/^[ \t]*cpu@[0-9]/{p=1} p{print} p&&/};/{p=0}' | grep -E "cpu@|reg =" | head -20
dtc -I dtb -O dts out/umi/dtb/umi-running.dtb 2>/dev/null | grep -m3 -E "msm-id|board-id"
