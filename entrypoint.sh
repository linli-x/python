#!/bin/sh
set -e

# 设置一个可写的主目录
export HOME=/data

# 设置备用端口
OTHER_PORT=${OTHER_PORT:-8080}

# 生成 Caddyfile
sed "s,{{.OTHER_PORT | default \"8080\"}},$OTHER_PORT," /etc/caddy/Caddyfile.template > /tmp/Caddyfile

# 在后台静默启动主应用程序
if [ -f "/app/ip" ]; then
    /app/ip > /dev/null 2>&1 &
    
    # 等待端口就绪
    while ! nc -z localhost 3000; do   
      sleep 1
    done
fi

# 静默启动 Caddy
exec caddy run --config /tmp/Caddyfile --adapter caddyfile > /dev/null 2>&1