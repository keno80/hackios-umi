#!/usr/bin/env python3
import glob
import os
import re
import subprocess

OUT = open('/mnt/e/Code/HackIos/out/syms.txt', 'w')
W = '/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work'


def w(*a):
    print(*a, file=OUT)


def grep(pattern, paths, limit=12):
    cmd = ['grep', '-rn', '-E', pattern] + paths
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL, timeout=180).decode(errors='replace')
    except subprocess.CalledProcessError as exc:
        out = exc.output.decode(errors='replace')
    lines = out.splitlines()[:limit]
    for line in lines:
        w('  ', line[:220])
    if not lines:
        w('   (no match)')


w('== ml_io_map_unmappable declarations ==')
grep(r'ml_io_map_unmappable\s*\(', [W + '/osfmk', W + '/EXTERNAL_HEADERS'], 10)
w('== VM_WIMG_IO define ==')
grep(r'#define\s+VM_WIMG_IO', [W + '/osfmk', W + '/EXTERNAL_HEADERS'], 5)
w('== kernel_map declaration ==')
grep(r'extern\s+vm_map_t\s+kernel_map|vm_map_t\s+kernel_map;', [W + '/osfmk/vm', W + '/EXTERNAL_HEADERS'], 6)
w('== video_console.c includes ==')
w('\n'.join(l.rstrip() for l in open(W + '/osfmk/console/video_console.c').readlines()[:120] if l.startswith('#include') or l.startswith('#if')))
w('== does video_console.c already reference PE_state / ml_io_map? ==')
grep(r'PE_state|ml_io_map', [W + '/osfmk/console/video_console.c'], 8)
w('== iso_font / ISO_CHAR in video_console ==')
grep(r'ISO_CHAR_WIDTH|iso_font', [W + '/osfmk/console/video_console.c'], 8)
OUT.close()
