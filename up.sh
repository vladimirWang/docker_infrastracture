#!/bin/bash
# 阿里云 Ubuntu 上执行：从 Docker Hub(经 mirror 加速) 拉取镜像并启动生产服务
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PROJECT_NAME="docker-infrastracture"
COMPOSE_FILE="docker-compose.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "错误: $COMPOSE_FILE 不存在，请确认部署包完整"; exit 1
fi

echo "==> [1/2] 拉取镜像 (经阿里云 mirror 加速)..."
docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" pull

echo "==> [2/2] 启动服务..."
docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" up -d

echo ""
echo "==> 服务状态:"
docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" ps
