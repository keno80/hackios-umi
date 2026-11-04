#!/bin/bash
exec > /mnt/e/Code/HackIos/out/probes/userdata-dry.txt 2>&1
cd /home/unixnu/code/umi-work-pin || exit 1
echo "== port userdata.py for Linux =="
tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/port-pin-userdata.py > /tmp/port-pin-userdata.py
python3 /tmp/port-pin-userdata.py
echo "PORT_RC=$?"
echo "== import check =="
echo "== git diff stat =="
cd sources/UniXNU && git status --short | head && git diff --stat | tail -3
cd /home/unixnu/code/umi-work-pin
echo "== dry run =="
timeout 600 python3 -c "
import sys; sys.path.insert(0,'sources/UniXNU/scripts')
from unixnu.cli import main
main(['build','userdata','-D','devices/umi','--out','out/umi-xnu','--dry-run'])
"
echo "RC=$?"
