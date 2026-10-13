#!/bin/bash
# Mac 本地执行：打包部署文件传到阿里云
# 阿里云 ECS 已配置 registry-mirror，直接 pull Docker Hub 官方镜像加速，无需 Mac 端 retag/push
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PROJECT_NAME="docker-infrastracture"
OUTPUT_DIR="$SCRIPT_DIR/dist"

echo "==> 准备输出目录..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "==> 复制部署文件..."
cp docker-compose.yml "$OUTPUT_DIR/"
cp .env              "$OUTPUT_DIR/"
cp up.sh             "$OUTPUT_DIR/"
cp init-pgvector.sql "$OUTPUT_DIR/"
chmod +x "$OUTPUT_DIR/up.sh"

echo "==> 打包..."
PACKAGE="$SCRIPT_DIR/${PROJECT_NAME}-deploy-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -czf "$PACKAGE" -C "$OUTPUT_DIR" .

# tar.gz 已生成，dist 临时目录清理掉
rm -rf "$OUTPUT_DIR"

echo ""
echo "==> 完成!"
echo "    部署压缩包: $PACKAGE"
ls -lh "$PACKAGE"
echo ""
echo "下一步 (部署到阿里云):"
echo "  1. scp $PACKAGE <user>@<aliyun-ip>:/path/to/deploy/"
echo "  2. ssh <user>@<aliyun-ip>"
echo "  3. cd /path/to/deploy && mkdir -p infra && tar -xzf $(basename "$PACKAGE") -C infra && cd infra"
echo "  4. ./up.sh   # 阿里云 mirror 自动加速拉取官方镜像"
