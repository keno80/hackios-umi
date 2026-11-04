#!/usr/bin/env python3
import glob
import os
import subprocess

OUT = open('/mnt/e/Code/HackIos/out/probes/build-progress.txt', 'w')
LOGD = '/home/unixnu/code/UniXNU-main/out/unixnu-logs'
WS = '/home/unixnu/code/umi-work-pin'


def w(*a):
    print(*a, file=OUT)


latest = open(os.path.join(LOGD, 'kernel-screen-latest.txt')).read().strip()
pid = open(os.path.join(LOGD, 'kernel-screen.pid')).read().strip()
alive = os.path.exists('/proc/%s' % pid)
w('log=%s pid=%s alive=%s size=%d' % (latest, pid, alive, os.path.getsize(latest)))
lines = open(latest, errors='replace').read().splitlines()
w('---- first 12 ----')
for l in lines[:12]:
    w('  ', l[:200])
w('---- last 25 ----')
for l in lines[-25:]:
    w('  ', l[:200])

logs = sorted(glob.glob(WS + '/out/umi-xnu/umi/logs/*'), key=os.path.getmtime)
if logs:
    d = logs[-1]
    w('---- newest step dir', d)
    for f in sorted(os.listdir(d)):
        p = os.path.join(d, f)
        w('    %-46s %10d' % (f, os.path.getsize(p)))
    k = os.path.join(d, 'kernel.log')
    if os.path.exists(k):
        w('---- kernel.log last 30 ----')
        for l in open(k, errors='replace').read().splitlines()[-30:]:
            w('  ', l[:200])
OUT.close()
