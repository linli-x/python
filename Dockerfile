FROM oven/bun:latest AS builder

WORKDIR /build
COPY web/package.json .
COPY web/bun.lock .
RUN bun install
COPY ./web .
COPY ./VERSION .
RUN DISABLE_ESLINT_PLUGIN='true' VITE_REACT_APP_VERSION=$(cat VERSION) bun run build

FROM golang:alpine AS builder2

ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOOS=linux

WORKDIR /build

ADD go.mod go.sum ./
RUN go mod download

COPY . .
COPY --from=builder /build/dist ./web/dist
RUN go build -ldflags "-s -w -X 'one-api/common.Version=$(cat VERSION)'" -o one-api

FROM python:3.9-slim

# 安装依赖，注意 curl 和 ip 文件相关的都已移除
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    tzdata \
    ffmpeg \
    curl \
    gpg \
    netcat-openbsd \
    debian-keyring \
    debian-archive-keyring \
    apt-transport-https \
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg \
    && curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list \
    && apt-get update \
    && apt-get install caddy \
    && rm -rf /var/lib/apt/lists/*

# 复制简化的配置文件
COPY Caddyfile /etc/caddy/Caddyfile.template
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

WORKDIR /app
COPY --from=builder2 /build/one-api .
RUN mv one-api ip

# 创建非 root 用户和组（Debian 风格）
RUN addgroup --system appgroup && adduser --system --ingroup appgroup --no-create-home appuser

# 创建并授权必要的目录
RUN mkdir -p /data/.streamlit /data/.config/caddy /app/logs \
    && chown -R appuser:appgroup /app /data \
    && chmod -R 777 /app/logs

# 切换到非 root 用户
USER appuser
WORKDIR /data

# 暴露端口并设置入口点
EXPOSE 7860
ENTRYPOINT ["/entrypoint.sh"]
