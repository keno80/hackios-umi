#!/bin/bash
# gdb-stop.py 固定找 <qemu>/../share/qemu/edk2-aarch64-code.fd（+同名 edk2-arm-vars.fd）。
# Ubuntu 的 qemu-efi-aarch64 只给 QEMU_EFI.fd（2MB 合并镜像），改成发行版自带的 AAVMF 分裂对。
set -u
C=/usr/share/AAVMF/AAVMF_CODE.no-secboot.fd
V=/usr/share/AAVMF/AAVMF_VARS.fd
[ -r "$C" ] && [ -r "$V" ] || { echo "缺 AAVMF 分裂镜像"; exit 1; }
ln -sfn "$C" /usr/share/qemu/edk2-aarch64-code.fd
ln -sfn "$V" /usr/share/qemu/edk2-arm-vars.fd
ls -l /usr/share/qemu/edk2-aarch64-code.fd /usr/share/qemu/edk2-arm-vars.fd
