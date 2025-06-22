#!/bin/bash

# SVN Admin HTTPS 代理部署脚本 for CentOS 7.9
# 使用方法: ./deploy.sh svn.lab.icinfra.ltd

DOMAIN=${1:-svn.lab.icinfra.ltd}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "正在部署 SVN Admin HTTPS 代理..."
echo "域名: $DOMAIN"

# 1. 创建必要的目录并设置权限
echo "1. 创建目录并设置权限..."
sudo mkdir -p /data/svn/{svnadmin,conf.d,sasl2}
mkdir -p "$SCRIPT_DIR"/{ssl,logs}

# 设置logs目录权限，让nginx容器可以写入
chmod 755 "$SCRIPT_DIR/logs"
chmod 644 "$SCRIPT_DIR/nginx.conf" 2>/dev/null || true

# 2. 生成SSL证书
echo "2. 生成SSL证书..."
if [ ! -f "$SCRIPT_DIR/ssl/$DOMAIN.crt" ]; then
    chmod +x "$SCRIPT_DIR/generate-ssl-cert.sh"
    "$SCRIPT_DIR/generate-ssl-cert.sh" "$DOMAIN"
else
    echo "SSL证书已存在，跳过生成步骤"
fi

# 3. 配置防火墙
echo "3. 配置防火墙..."
if systemctl is-active --quiet firewalld; then
    sudo firewall-cmd --permanent --add-port=80/tcp 2>/dev/null || true
    sudo firewall-cmd --permanent --add-port=443/tcp 2>/dev/null || true
    sudo firewall-cmd --permanent --add-port=3690/tcp 2>/dev/null || true
    sudo firewall-cmd --reload 2>/dev/null || true
    echo "防火墙端口已开放"
else
    echo "防火墙未运行，跳过配置"
fi

# 4. 设置SELinux（如果启用）
echo "4. 配置SELinux..."
if command -v getenforce >/dev/null && [ "$(getenforce)" = "Enforcing" ]; then
    sudo setsebool -P httpd_can_network_connect 1 2>/dev/null || true
    sudo chcon -Rt container_file_t /data/svn/ 2>/dev/null || true
    sudo chcon -Rt container_file_t "$SCRIPT_DIR"/{ssl,logs,nginx.conf} 2>/dev/null || true
    echo "SELinux策略已配置"
else
    echo "SELinux未启用或非Enforcing模式，跳过配置"
fi

# 5. 停止可能冲突的服务
echo "5. 停止冲突服务..."
sudo systemctl stop httpd 2>/dev/null || true
sudo systemctl stop nginx 2>/dev/null || true

# 6. 停止已存在的容器
echo "6. 清理已存在的容器..."
docker-compose down 2>/dev/null || true
podman-compose down 2>/dev/null || true

# 7. 启动服务
echo "7. 启动服务..."
if command -v docker-compose >/dev/null; then
    docker-compose up -d
elif command -v podman-compose >/dev/null; then
    podman-compose up -d
else
    echo "错误: 未找到 docker-compose 或 podman-compose"
    exit 1
fi

# 8. 等待服务启动
echo "8. 等待服务启动..."
sleep 10

# 9. 验证服务
echo "9. 验证服务状态..."
if command -v docker-compose >/dev/null; then
    docker-compose ps
else
    podman-compose ps
fi

echo ""
echo "部署完成！"
echo "访问地址:"
echo "  HTTPS: https://$DOMAIN"
echo "  HTTP:  http://$DOMAIN (自动重定向到HTTPS)"
echo "  SVN:   svn://$DOMAIN:3690"
echo ""
echo "注意: 如果使用自签名证书，浏览器会显示安全警告"
echo "     请将证书添加到受信任的根证书颁发机构"
