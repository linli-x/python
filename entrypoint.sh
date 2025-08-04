#!/bin/sh
set -e

# 设置备用端口
OTHER_PORT=${OTHER_PORT:-8080}

# 使用 sed 替换模板占位符
# 注意：我们现在只替换端口，IP 相关的占位符已从 Caddyfile 中移除
sed "s,{{.OTHER_PORT | default \"8080\"}},$OTHER_PORT," /etc/caddy/Caddyfile.template > /tmp/Caddyfile

# 在后台启动主应用程序
if [ -d "/app" ] && [ -n "$(ls -A /app)" ]; then
    echo "[entrypoint.sh] 正在启动 one-api 服务..."
    /app/$(ls /app) &
    echo "[entrypoint.sh] one-api 服务已在后台启动。"
else
    echo "[entrypoint.sh] 警告：/app 目录为空或不存在，不启动主应用程序。"
fi

# 启动 Caddy
echo "[entrypoint.sh] 正在启动 Caddy..."
exec caddy run --config /tmp/Caddyfile --adapter caddyfile