"""让 tools/prepare_umi_root.py 在非 macOS 上也能取原始盘块。

它原来直连 hdiutil attach + /dev/rdisk 读盘；这里换成 upstream 已移植好的
userdata.disk_blocks()（macOS 走 hdiutil，其他主机走 udif.py 解 UDIF）。
gzip 压缩缓存分支与全部哈希/来源校验保持原样。
"""
import re
import sys
from pathlib import Path

TARGET = Path("/home/unixnu/code/umi-work-pin/tools/prepare_umi_root.py")

IMPORT_OLD = "from unixnu.userdata import attach,image_size"
IMPORT_NEW = "from unixnu.userdata import disk_blocks,image_size"

HELPER_ANCHOR = "def hash_window(path,offset,size):"
HELPER = '''class BlockReader:
    """把 disk_blocks 的块流包成 read(n) 流，沿用下面的拷贝循环。"""

    def __init__(self, blocks):
        self.blocks, self.buf, self.exhausted = iter(blocks), b"", False

    def read(self, n):
        while len(self.buf) < n and not self.exhausted:
            try:
                self.buf += next(self.blocks)
            except StopIteration:
                self.exhausted = True
        out, self.buf = self.buf[:n], self.buf[n:]
        return out

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


'''

ATTACH_OLD = """            device=None if raw_input else attach(dmg)
            digest=hashlib.sha256()
            try:
                handle=gzip.open(dmg,"rb") if raw_input else open(device.replace("/dev/disk","/dev/rdisk"),"rb",buffering=0)"""

ATTACH_NEW = """            digest=hashlib.sha256()
            try:
                handle=gzip.open(dmg,"rb") if raw_input else BlockReader(disk_blocks(dmg, raw_bytes))"""

DETACH_OLD = """            finally:
                if device: subprocess.run(["hdiutil","detach",device],check=True)"""
DETACH_NEW = """            finally:
                pass"""

MARK = "class BlockReader:"


def apply(text, old, new, label, done_marker):
    if done_marker in text:
        print(f"skip  {label}（已打过）")
        return text
    if text.count(old) != 1:
        sys.exit(f"anchor lost: {label} ({text.count(old)} hits)")
    print(f"patch {label}")
    return text.replace(old, new)


text = TARGET.read_text()
text = apply(text, IMPORT_OLD, IMPORT_NEW, "imports", "import disk_blocks")
text = apply(text, HELPER_ANCHOR, HELPER + HELPER_ANCHOR, "BlockReader", MARK)
text = apply(text, ATTACH_OLD, ATTACH_NEW, "attach -> disk_blocks", "BlockReader(disk_blocks(dmg, raw_bytes))")
text = apply(text, DETACH_OLD, DETACH_NEW, "detach 收尾", "            finally:\n                pass")
compile(text, str(TARGET), "exec")
TARGET.write_text(text)
print("OK 语法通过")
