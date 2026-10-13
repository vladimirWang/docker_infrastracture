#!/bin/bash
# Mac 本地执行：拉取 amd64 镜像，retag 后推送到 Docker Hub，并生成阿里云部署包
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PROJECT_NAME="docker-infrastracture"
# 阿里云 Ubuntu 是 amd64，Mac arm64 必须显式指定平台，否则推上去的镜像在阿里云无法运行
TARGET_PLATFORM="linux/amd64"
OUTPUT_DIR="$SCRIPT_DIR/dist"

# 必填：Docker Hub 用户名 (命名空间)
: "${DOCKERHUB_USERNAME:?请先设置环境变量 DOCKERHUB_USERNAME=你的DockerHub用户名，并执行 docker login 登录}"

echo "==> [0/5] 检查 Docker Hub 登录状态..."
if ! docker info 2>/dev/null | grep -q "Username:"; then
  echo "错误: 未检测到 Docker Hub 登录，请先执行: docker login"; exit 1
fi
echo "    Docker Hub Username: $DOCKERHUB_USERNAME"

echo "==> [1/5] 解析镜像列表..."
IMAGES=$(docker compose -p "$PROJECT_NAME" config --images)
if [ -z "$IMAGES" ]; then
  echo "错误: 未从 docker-compose.yml 解析到镜像"; exit 1
fi
echo "$IMAGES" | sed 's/^/    - /'

# 把官方镜像名转换成 Docker Hub 个人仓库格式
#   mysql:8.0                 -> <user>/mysql:8.0
#   pgvector/pgvector:pg17    -> <user>/pgvector:pg17
#   redis:7.2.11-alpine       -> <user>/redis:7.2.11-alpine
retag() {
  local img="$1" repo tag base
  repo="${img%%:*}"          # 去掉 :tag
  tag="${img#*:}"            # 取 tag
  [ "$tag" = "$img" ] && tag="latest"
  base="${repo##*/}"         # 取 repo 最后一段(去掉 registry/namespace 前缀)
  echo "$DOCKERHUB_USERNAME/$base:$tag"
}

echo "==> [2/5] 拉取并 retag 镜像 (platform=$TARGET_PLATFORM)..."
for img in $IMAGES; do
  new_tag=$(retag "$img")
  echo "    pulling: $img"
  docker pull --platform "$TARGET_PLATFORM" "$img"
  echo "    tagging: $img -> $new_tag"
  docker tag "$img" "$new_tag"
done

echo "==> [3/5] 推送到 Docker Hub..."
for img in $IMAGES; do
  new_tag=$(retag "$img")
  echo "    pushing: $new_tag"
  docker push "$new_tag"
done

echo "==> [4/5] 生成阿里云部署 compose 文件..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
DOCKERHUB_USERNAME="$DOCKERHUB_USERNAME" python3 - <<'PYEOF'
import re, os
user = os.environ["DOCKERHUB_USERNAME"]
with open("docker-compose.yml") as f:
    content = f.read()
def repl(m):
    indent, img = m.group(1), m.group(2)
    repo, _, tag = img.partition(":")
    base = repo.split("/")[-1]
    new = f"{user}/{base}:{tag}" if tag else f"{user}/{base}"
    return f"{indent}{new}"
new_content = re.sub(r'^(\s*image:\s*)(\S+)', repl, content, flags=re.MULTILINE)
with open("dist/docker-compose.prod.yml", "w") as f:
    f.write(new_content)
print(new_content)
PYEOF

echo "==> [5/5] 打包部署文件..."
cp .env  "$OUTPUT_DIR/"
cp up.sh "$OUTPUT_DIR/"
chmod +x "$OUTPUT_DIR/up.sh"

PACKAGE="$SCRIPT_DIR/${PROJECT_NAME}-deploy-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -czf "$PACKAGE" -C "$OUTPUT_DIR" .

echo ""
echo "==> 完成!"
echo "    推送命名空间:   $DOCKERHUB_USERNAME"
echo "    部署目录:       $OUTPUT_DIR"
echo "    部署压缩包:     $PACKAGE"
ls -lh "$OUTPUT_DIR"
echo ""
echo "下一步 (部署到阿里云):"
echo "  1. scp $PACKAGE <user>@<aliyun-ip>:/path/to/deploy/"
echo "  2. ssh <user>@<aliyun-ip>"
echo "  3. cd /path/to/deploy && mkdir -p infra && tar -xzf $(basename "$PACKAGE") -C infra && cd infra && ./up.sh"
