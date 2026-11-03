#!/usr/bin/env python3
import hashlib
import json
import os
import subprocess

OUT = open('/mnt/e/Code/HackIos/out/kernel-check.txt', 'w')
WS = '/home/unixnu/code/umi-work-pin'
KER = WS + '/out/umi-xnu/umi/kernel/source-kernel.macho'


def w(*a):
    print(*a, file=OUT)


st = json.load(open(WS + '/out/umi-xnu/umi/source-build-status.json'))
w('stage=%s success=%s steps=%s' % (st['stage'], st['success'], [(s['name'], s['exit_code']) for s in st['steps']]))
w('kernel=%s bytes=%s sha=%s' % (st['kernel'], st['bytes'], st['sha256']))
w('log=%s' % st['log_directory'])
data = open(KER, 'rb').read()
w('file sha=%s bytes=%d mtime=%d' % (hashlib.sha256(data).hexdigest(), len(data), os.path.getmtime(KER)))
for needle in (b'UMI SCREEN fb=', b'UMI PANIC ', b'UMI ', b'UMI .. '):
    w('  literal %-18r count=%d' % (needle, data.count(needle)))
nm = subprocess.run(['nm', KER], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
w('nm rc=%d' % nm.returncode)
for line in nm.stdout.decode(errors='replace').splitlines():
    if 'umi_screen' in line or 'umi_scr' in line:
        w('  ', line)
OUT.close()
