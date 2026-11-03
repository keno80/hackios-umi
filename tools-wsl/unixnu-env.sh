#!/bin/bash
# 统一的 WSL 出网设置：NAT 网关即宿主地址，子网可能变，动态解析
gw=$(ip route 2>/dev/null | awk '/^default/ {print $3; exit}')
if [ -n "${gw:-}" ]; then
  export http_proxy="http://${gw}:8090"
  export https_proxy="http://${gw}:8090"
  export HTTP_PROXY="$http_proxy"
  export HTTPS_PROXY="$https_proxy"
  export no_proxy="localhost,127.0.0.1,::1"
  export NO_PROXY="$no_proxy"
  export ALL_PROXY="$http_proxy"
fi
export TMPDIR=${TMPDIR:-/var/tmp}
