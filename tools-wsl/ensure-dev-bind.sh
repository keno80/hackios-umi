#!/bin/bash
# 工作区的 devices/umi 用符号链接指向设备仓；unixnu 的 expand() 会 resolve()，
# 于是 provenance 收据里 p.relative_to(ROOT) 越界报错。bind mount 让路径留在工作区内。
set -u
R=/home/unixnu/code/umi-work-pin
S=/home/unixnu/code/UniXNU-umi
T=$R/devices/umi
# bind 后 findmnt 的 SOURCE 形如 /dev/sdd[/home/unixnu/code/UniXNU-umi]
if mountpoint -q "$T" && findmnt -no SOURCE --target "$T" | grep -q "\[$S\]"; then
  echo "bind 已就位"
else
  [ -L "$T" ] && rm "$T"
  [ -d "$T" ] && mountpoint -q "$T" && umount "$T"
  [ -d "$T" ] && [ -n "$(ls -A "$T")" ] && { echo "$T 是非空目录，停手"; ls "$T" | head -3; exit 1; }
  mkdir -p "$T"
  mount --bind "$S" "$T" || { echo "bind 失败"; exit 1; }
  echo "bind 完成：$S -> $T"
fi
python3 - "$T" <<'PY'
import sys
from pathlib import Path
t = Path(sys.argv[1])
p = (t / "scripts/umi-lock-trace.h").resolve()
root = t.parents[1]
print(f"resolve={p}")
print(f"在工作区 {root} 内 = {p.is_relative_to(root)}")
print(f"board.toml = {(t/'board.toml').is_file()}  git HEAD = "
      f"{(t/'.git').exists()}")
PY
