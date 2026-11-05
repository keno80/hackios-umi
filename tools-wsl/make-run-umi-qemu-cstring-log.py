#!/usr/bin/env python3
"""给本机实际在跑的 run_umi_qemu.py 加一个 --log-cstrings 转发口。

为什么缺这一口：上游观测件 scripts/qemu-entry/gdb-stop.py 本来就实现了「被调件第一个参数是
内核 C 串」的采集（--cstring-log-address，定义在 :49、装断点在 :478 附近、事件处理在 :614-632），
事件带 handler/caller/argument/stack_bytes/value/elapsed_seconds——caller 是 x30，所以一次跑就能
知道**是哪个函数打了哪句日志**。本机的 run_umi_qemu.py 没把这口往下传，只有注册表那口传了
（make-run-umi-qemu-registry-log.py 补的）。

这一口对当前问题的价值：未改动的 com.apple.filesystems.apfs 里，nx_mount 的每一个失败分支在
往 w25 填错误码之前都先调 0x5688250 这句日志跳板（apfs_log 变参件，x0 原样透传给 0x576949c），
所以「容器为什么不被认领」在原版驱动自己的日志串里是有明话的，比猜错误码号表更直接。

址由调用方给（donor kext 里的裸址没有内核符号，走不了 symbol()），本仓不写死判据；
观测件本体一字不改（run_umi_qemu.py 本来就一直在替换它），判读件也不改。

注意风险：上游在 x0 < 0xfffffff000000000 时直接 raise RuntimeError 中止整档（:615-616），
所以只能挂在「第一个参数恒为格式串」的跳板上，挂之前要按反汇编核过所有调用点的 x0 来路。

用法：make-run-umi-qemu-cstring-log.py [--runner PATH] [--restore]
"""
import argparse
import hashlib
import sys
from pathlib import Path

DEFAULT_RUNNER = Path("/home/unixnu/code/umi-work-pin/tools/run_umi_qemu.py")
MARKER = "UMI_CSTRING_LOG"
ANCHOR_ARG = ('    p.add_argument("--stop-address", help="explicit component instruction '
              'address instead of a native symbol")\n')
ANCHOR_CMD = '    if a.accel == "tcg":\n        command.append("--system-registers")\n'

BLOCK_ARG = (
    '    # UMI_CSTRING_LOG: expose the upstream C-string call observer. Addresses are\n'
    '    # supplied by the caller because donor-kext handlers have no kernel symbol.\n'
    '    p.add_argument("--log-cstrings", action="append", default=[], metavar="ADDRESS",\n'
    '                   help="observe kernel C-string first arguments at this handler address")\n'
)
BLOCK_CMD = (
    '    # UMI_CSTRING_LOG: arm the upstream cstring observer on each handler address.\n'
    '    for _umi_cstring in a.log_cstrings:\n'
    '        command += ["--cstring-log-address", hex(int(_umi_cstring, 0))]\n'
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runner", type=Path, default=DEFAULT_RUNNER,
                        help="本机真正被执行的那份 run_umi_qemu.py")
    parser.add_argument("--restore", action="store_true",
                        help="撤掉本段转发，回到未打补丁的原件")
    args = parser.parse_args()

    original = args.runner.read_text()
    before_sha = hashlib.sha256(args.runner.read_bytes()).hexdigest()
    applied = MARKER in original

    if args.restore:
        if not applied:
            print(f"runner={args.runner} 本来就没打过本段补丁，无需撤")
            return 0
        content = original
        for block in (BLOCK_ARG, BLOCK_CMD):
            if content.count(block) != 1:
                raise SystemExit(f"撤销时补丁块命中 {content.count(block)} 次，停手（别是被人手改过？）")
            content = content.replace(block, "", 1)
    elif applied:
        print(f"runner={args.runner} 已应用 sha256={before_sha}")
        return 0
    else:
        content = original
        for anchor, block in ((ANCHOR_ARG, BLOCK_ARG), (ANCHOR_CMD, BLOCK_CMD)):
            if content.count(anchor) != 1:
                raise SystemExit(f"锚点 {anchor.strip()!r} 在 {args.runner} 里命中 "
                                 f"{content.count(anchor)} 次，停手")
            content = content.replace(anchor, anchor + block, 1)

    compile(content, str(args.runner), "exec")
    args.runner.write_text(content)
    action = "已撤销" if args.restore else "已应用"
    print(f"runner={args.runner} {action} sha256 {before_sha[:16]} -> "
          f"{hashlib.sha256(args.runner.read_bytes()).hexdigest()[:16]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
