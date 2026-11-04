#!/bin/bash
# 看 build_umi_xnu.py 的产物命名与 owner-root 相关步骤（200..360）
cd /home/unixnu/code/umi-work-pin || exit 1
sed -n '200,360p' tools/build_umi_xnu.py > /mnt/e/Code/HackIos/out/probes/build-xnu-naming.txt 2>&1
echo WROTE
