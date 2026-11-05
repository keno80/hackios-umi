#!/usr/bin/env python3
"""给本机实际在跑的 run_umi_qemu.py 加一个 --log-registry-strings 转发口。

为什么缺这一口：上游观测件 scripts/qemu-entry/gdb-stop.py 本来就实现了 IOKit 注册表字符串
属性的采集（--registry-string-log-address，定义在 :52、装断点在 :478、事件处理在 :597-612），
上游自己的资格化件也靠它判「原版 APFS 到底把哪个卷 UUID 发给了注册表、由谁发的」——
check-native-virtio-checkpoints.py:89-96 用事件的 caller 落在 com.apple.filesystems.apfs 的
__TEXT_EXEC extent 内来证明是未改动的原版 APFS 发的，check-original-apfs-root-checkpoints.py:51-54
再按 entry（=x0，那个 IORegistryEntry）归组，读出同一对象的 Status=Online / Sealed / BSD Name /
FullName。本机的 run_umi_qemu.py 没有把这个开关往下传，所以 47 档的 registry_string_events 是空表。

址不写死在本仓里：照上游 probe-darwinboot-xnu.py:672 的做法，从待测内核的符号现算
__ZN15IORegistryEntry11setPropertyEPKcS1_（47 档实测 fffffff00bef089c）。观测件本体一字不改
（run_umi_qemu.py 本来就一直在替换它），判读件也不改。

用法：make-run-umi-qemu-registry-log.py [--runner PATH] [--restore]
"""
import argparse
import hashlib
import sys
from pathlib import Path

DEFAULT_RUNNER = Path("/home/unixnu/code/umi-work-pin/tools/run_umi_qemu.py")
MARKER = "UMI_REGISTRY_STRING_LOG"
ANCHOR_ARG = ('    p.add_argument("--stop-address", help="explicit component instruction '
              'address instead of a native symbol")\n')
ANCHOR_CMD = '    if a.accel == "tcg":\n        command.append("--system-registers")\n'
REGISTRY_SYMBOL = "__ZN15IORegistryEntry11setPropertyEPKcS1_"

BLOCK_ARG = (
    '    # UMI_REGISTRY_STRING_LOG: hand the observer channel this guest already\n'
    '    # supports to the caller. The address is resolved from the kernel under test,\n'
    '    # the same way upstream\'s probe-darwinboot-xnu.py does, so no address is\n'
    '    # baked into this repo.\n'
    '    p.add_argument("--log-registry-strings", action="store_true",\n'
    '                   help="observe real IORegistryEntry::setProperty(char const*, char const*) calls")\n'
)
BLOCK_CMD = (
    '    # UMI_REGISTRY_STRING_LOG: arm the upstream registry-string observer.\n'
    f'    if a.log_registry_strings:\n'
    f'        command += ["--registry-string-log-address", symbol("{REGISTRY_SYMBOL}")]\n'
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
            content = content.replace(anchor, block + anchor, 1)

    compile(content, str(args.runner), "exec")
    args.runner.write_text(content)
    action = "已撤销" if args.restore else "已应用"
    print(f"runner={args.runner} {action} sha256 {before_sha[:16]} -> "
          f"{hashlib.sha256(args.runner.read_bytes()).hexdigest()[:16]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
