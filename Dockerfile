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

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    tzdata \
    ffmpeg \
    openssl \
    curl \
    caddy \
    && rm -rf /var/lib/apt/lists/*

COPY Caddyfile /etc/caddy/Caddyfile.template
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

WORKDIR /app
COPY --from=builder2 /build/one-api .
RUN mv one-api $(openssl rand -hex 8)

EXPOSE 7860
WORKDIR /data
ENTRYPOINT ["/entrypoint.sh"]
