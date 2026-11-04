#!/bin/bash
# 反汇编 _IOFindBSDRoot 尾部，看 +0xc88 断言引用了哪条字符串
export PATH=/opt/unixnu-linux/CommandLineTools/usr/bin:/opt/unixnu-linux/bin:/usr/local/bin:/usr/bin:/bin
export LC_ALL=C
python3 /mnt/e/Code/HackIos/tools-wsl/probe_ioroot.py > /mnt/e/Code/HackIos/out/probes/ioroot-probe.txt 2>&1
echo WROTE
