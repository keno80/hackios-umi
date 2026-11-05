#!/usr/bin/env python3
"""给本机实际在跑的 run_umi_qemu.py 再加一段观测件替换：放开注册表串通道的事件预算。

为什么动这一件：上游 scripts/qemu-entry/gdb-stop.py 的 --registry-string-log-address
每吃一次 IORegistryEntry::setProperty(cc,cc) 就重挂一次硬件断点，但重挂条件写死了
「事件数 < 128」（原件 611 行），结束标记同样按 == 128 算（原件 1250 行）。48 档实测
事件条数正好 128、registry_string_log_exhausted=true，最后一发 UUID 属性发布停在
12.959 秒——于是「我们的 Data 卷一条属性都没发布」这条判据还不能用：它可能只是被
预算掐在了后面。

改法只抬这两个字面量，观测件的采样、字段、异常路径一字不动；help 文案里那句
「at most 128」一起抬，免得 run 目录里的观测件副本自相矛盾。
判读件：tools-wsl/evaluate-data-registry-evidence.py

用法：make-run-umi-qemu-registry-budget.py [--runner PATH] [--events N] [--restore]
"""
import argparse
import hashlib
import re
import sys
from pathlib import Path

DEFAULT_RUNNER = Path("/home/unixnu/code/umi-work-pin/tools/run_umi_qemu.py")
MARKER = "UMI_REGISTRY_STRING_BUDGET"
ANCHOR = '        gdb_script = out / "gdb-stop-root-window.py"\n'

GUARDS = ("len(registry_string_events) < 128",
          "len(registry_string_events) == 128",
          "Observe at most 128 real IORegistryEntry")


def block(events: int) -> str:
    """插进 run_umi_qemu.py 的那段替换指令（在它自己的 content 变量上操作）。"""
    lines = [
        f"        # {MARKER}: upstream only re-arms the registry-string breakpoint while",
        "        # its own event list stays under 128, so a boot that publishes more media",
        "        # than that silently truncates the publication list. Raise the arming",
        "        # guard and the matching exhausted flag together; sampling, fields and",
        "        # error paths stay exactly as upstream wrote them.",
    ]
    for guard in GUARDS:
        value = guard.replace("128", str(events))
        lines += [
            f'        before = "{guard}"',
            "        assert content.count(before) == 1",
            f'        content = content.replace(before, "{value}")',
        ]
    lines.append(f"        # {MARKER}_END")
    return "\n".join(lines) + "\n"


def strip(text: str) -> str:
    start = text.index("        # " + MARKER + ":")
    end = text.index("        # " + MARKER + "_END\n", start) + len("        # " + MARKER + "_END\n")
    return text[:start] + text[end:]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runner", type=Path, default=DEFAULT_RUNNER,
                        help="本机真正被执行的那份 run_umi_qemu.py")
    parser.add_argument("--events", type=int, default=4096,
                        help="注册表串事件预算（上游原件写死 128）")
    parser.add_argument("--restore", action="store_true",
                        help="撤掉本段替换，回到未打补丁的原件")
    args = parser.parse_args()

    original = args.runner.read_text()
    before_sha = hashlib.sha256(args.runner.read_bytes()).hexdigest()
    baked = None
    if MARKER in original:
        found = re.search(r"len\(registry_string_events\) < (\d+)", original)
        baked = int(found.group(1)) if found else None
        if baked == args.events and not args.restore:
            print(f"runner={args.runner} 已应用 events={baked} sha256={before_sha}")
            return 0
        original = strip(original)

    if args.restore:
        if baked is None:
            print(f"runner={args.runner} 本来就没打过本段补丁，无需撤")
            return 0
        content = original
        action = f"已撤销 events={baked}"
    else:
        if ANCHOR not in original:
            raise SystemExit(f"锚点 {ANCHOR.strip()} 不在 {args.runner} 里，停手")
        content = original.replace(ANCHOR, block(args.events) + ANCHOR, 1)
        action = f"已应用 events={args.events}"

    compile(content, str(args.runner), "exec")
    args.runner.write_text(content)
    print(f"runner={args.runner} {action} sha256 {before_sha[:16]} -> "
          f"{hashlib.sha256(args.runner.read_bytes()).hexdigest()[:16]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
