#!/usr/bin/env python3
"""汇总仓库内各设备记录的挂根方案：只抽与 root/mockfs/apfs/storage 相关的短句。"""
import re
import subprocess
from pathlib import Path

MAIN = Path('/home/unixnu/code/UniXNU-main')
OUT = Path('/mnt/e/Code/HackIos/out/probes/devices-root-solutions.txt')
lines = []


def say(s):
    lines.append(s)


say('== 0. 设备目录与记录清单 ==')
devs = sorted(p.parent.name for p in MAIN.glob('devices/*/board.toml'))
say(f'board.toml 设备（{len(devs)}）: {", ".join(devs)}')
recs = sorted(p.stem for p in MAIN.glob('docs/.vitepress/device-records/*.toml'))
say(f'device-records（{len(recs)}）: {", ".join(recs)}')

say('')
say('== 1. 各设备 board.toml / defconfig 的挂根相关开关 ==')
KEY = re.compile(r'rd=|mockfs|MOCKFS|apfs|APFS|data_ramdisk|data-ramdisk|RAMDisk|IOStorageFamily|'
                 r'NativeUfs|native_ufs|NATIVE_UFS|Virtio|VIRTIO|AES|owner_root|OWNER_ROOT|'
                 r'archives|launchd|root_match_volume_uuid|VERIFIED_ROOT|SOURCE_STORAGE', re.I)
for d in devs:
    say(f'-- {d} --')
    for rel in ('board.toml',):
        f = MAIN / 'devices' / d / rel
        if f.is_file():
            hits = [ln.strip()[:160] for ln in f.read_text(errors='replace').splitlines() if KEY.search(ln)]
            for h in hits[:22]:
                say('  ' + h)
    cfg = MAIN / 'devices' / d / 'configs'
    if cfg.is_dir():
        for c in sorted(cfg.glob('*')):
            txt = c.read_text(errors='replace')
            hits = [ln.strip()[:120] for ln in txt.splitlines()
                    if re.search(r'MOCKFS|RAM_BLOCK|UFS|VIRTIO|AES|OWNER_ROOT|VERIFIED_ROOT|SOURCE_STORAGE', ln)]
            say(f'  [{c.name}] ' + ' | '.join(hits[:14]) if hits else f'  [{c.name}] (无存储开关)')

say('')
say('== 2. 设备记录里挂根/PID 1 相关结果句（每板最多 6 句）==')
PAT = re.compile(r'mockfs|md0|PID 1|pid 1|launchd|userland|userspace|root (mount|ed|device|volume)|'
                 r'mountroot|apfs|ramdisk|storage', re.I)
for p in sorted(MAIN.glob('docs/.vitepress/device-records/*.toml')):
    txt = p.read_text(errors='replace')
    got = []
    for m in re.finditer(r'^(\w+) = "(.*)"$', txt, re.M):
        key, val = m.group(1), m.group(2)
        if key in ('result', 'findings', 'next_action', 'limits', 'summary'):
            for s in re.split(r'(?<=[.")]),\s(?=")', val):
                if PAT.search(s) and len(s) < 700:
                    got.append(f'{key}: {s.strip()[:330]}')
    say(f'-- {p.stem} --')
    for g in got[:6]:
        say('  ' + g)
    if not got:
        say('  (无匹配句)')

OUT.write_text('\n'.join(lines) + '\n', encoding='utf-8')
subprocess.run(['wc', '-l', str(OUT)])
