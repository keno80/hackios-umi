#!/usr/bin/env python3
"""给本机实际在跑的 run_umi_qemu.py 再加一段观测件替换：把单发大 'm' 包改成分段读。

为什么动这一件：本机 QEMU 8.2.2 的 gdbstub 对单发 'm' 请求按 (4096-16)/2 ≈ 2040 字节设限，
超了就回 E22。上游 scripts/qemu-entry/gdb-stop.py 的 --read-memory 处理把应答原样存进
report['memory']，于是官方 tools/analyze_umi_systemos_qemu.py 第 59 行读 2382 字节的
_exit_records 时拿到的是字符串 "E22"，bytes.fromhex 直接 ValueError——观测面明明在，
只是取它的包太大了。

改法沿上游自己的规矩：它在 saved-register 采集里就用「页边界 + 每次最多 512 字节」的分段循环
（gdb-stop.py:1389-1396）。这里把同一惯用法接到 --read-memory 上，拼回原键，长度不变的短读
产出与改动前逐字节相同。上游观测件本体一字不改（run_umi_qemu.py 一直在给它打窗口补丁，
本段只多加一条同风格的替换）；判读件也不改。

用法：make-run-umi-qemu-chunked-read.py [--runner PATH] [--restore]
"""
import argparse
import hashlib
import sys
from pathlib import Path

DEFAULT_RUNNER = Path("/home/unixnu/code/umi-work-pin/tools/run_umi_qemu.py")
MARKER = "UMI_CHUNKED_MEMORY_READ"
ANCHOR = '        gdb_script = out / "gdb-stop-root-window.py"\n'

PATCH_BLOCK = r'''        # UMI_CHUNKED_MEMORY_READ: local QEMU 8.2.2 answers E22 for one 'm' packet
        # over its gdbstub limit, and the upstream observer stored that reply as if
        # it were memory. Fetch the same bytes with the page-bounded 512-byte chunk
        # loop upstream already uses for saved-register captures (gdb-stop.py:1389).
        # Reads a single packet can carry keep their original byte-identical value.
        before = "            report['memory'] = {}\n"
        assert content.count(before) == 1
        content = content.replace(before, before + "            report['memory_read_errors'] = {}\n")
        before = "                report['memory'][request] = packet(f'm{address:x},{length:x}')\n"
        assert content.count(before) == 1
        content = content.replace(before,
            "                have = 0\n"
            "                chunks = []\n"
            "                while have < length:\n"
            "                    cursor = address + have\n"
            "                    count = min(512, length - have, 4096 - (cursor & 4095))\n"
            "                    chunk = packet(f'm{cursor:x},{count:x}')\n"
            "                    if chunk.startswith('E') or len(chunk) != count * 2:\n"
            "                        report['memory_read_errors'][request] = dict(address=hex(cursor), reply=chunk)\n"
            "                        break\n"
            "                    chunks.append(chunk)\n"
            "                    have += count\n"
            "                report['memory'][request] = ''.join(chunks)\n")
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runner", type=Path, default=DEFAULT_RUNNER,
                        help="本机真正被执行的那份 run_umi_qemu.py")
    parser.add_argument("--restore", action="store_true",
                        help="撤掉本段替换，回到未打补丁的原件")
    args = parser.parse_args()

    original = args.runner.read_text()
    before_sha = hashlib.sha256(args.runner.read_bytes()).hexdigest()

    if args.restore:
        if MARKER not in original:
            print(f"runner={args.runner} 本来就没打过本段补丁，无需撤")
            return 0
        start = original.index("        # " + MARKER)
        end = original.index(ANCHOR, start)
        content = original[:start] + original[end:]
    elif MARKER in original:
        print(f"runner={args.runner} 已应用 sha256={before_sha}")
        return 0
    else:
        if original.count(ANCHOR) != 1:
            raise SystemExit(f"锚点 {ANCHOR.strip()} 在 {args.runner} 里命中 {original.count(ANCHOR)} 次，停手")
        content = original.replace(ANCHOR, PATCH_BLOCK + ANCHOR, 1)

    compile(content, str(args.runner), "exec")
    args.runner.write_text(content)
    action = "已撤销" if args.restore else "已应用"
    print(f"runner={args.runner} {action} sha256 {before_sha[:16]} -> "
          f"{hashlib.sha256(args.runner.read_bytes()).hexdigest()[:16]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
