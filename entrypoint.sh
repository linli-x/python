#!/bin/sh
set -e

# 获取 EdgeOne IP 地址并格式化为 JSON 数组
EDGEONE_IPS=$(curl -s 'https://api.edgeone.ai/ips?version=v4&area=global' | sed 's/.*/"&"/' | tr '\n' ',' | sed 's/,$//')

# 检查是否成功获取 IP
if [ -z "$EDGEONE_IPS" ]; then
  echo "无法获取 EdgeOne IP 地址，正在退出。"
  exit 1
fi

# 从模板生成 Caddyfile
sed -e "s,{{.EDGEONE_IPS}},$EDGEONE_IPS," \
    -e "s,{{.OTHER_PORT | default \"8080\"}},${OTHER_PORT:-8080}," \
    /etc/caddy/Caddyfile.template > /etc/caddy/Caddyfile

# 在后台启动主应用程序
/app/$(ls /app) &

# 启动 Caddy
exec caddy run --config /etc/caddy/Caddyfile