#!/bin/sh
set -e

# 优先尝试从网络获取 IP
CURL_OUTPUT=$(curl -sS 'https://api.edgeone.ai/ips?version=v4&area=global' 2> /tmp/curl_error.log)

# 检查 curl 是否成功并且返回了内容
if [ -n "$CURL_OUTPUT" ]; then
    echo "成功从网络获取 EdgeOne IP 列表。"
    EDGEONE_IPS_RAW="$CURL_OUTPUT"
else
    echo "警告：无法从网络获取 EdgeOne IP 列表，回退到使用本地文件。"
    cat /tmp/curl_error.log >&2
    
    if [ -f /etc/edgeone_ips ]; then
        echo "正在使用 /etc/edgeone_ips ..."
        EDGEONE_IPS_RAW=$(cat /etc/edgeone_ips)
    else
        echo "错误：网络获取失败，且本地回退文件 /etc/edgeone_ips 不存在。"
        exit 1
    fi
fi

# 格式化 IP 列表为空格分隔的字符串
EDGEONE_IPS=$(echo "$EDGEONE_IPS_RAW" | tr '\n' ' ')

# 检查 IP 列表是否为空
if [ -z "$EDGEONE_IPS" ]; then
  echo "错误：最终的 IP 地址列表为空。"
  exit 1
fi

# 设置备用端口
OTHER_PORT=${OTHER_PORT:-8080}

# 使用 sed 替换模板占位符
# 先替换 IP，再替换端口
sed -e "s,{{.EDGEONE_IPS}},$EDGEONE_IPS," \
    -e "s,{{.OTHER_PORT | default \"8080\"}},$OTHER_PORT," \
    /etc/caddy/Caddyfile.template > /tmp/Caddyfile


# 在后台启动主应用程序
if [ -d "/app" ] && [ -n "$(ls -A /app)" ]; then
    echo "[entrypoint.sh] 正在启动 one-api 服务..."
    /app/$(ls /app) &
    echo "[entrypoint.sh] one-api 服务已在后台启动。"
else
    echo "[entrypoint.sh] 警告：/app 目录为空或不存在，不启动主应用程序。"
fi

# 启动 Caddy
exec caddy run --config /tmp/Caddyfile --adapter caddyfile