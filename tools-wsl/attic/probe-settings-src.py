#!/usr/bin/env python3
import subprocess

OUT = open('/mnt/e/Code/HackIos/out/probes/settings-src.txt', 'w')
BS = '/home/unixnu/code/umi-work-pin/tools/build_umi_xnu.py'


def w(*a):
    print(*a, file=OUT)


w('== build_umi_xnu.py lines 1..180 ==')
w(''.join(open(BS).readlines()[:180]))
OUT.close()
