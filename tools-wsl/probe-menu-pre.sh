#!/bin/bash
# #10 前置核对（只读）：证据目录 / prepare 档案 / FD 窗口冲突 / 工具是否齐
WS=/home/unixnu/code/umi-work-pin
{
echo "== 证据目录（采集件）在哪"
ls -d $WS/out/umi/evidence* $WS/out/evidence* $WS/out/umi-capture* 2>/dev/null | head
find $WS/out -maxdepth 3 -name 'report.json' 2>/dev/null | head -5
find $WS/out -maxdepth 4 -name 'running.dtb' 2>/dev/null | head -3

echo "== prepare.json 档案"
cat $WS/out/umi/prepare.json 2>&1 | head -30

echo "== sources/uefi-umi 指向与 FD 是否可见"
ls -ld $WS/sources/uefi-umi
ls -l $WS/sources/uefi-umi/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd 2>&1 | tail -1

echo "== 工具齐不齐"
for t in fdtoverlay dtc clang lld llvm-objcopy fastboot; do printf "  %-12s %s\n" "$t" "$(command -v $t || echo MISSING)"; done
ls $WS/out/venv-umi/bin 2>/dev/null | head -5

echo "== 实机 DT 里 0x9c000000~0xa0000000 段的 reserved-memory"
python3 - <<'PYEOF' 2>&1 | head -40
import glob, struct, subprocess
paths = glob.glob("/home/unixnu/code/umi-work-pin/out/**/running.dtb", recursive=True) + glob.glob("/mnt/e/Code/HackIos/**/running.dtb", recursive=True)
print("候选 dtb:", paths[:3])
if not paths:
    raise SystemExit("没找到 running.dtb")
data = open(paths[0], "rb").read()
print("size", len(data), "magic", hex(struct.unpack_from(">I", data, 0)[0]))
PYEOF

echo "== 采集包里有没有 iomem/meminfo"
ls /mnt/e/Code/HackIos/phone-capture/ 2>&1 | head -10
} > /mnt/e/Code/HackIos/out/menu-pre.txt 2>&1
echo WROTE
