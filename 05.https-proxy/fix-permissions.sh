#!/bin/bash

# 快速修复权限问题
echo "修复文件权限..."

# 确保当前目录权限正确
chmod 755 .
chmod 644 *.conf *.yml 2>/dev/null || true
chmod +x *.sh 2>/dev/null || true

# 创建并设置logs目录权限
mkdir -p logs
chmod 755 logs
touch logs/access.log logs/error.log logs/svnadmin_access.log logs/svnadmin_error.log 2>/dev/null || true
chmod 666 logs/*.log 2>/dev/null || true

# 设置ssl目录权限
mkdir -p ssl
chmod 755 ssl
chmod 644 ssl/*.crt ssl/*.key 2>/dev/null || true

echo "权限修复完成"

# 重启服务
echo "重启服务..."
if command -v docker-compose >/dev/null; then
    docker-compose down
    docker-compose up -d
elif command -v podman-compose >/dev/null; then
    podman-compose down
    podman-compose up -d
else
    echo "未找到 docker-compose 或 podman-compose"
fi

echo "服务重启完成"
