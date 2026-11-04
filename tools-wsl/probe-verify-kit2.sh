#!/bin/bash
set -u
B=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837
O=/mnt/e/Code/HackIos/out/probes/verify-kit2.txt
{
  echo "== build dir kernel binaries =="
  ls -l --time-style=+%H:%M "$B"/mach.development.bcm2837* 2>/dev/null | head
  echo "== symbol in unstripped =="
  llvm-nm "$B/mach.development.bcm2837.unstripped" 2>/dev/null | grep -E 'umi_crypto_kit' | head
  echo "== disassembly: PE_init_iokit calls =="
  llvm-objdump -d --disassemble-symbols=_PE_init_iokit "$B/mach.development.bcm2837.unstripped" 2>/dev/null | grep -E 'bl\s' | tail -8
  echo "== umi_crypto_kit_register bl list =="
  llvm-objdump -d --disassemble-symbols=_umi_crypto_kit_register "$B/mach.development.bcm2837.unstripped" 2>/dev/null | grep -E 'bl\s' | head -20
  echo "== register_crypto.o timestamp =="
  find "$B/libkern" -name 'register_crypto.o' -printf '%TH:%TM %p\n' 2>/dev/null
  find "$B" -name 'pe_init.o' -printf '%TH:%TM %p\n' 2>/dev/null | head -3
  echo "== where does build-xnu-payload.py read the kernel =="
  grep -nE 'kernel\.macho|mach\.development|Payloads|stage2|glob|Path\(' /mnt/e/Code/HackIos/tools-wsl/build-xnu-payload.py | head -25
  echo "== all kernel.macho copies with times =="
  find /home/unixnu/code/umi-work-pin/out -name 'kernel.macho' -printf '%TH:%TM %s %p\n' 2>/dev/null | head
} > "$O" 2>&1
echo done
