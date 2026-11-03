#!/bin/bash
cd /home/unixnu/code/umi-work-pin || exit 1
echo "=== umi-hardware.json 全文 ==="
cat devices/umi/package/umi-hardware.json
echo
echo "=== umi_adt.py 里 memory/cpus/chosen 的构造 ==="
grep -n "memory_banks\|def build_tree" -A 4 devices/umi/scripts/umi_adt.py | head -40
echo
echo "--- dram_size 用法 ---"
grep -n "dram_size\|owned_memory_size\|memory-map\|/memory" devices/umi/scripts/umi_adt.py | head -25
