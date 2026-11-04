#!/bin/bash
set -u
L=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/logs/20261103T132615602498Z/kernel.log
D=/home/unixnu/code/UniXNU-main/out/unixnu-logs/kernel-screen-20261103-212615.log
O=/mnt/e/Code/HackIos/out/probes/build2.txt
{
  echo "== driver log =="
  ls -l "$D"; tail -6 "$D"
  echo "== step log =="
  ls -l "$L"
  echo "== our files =="
  grep -naE 'register_crypto\.c:|pe_init\.c:' "$L" | tail -20
  echo "== fatal/error =="
  grep -naE 'fatal error|error: |\*\*\* \[' "$L" | tail -30
  echo "== link/packaging progress =="
  grep -naE 'LDFILELIST|Ld |kernel\.macho|kernelcache|IM4P|STEP|stage' "$L" | tail -15
  echo "== last 8 =="
  tail -8 "$L"
} > "$O" 2>&1
echo done
