#!/bin/sh
set -e

# 优先尝试从网络获取 IP，将 stderr 重定向以便捕获错误
CURL_OUTPUT=$(curl -sS 'https://api.edgeone.ai/ips?version=v4&area=global' 2> /tmp/curl_error.log)

# 检查 curl 是否成功并且返回了内容
if [ -n "$CURL_OUTPUT" ]; then
    echo "成功从网络获取 EdgeOne IP 列表。"
    EDGEONE_IPS_RAW="$CURL_OUTPUT"
else
    echo "警告：无法从网络获取 EdgeOne IP 列表，回退到使用本地文件。"
    # 将 curl 的错误信息输出到终端
    cat /tmp/curl_error.log >&2
    
    if [ -f /etc/edgeone_ips ]; then
        echo "正在使用 /etc/edgeone_ips ..."
        EDGEONE_IPS_RAW=$(cat /etc/edgeone_ips)
    else
        echo "错误：网络获取失败，且本地回退文件 /etc/edgeone_ips 不存在。"
        exit 1
    fi
fi

# IP 列表已经是格式化的，直接使用
EDGEONE_IPS=$(echo "$EDGEONE_IPS_RAW")

# 检查 IP 列表是否为空
if [ -z "$EDGEONE_IPS" ]; then
  echo "错误：最终的 IP 地址列表为空。"
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
if [ -d "/app" ] && [ -n "$(ls -A /app)" ]; then
    /app/$(ls /app) &
else
    echo "警告：/app 目录为空或不存在，不启动主应用程序。"
fi

# 启动 Caddy
exec caddy run --config /tmp/Caddyfile --adapter caddyfile