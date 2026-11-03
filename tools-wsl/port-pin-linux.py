#!/usr/bin/env python3
"""把上游 main 的 Linux 主机支持回移到 pin 树的一份拷贝里。

只改拷贝（UniXNU-pin），原 pin 保持不动；git HEAD 不变，所以 setup-workspace 的
source-lock 校验照样通过。每处替换都断言锚点存在，失败就退出，不做静默降级。
"""
import shutil
import subprocess
import sys
from pathlib import Path

PIN = Path('/home/unixnu/code/UniXNU')
MAIN = Path('/home/unixnu/code/UniXNU-main')
DST = Path('/home/unixnu/code/UniXNU-pin')

LINUX_BLOCK = '''python3 scripts/prepare-xnu-source.py
# (Linux port) 上游 main 的主机支持回移：改写少数假设 Apple 工具链的源码，并把 Mac 自带的
# host compiler / mig / 内存与 CPU 数量显式告诉 xnu 的 make。
XNU_HOST_MAKE_ARGS=()
if [ "$(uname -s)" = Linux ]; then
  python3 scripts/linux/prepare-xnu.py source
  export PLATFORM=iPhoneOS HOST_CC="$CLT_PREFIX/bin/xnu-host-cc" MIGCOM="$CLT_PREFIX/libexec/migcom"
  XNU_HOST_MAKE_ARGS=(TIGHTBEAMC=tightbeamc-not-supported BUILD_DSYM=0
    MEMORY_SIZE="$(( $(getconf _PHYS_PAGES) * $(getconf PAGE_SIZE) ))"
    SYSCTL_HW_PHYSICALCPU="$(nproc)" SYSCTL_HW_LOGICALCPU="$(nproc)"
    LD_KERNEL_LIBS="$ROOT/.cache/fakeroot/usr/local/lib/kernel/libcc_kext.a")
fi
'''

COPY_TREE = '''copy_tree() {
  mkdir -p "$2"
  cp -R "$1/." "$2/"
}
copy_tree refer/libplatform/include "$KERNEL_SDKROOT/usr/local/include"
copy_tree refer/libplatform/private "$KERNEL_SDKROOT/usr/local/include"
copy_tree refer/libplatform/private/platform "$KERNEL_SDKROOT/System/Library/Frameworks/Kernel.framework/Versions/A/PrivateHeaders/platform"
'''

FIREHOSE_LIBS = '''if [ ! -f "$KERNEL_SDKROOT/usr/local/lib/kernel/libfirehose_kernel.a" ]; then
  bash scripts/build-firehose.sh
fi
if [ "$(uname -s)" = Linux ]; then
  python3 scripts/linux/prepare-xnu.py libs
fi
'''


def sub(text, old, new, name):
    if old not in text:
        sys.exit(f'锚点未找到：{name}')
    if text.count(old) != 1:
        sys.exit(f'锚点不唯一：{name}（{text.count(old)} 处）')
    return text.replace(old, new)


def main():
    if DST.exists():
        shutil.rmtree(DST)
    subprocess.run(['cp', '-a', str(PIN), str(DST)], check=True)
    head = subprocess.check_output(['git', '-C', str(DST), 'rev-parse', 'HEAD'], text=True).strip()
    pinned = subprocess.check_output(['git', '-C', str(PIN), 'rev-parse', 'HEAD'], text=True).strip()
    assert head == pinned == '7b52e7968c76453cdc18b5aa174fc368d5293b91', (head, pinned)
    print(f'pin 拷贝完成，HEAD 仍是 {head[:12]}')

    shutil.copytree(MAIN / 'scripts/linux', DST / 'scripts/linux')
    print('已复制 scripts/linux（xcrun/clang shim、prepare-xnu.py、llvm 补丁）')
    shutil.copyfile(MAIN / 'scripts/build-firehose.sh', DST / 'scripts/build-firehose.sh')
    print('已替换 build-firehose.sh（含 Linux 分支；libdispatch tag 两边一致）')

    script = DST / 'scripts/build-xnu-4k-baseline.sh'
    text = script.read_text()
    text = sub(text, 'python3 scripts/prepare-xnu-source.py\n', LINUX_BLOCK, 'prepare-xnu source 挂钩')
    text = sub(text,
               'ditto refer/libplatform/include "$KERNEL_SDKROOT/usr/local/include"\n'
               'ditto refer/libplatform/private "$KERNEL_SDKROOT/usr/local/include"\n'
               'ditto refer/libplatform/private/platform "$KERNEL_SDKROOT/System/Library/Frameworks/Kernel.framework/Versions/A/PrivateHeaders/platform"\n',
               COPY_TREE, 'ditto -> copy_tree')
    text = sub(text,
               '    SYMROOT="$ROOT/build/xnu/sym" DSTROOT="$KERNEL_SDKROOT"\n  touch',
               '    SYMROOT="$ROOT/build/xnu/sym" DSTROOT="$KERNEL_SDKROOT" \\\n'
               '    ${XNU_HOST_MAKE_ARGS[@]+"${XNU_HOST_MAKE_ARGS[@]}"}\n  touch',
               'installhdrs 追加主机参数')
    text = sub(text,
               'if [ ! -f "$KERNEL_SDKROOT/usr/local/lib/kernel/libfirehose_kernel.a" ]; then\n'
               '  bash scripts/build-firehose.sh\nfi\n',
               FIREHOSE_LIBS, 'prepare-xnu libs 挂钩')
    text = sub(text,
               '  CFLAGS_EXTRA="$EXTRA_CFLAGS" "${EXTRA_MAKE_ARGS[@]}" \\\n'
               '  OBJROOT="$ROOT/build/xnu/ios-obj"',
               '  CFLAGS_EXTRA="$EXTRA_CFLAGS" "${EXTRA_MAKE_ARGS[@]}" ${XNU_HOST_MAKE_ARGS[@]+"${XNU_HOST_MAKE_ARGS[@]}"} \\\n'
               '  OBJROOT="$ROOT/build/xnu/ios-obj"',
               '最终 make 追加主机参数')
    script.write_text(text)
    print('build-xnu-4k-baseline.sh 五处 Linux 回移完成')
    diff = subprocess.run(['git', '-C', str(DST), 'diff', '--stat'], capture_output=True, text=True).stdout
    print('--- 相对 pin 的改动 ---')
    print(diff.strip() or '（scripts/linux 与 build-firehose.sh 是新增/替换，未计入 diff --stat 之外）')


if __name__ == '__main__':
    main()
