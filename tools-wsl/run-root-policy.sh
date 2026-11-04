#!/bin/bash
# U 步之三之备料：在 Linux 上把 root-policy 这条子链跑出来。
#
# 官方链是 prepare_umi_root_policy.py -> out/umi/root-policy/policies.json -> build_umi_root_bundle.py
# -> libVerifiedRootProbe.a。上游那件写死三处 Mac 假设（check.py 的 xcrun clang -dynamiclib、
# /opt/homebrew/opt/openssl@3、diskutil info -plist 产的 *-volume-info.json），本仓用三个 Linux
# 等价件补上，验证逻辑（真 RSA3072 验签 + 逐 4096 块 C 校验）一条没减：
#   verified-root-host-check-linux.py   宿主件用 /usr/bin/clang -shared（u102 归因：gcc 会被
#                                       工具链的 ld 壳抢走，报 unknown argument '--64'）
#   make-volume-infos-linux.py          GPT 定位容器 + libfsapfs 读卷 UUID，Writable 取只读挂接
#   prepare-root-policy-linux.py        官方 preparer 的逐行拷贝，只替换上面两处调用
#
# 慢点说明：两个窗合计 9.1 GiB，manifest 生成 + 逐块 C 校验各读一遍，十几分钟起。
# 用法：run-root-policy.sh [volume|prepare|all]
set -u
MODE=${1:-all}
PIN=/home/unixnu/code/umi-work-pin
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
T=$PIN/out/umi-xnu/umi/tree
MEDIA=$PIN/out/umi-xnu/umi/userdata
OUTP=$PIN/out/umi/root-policy
LOGDIR=/home/unixnu/code/UniXNU-main/out/unixnu-logs
LOG=$LOGDIR/root-policy-$(date +%Y%m%d-%H%M%S).log
LATEST=$LOGDIR/root-policy-latest.log
WINLOG=/mnt/e/Code/HackIos/out/probes/root-policy-current.log   # Windows 侧可读，方便随时看进度
REPO=/mnt/e/Code/HackIos/tools-wsl

source /usr/local/bin/unixnu-env 2>/dev/null
export PATH="$TC/CommandLineTools/usr/bin:$TC/bin:/usr/local/bin:/usr/bin:/bin"
export LC_ALL=C CLT_PREFIX=$TC/CommandLineTools/usr XCTOOLCHAIN_PREFIX=$TC/XcodeDefault.xctoolchain/usr
export XNU_TOOLCHAIN_BIN="$TC/CommandLineTools/usr/bin $TC/XcodeDefault.xctoolchain/usr/bin"
export UNIXNU_SDKROOT=$T/.cache/fakeroot UNIXNU_SDK_VERSION=17.0
export UNIXNU_PLATFORM_PATH=$T/.cache/fakeroot/Platforms/iPhoneOS.platform
export CCC_OVERRIDE_OPTIONS='# +-Wno-missing-designated-field-initializers +-Wno-unused-but-set-global +-Wno-unnecessary-virtual-specifier +-Wno-deprecated-enum-enum-conversion'

echo "== 0. 前置 =="
printf '  userdata-root.json   %s\n' "$([ -f "$MEDIA/userdata-root.json" ] && echo 有 || echo 缺)"
printf '  userdata-root.img    %s\n' "$([ -f "$MEDIA/userdata-root.img" ] && du -h "$MEDIA/userdata-root.img" | cut -f1 || echo 缺)"
printf '  VerifiedRoot kit     %s\n' "$([ -d "$PIN/sources/UniXNU/kits/VerifiedRoot" ] && echo 有 || echo 缺)"
printf '  losetup sudo 免密    %s\n' "$(sudo -n losetup -l >/dev/null 2>&1 && echo 可用 || echo 不可用)"
printf '  iPhoneOS SDKROOT     %s\n' "$([ -d "$UNIXNU_SDKROOT" ] && echo 有 || echo 缺)"
for f in verified-root-host-check-linux.py make-volume-infos-linux.py prepare-root-policy-linux.py; do
  printf '  %-36s %s\n' "$f" "$([ -f "$REPO/$f" ] && echo 有 || echo 缺)"; done

echo
echo "== 1. 把三个 Linux 件装进构建树 tools/（非上游名，不覆盖上游文件） =="
for f in verified-root-host-check-linux.py make-volume-infos-linux.py prepare-root-policy-linux.py; do
  tr -d '\r' < "$REPO/$f" > "$PIN/tools/$f" && echo "  装了 $f ($PIN/tools/$f)"
done

if [ "$MODE" = "volume" ] || [ "$MODE" = "all" ]; then
  echo
  echo "== 2. 实测 APFS 卷身份，产 *-volume-info.json =="
  python3 -u "$PIN/tools/make-volume-infos-linux.py" --userdata-json "$MEDIA/userdata-root.json" 2>&1 | tail -10
  echo "  rc=${PIPESTATUS[0]}"
  for w in OS SystemOS; do
    f=$MEDIA/$w-volume-info.json
    [ -f "$f" ] && { echo "  -- $f --"; python3 -c "
import json;d=json.load(open('$f'))[0]
for k in ('FilesystemType','VolumeUUID','Writable','VolumeName','ContainerRelativeOffset','LocatedBy'):
    print(f'     {k} = {d.get(k)}')"; } || echo "  缺 $f"
  done
fi

if [ "$MODE" = "prepare" ] || [ "$MODE" = "all" ]; then
  echo
  echo "== 3. 官方逐块验证出策略件（9.1 GiB 读两遍，十几分钟起）=="
  echo "  日志 $LOG"
  echo "  实时副本 $WINLOG"
  mkdir -p "$LOGDIR"; ln -sf "$LOG" "$LATEST"
  cd "$PIN" || exit 1
  python3 -u tools/prepare-root-policy-linux.py 2>&1 | tee "$LOG" "$WINLOG"
  rc=${PIPESTATUS[0]}
  echo "  prepare rc=$rc"
  echo
  echo "== 4. 产物核对 =="
  ls -la $OUTP 2>&1 | head -12
  for w in OS SystemOS; do
    [ -f "$OUTP/$w/verification.json" ] && python3 -c "
import json;d=json.load(open('$OUTP/$w/verification.json'))
print('  $w: blocks_verified=%s image_sha256=%s… manifest=%s B real_c=%s' % (
  d.get('blocks_verified'), str(d.get('image_sha256'))[:16],
  __import__('os').path.getsize('$OUTP/$w/manifest.bin'), d.get('real_c_signature_and_block_verification')))"
  done
  [ -f $OUTP/host/checks.json ] && { echo "  -- host/checks.json --"; head -30 $OUTP/host/checks.json; }
  [ -f $OUTP/policies.json ] && python3 -c "
import json;d=json.load(open('$OUTP/policies.json'))
print('  policies.json status=%s manifest_bytes=%s apple_signature_claim=%s hardware_tested=%s' % (
  d.get('status'), d.get('manifest_bytes'), d.get('apple_signature_claim'), d.get('hardware_tested')))" \
    || echo "  没有 policies.json，root-policy 没成"
fi
# 只列残留，不做全局 losetup -D（那会连带 detach 别人挂上的 loop）
echo "== 残留 loop（应为空；measure() 每条都 finally 释放）=="
sudo -n losetup -l 2>&1 | head -6
echo done
