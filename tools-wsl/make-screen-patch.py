#!/usr/bin/env python3
"""Export the on-screen boot-log edits as a umi-xnu patch file."""
import difflib
import os
import subprocess
import sys

NL = chr(10)
WORK = '/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work'
PATCHDIR = '/home/unixnu/code/umi-work-pin/devices/umi/patches/umi-xnu'
PATCH = os.path.join(PATCHDIR, 'zzzzzzzzzzzzzzzzz-umi-screen.patch')
MINE = '/home/unixnu/umi-screen-patch/mine'
BASE = '/home/unixnu/umi-screen-patch/base'

FILES = ['osfmk/console/video_console.c', 'osfmk/arm/arm_init.c',
         'osfmk/kern/startup.c', 'osfmk/kern/debug.c']

EXTERN_MARK = 'extern void umi_screen_mark(unsigned long phase, unsigned long value);'
EXTERN_TEXT = 'extern void umi_screen_text(const char *s);'
EXTERN_HALT = 'extern void umi_screen_halt(const char *s);'
ENDIF_OSX = '#endif /* defined(XNU_TARGET_OS_OSX) */'


def read(path):
    with open(path, newline='') as handle:
        return handle.read().splitlines(keepends=True)


def strip_lines(rel, lines):
    """Return the pre-edit version of lines, asserting every removal is ours."""
    if rel.endswith('video_console.c'):
        assert lines[3311].rstrip() == ENDIF_OSX, repr(lines[3311])
        assert lines[3312].startswith('#define UMI_SCR_SCALE_MAX'), repr(lines[3312])
        return lines[:3312], len(lines) - 3312

    drop = set()
    for index, line in enumerate(lines):
        text = line.strip()
        if text in (EXTERN_MARK, EXTERN_TEXT, EXTERN_HALT):
            drop.add(index)
        elif text.startswith('umi_screen_mark(0x') or text.startswith('umi_screen_text(message);'):
            drop.add(index)
    if rel.endswith('debug.c'):
        hit = [i for i, l in enumerate(lines) if 'umi_screen_halt(umi_panic_line);' in l]
        assert len(hit) == 1, hit
        start, end = hit[0] - 13, hit[0] + 1
        assert lines[start].strip() == '{', repr(lines[start])
        assert lines[end].strip() == '}', repr(lines[end])
        drop.update(range(start, end + 1))
    expected = {'osfmk/arm/arm_init.c': 15, 'osfmk/kern/startup.c': 4, 'osfmk/kern/debug.c': 16}[rel]
    assert len(drop) == expected, (rel, len(drop), expected)
    return [l for i, l in enumerate(lines) if i not in drop], len(drop)


def main():
    os.makedirs(MINE, exist_ok=True)
    os.makedirs(BASE, exist_ok=True)
    chunks = []
    for rel in FILES:
        mine_path = os.path.join(MINE, rel.replace('/', '_'))
        base_path = os.path.join(BASE, rel.replace('/', '_'))
        lines = read(os.path.join(WORK, rel))
        with open(mine_path, 'w', newline='') as handle:
            handle.writelines(lines)
        base, removed = strip_lines(rel, lines)
        with open(base_path, 'w', newline='') as handle:
            handle.writelines(base)
        diff = difflib.unified_diff(base, lines, fromfile='a/' + rel, tofile='b/' + rel, n=3, lineterm=NL)
        body = [d if d.endswith(NL) else d + NL for d in diff]
        assert any(d.startswith('@@') for d in body), rel
        chunks.extend(body)
        print('%s: %d lines removed, %d patch lines' % (rel, removed, len(body)))

    with open(PATCH, 'w', newline='') as handle:
        handle.writelines(chunks)
    print('wrote', PATCH, os.path.getsize(PATCH), 'bytes')

    check = subprocess.run(['git', '-C', WORK, 'apply', '--reverse', '--check', PATCH],
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    print('reverse-check rc=%d %s' % (check.returncode, check.stdout.decode().strip()))
    return 0 if check.returncode == 0 else 1


sys.exit(main())
