#!/bin/sh
set -e

# 获取 EdgeOne IP 地址并格式化为 Caddyfile 需要的 JSON 字符串
EDGEONE_IPS=$(curl -s 'https://api.edgeone.ai/ips?version=v4&area=global' | sed 's/.*/"&"/' | tr '\n' ',' | sed 's/,$//')

# 检查是否成功获取 IP
if [ -z "$EDGEONE_IPS" ]; then
  echo "无法获取 EdgeOne IP 地址，正在退出。"
  exit 1
fi

# 设置备用端口
OTHER_PORT=${OTHER_PORT:-8080}

# 使用 awk 安全地替换模板占位符
awk \
  -v ips="$EDGEONE_IPS" \
  -v port="$OTHER_PORT" \
  '{
    gsub("{{.EDGEONE_IPS}}", ips);
    gsub("{{.OTHER_PORT | default \"8080\"}}", port);
    print;
  }' /etc/caddy/Caddyfile.template > /tmp/Caddyfile

# 在后台启动主应用程序
# 确保 /app 目录存在且不为空
if [ -d "/app" ] && [ -n "$(ls -A /app)" ]; then
    /app/$(ls /app) &
else
    echo "警告：/app 目录为空或不存在，不启动主应用程序。"
fi

# 启动 Caddy
exec caddy run --config /tmp/Caddyfile --adapter caddyfile