#!/bin/bash

# 快速修复和启动脚本
echo "🔧 修复权限并启动服务..."

# 确保文件权限正确
chmod 644 *.conf *.yml 2>/dev/null || true
chmod +x *.sh 2>/dev/null || true

# 设置SELinux上下文（如果需要）
if command -v chcon >/dev/null 2>&1; then
    sudo chcon -t container_file_t apache-servername.conf nginx.conf 2>/dev/null || true
    sudo chcon -Rt container_file_t ssl/ 2>/dev/null || true
fi

# 停止旧容器
docker-compose down 2>/dev/null || podman-compose down 2>/dev/null || true

# 启动服务
if command -v podman-compose >/dev/null; then
    echo "使用 podman-compose 启动..."
    podman-compose up -d
elif command -v docker-compose >/dev/null; then
    echo "使用 docker-compose 启动..."
    docker-compose up -d
else
    echo "❌ 未找到 compose 命令"
    exit 1
fi

echo "✅ 启动完成！"
