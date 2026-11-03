"""把 upstream main 的 Linux 解 UDIF 通路移植进 pinned 树。

只做 Linux 支持，不引入 main 的 manifest v2 / --object / AEA：
pinned 树的 prepare_umi_root.py 与 run_umi_qemu.py 认的是 v1（windows-only）清单。
幂等：锚点缺失即报错，已打过则跳过。
"""
import shutil
import re
import sys
from pathlib import Path

W = Path("/home/unixnu/code/umi-work-pin")
PKG = W / "sources/UniXNU/scripts/unixnu"
UPSTREAM_MAIN = Path("/home/unixnu/code/UniXNU-main/scripts/unixnu")
TARGET = PKG / "userdata.py"
UTIL = PKG / "util.py"

IMPORTS_OLD = """import hashlib
import json
import plistlib
import re
import struct
import subprocess

from .ipsw import Ipsw"""

IMPORTS_NEW = """import contextlib
import hashlib
import json
import platform
import plistlib
import re
import struct
import subprocess

from . import udif
from .ipsw import Ipsw"""

SIZE_OLD = """def image_size(dmg):
    info = subprocess.run(['hdiutil', 'imageinfo', '-plist', str(dmg)], capture_output=True, check=True).stdout"""

SIZE_NEW = """def image_size(dmg):
    if platform.system() != 'Darwin':
        return udif.Image(dmg).size
    info = subprocess.run(['hdiutil', 'imageinfo', '-plist', str(dmg)], capture_output=True, check=True).stdout"""

TOOL_OLD = "\n    tool('hdiutil', 'the disk images are attached with macOS hdiutil')"
TOOL_NEW = "\n    if platform.system() == 'Darwin':\n        tool('hdiutil', 'the disk images are attached with macOS hdiutil')"

BLOCKS_ANCHOR = "def build(ctx, dry_run=False):"
BLOCKS_FUNC = '''def disk_blocks(dmg, size):
    """The raw disk of a disk image, in order: hdiutil's /dev/rdiskN on macOS, udif.py on other hosts."""
    if platform.system() != 'Darwin':
        yield from udif.Image(dmg).blocks()
        return
    device = attach(dmg)
    try:
        raw = device.replace('/dev/disk', '/dev/rdisk')
        done = 0
        with open(raw, 'rb', buffering=0) as handle:
            while done < size:
                want = min(CHUNK, size - done)
                data = handle.read(want)
                if len(data) != want:
                    raise Error(f'short read from {raw} at {done}')
                yield data
                done += want
    finally:
        subprocess.run(['hdiutil', 'detach', device], capture_output=True)


'''

COPY_OLD = """            device = attach(dmg)
            try:
                raw = device.replace('/dev/disk', '/dev/rdisk')
                digest = hashlib.sha256()
                target.seek(offset)
                done = 0
                with open(raw, 'rb', buffering=0) as handle:
                    while done < size:
                        want = min(CHUNK, size - done)
                        data = handle.read(want)
                        if len(data) != want:
                            raise Error(f'short read from {raw} at {done}')
                        digest.update(data)
                        target.write(data)
                        done += want
            finally:
                subprocess.run(['hdiutil', 'detach', device], capture_output=True)"""

COPY_NEW = """            digest = hashlib.sha256()
            target.seek(offset)
            done = 0
            with contextlib.closing(disk_blocks(dmg, size)) as blocks:
                for data in blocks:
                    digest.update(data)
                    target.write(data)
                    done += len(data)
            if done != size:
                raise Error(f'{dmg.name}: {done} bytes of raw disk, expected {size}')"""

# util.py：main 用 lzfse() 找工具链里的 Apple 参考 LZFSE 解码器
LZFSE_ANCHOR = "\ndef run(command, *, cwd=None, env=None, log_file=None, capture=False):"
LZFSE_FUNC = '''

def lzfse():
    """Apple's reference LZFSE tool, which decodes LZFSE on Linux: in the scripts/linux/setup-toolchain.py prefix, else on PATH."""
    path = Path(os.environ.get('UNIXNU_TOOLCHAIN', '/opt/unixnu-linux')) / 'bin/lzfse'
    return str(path) if path.is_file() else tool('lzfse', 'run sudo scripts/linux/setup-toolchain.py')

'''


def apply(text, old, new, label, done_marker):
    if done_marker in text:
        print(f"skip  {label}（已打过）")
        return text
    if text.count(old) != 1:
        sys.exit(f"anchor lost: {label} ({text.count(old)} hits)")
    print(f"patch {label}")
    return text.replace(old, new)


def patch_udif():
    if not (PKG / "udif.py").is_file():
        shutil.copyfile(UPSTREAM_MAIN / "udif.py", PKG / "udif.py")
        print("install udif.py")


def patch_util():
    text = UTIL.read_text()
    if "def lzfse(" in text:
        print("skip  util.lzfse（已就位）")
        return
    if "\ndef run(" not in text:
        sys.exit("anchor lost: util.run")
    if re.search(r"^import os$", text, re.M) is None:
        text = text.replace("import hashlib", "import hashlib\nimport os", 1)
    if re.search(r"^from pathlib import Path$", text, re.M) is None:
        text = re.sub(r"\n\n", "\nfrom pathlib import Path\n", text, count=1)
    idx = text.index("\ndef run(")
    text = text[:idx] + LZFSE_FUNC.rstrip("\n") + "\n" + text[idx:]
    compile(text, str(UTIL), "exec")
    UTIL.write_text(text)
    print("patch util.lzfse")


def main():
    patch_udif()
    patch_util()
    text = TARGET.read_text()
    text = apply(text, IMPORTS_OLD, IMPORTS_NEW, "imports", "from . import udif")
    text = apply(text, SIZE_OLD, SIZE_NEW, "image_size", "udif.Image(dmg).size")
    text = apply(text, TOOL_OLD, TOOL_NEW, "hdiutil gate", "        tool('hdiutil'")
    text = apply(text, BLOCKS_ANCHOR, BLOCKS_FUNC + BLOCKS_ANCHOR, "disk_blocks", "def disk_blocks(dmg, size):")
    text = apply(text, COPY_OLD, COPY_NEW, "copy loop", "contextlib.closing(disk_blocks")
    compile(text, str(TARGET), "exec")
    TARGET.write_text(text)
    print("OK 语法通过")


main()
