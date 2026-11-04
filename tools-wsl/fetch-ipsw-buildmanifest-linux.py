#!/usr/bin/env python3
"""Fetch only BuildManifest.plist from the pinned remote IPSW with HTTP range reads.

prepare_umi_trustcache.py reads that member from the local cache folder, so this is the one input
Linux lacks; nothing else is downloaded. The manifest must match the pin in devices/umi/ipsw-inputs.json.
"""
import hashlib
import json
import plistlib
import sys
import tomllib
import zipfile
from pathlib import Path

ROOT = Path('/home/unixnu/code/umi-work-pin')
sys.path.insert(0, str(ROOT / 'sources/UniXNU/scripts'))
from unixnu.ipsw import RangeFile  # noqa: E402  (upstream range reader, no whole-image download)

FOLDER = ROOT / 'out/umi-xnu/ipsw/21H461'
MANIFEST = FOLDER / 'BuildManifest.plist'


def main():
    board = tomllib.loads((ROOT / 'devices/umi/board.toml').read_text())
    ipsw = board['ipsw']
    pinned = json.loads((ROOT / 'devices/umi/ipsw-inputs.json').read_text())['manifest_sha256']
    if MANIFEST.is_file():
        got = hashlib.sha256(MANIFEST.read_bytes()).hexdigest()
        if got == pinned:
            print(f'已存在且与 pin 相同，跳过下载：{got}')
            return 0
        raise SystemExit(f'本地 BuildManifest.plist 与 pin 不符：{got} != {pinned}')
    stream = RangeFile(ipsw['url'])
    data = zipfile.ZipFile(stream).read('BuildManifest.plist')
    got = hashlib.sha256(data).hexdigest()
    if got != pinned:
        raise SystemExit(f'远端 BuildManifest.plist 与 pin 不符：{got} != {pinned}')
    manifest = plistlib.loads(data)
    build = manifest['ProductBuildVersion']
    classes = sorted({i['Info']['DeviceClass'] for i in manifest['BuildIdentities']})
    if build != ipsw['build']:
        raise SystemExit(f'Build {build} != {ipsw["build"]}')
    FOLDER.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_bytes(data)
    (FOLDER / 'BuildManifest.plist.json').write_text(json.dumps({
        'member': 'BuildManifest.plist', 'bytes': len(data), 'sha256': got,
        'source': 'remote', 'url': ipsw['url'], 'pin': pinned,
        'build': build, 'identity_classes': classes}, indent=2) + '\n')
    print(f'取到 BuildManifest.plist {len(data)} bytes sha256={got} build={build} classes={classes}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
