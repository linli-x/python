#!/bin/sh
set -e

# 设置备用端口
OTHER_PORT=${OTHER_PORT:-8080}

# 使用 sed 替换模板占位符
sed "s,{{.OTHER_PORT | default \"8080\"}},$OTHER_PORT," /etc/caddy/Caddyfile.template > /tmp/Caddyfile

# 在后台启动主应用程序
if [ -d "/app" ] && [ -n "$(ls -A /app)" ]; then
    echo "[entrypoint.sh] 正在启动 one-api 服务..."
    /app/$(ls /app) &
    
    echo "[entrypoint.sh] 等待 one-api 在 3000 端口上就绪..."
    while ! nc -z localhost 3000; do   
      sleep 1 # 等待 1 秒重试
    done
    echo "[entrypoint.sh] one-api 已在 3000 端口上就绪。"

else
    echo "[entrypoint.sh] 警告：/app 目录为空或不存在，不启动主应用程序。"
fi

# 启动 Caddy
echo "[entrypoint.sh] 正在启动 Caddy..."
exec caddy run --config /tmp/Caddyfile --adapter caddyfile