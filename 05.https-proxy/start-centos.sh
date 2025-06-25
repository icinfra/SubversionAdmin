#!/bin/bash

# CentOS 7.9 SVN Admin HTTPS 代理启动脚本
# 解决权限和SELinux问题

set -e

DOMAIN=${1:-svn.lab.icinfra.ltd}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 启动 SVN Admin HTTPS 代理 (CentOS 7.9)"
echo "域名: $DOMAIN"
echo "工作目录: $SCRIPT_DIR"

# 1. 检查必要命令
echo "1. 检查环境..."
if ! command -v podman >/dev/null && ! command -v docker >/dev/null; then
    echo "❌ 错误: 未找到 podman 或 docker"
    exit 1
fi

# 优先使用podman
if command -v podman-compose >/dev/null; then
    COMPOSE_CMD="podman-compose"
elif command -v docker-compose >/dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo "❌ 错误: 未找到 podman-compose 或 docker-compose"
    exit 1
fi

echo "使用: $COMPOSE_CMD"

# 2. 创建目录结构
echo "2. 创建目录结构..."
sudo mkdir -p /data/svn/{svnadmin,conf.d,sasl2}
mkdir -p "$SCRIPT_DIR"/{ssl,logs}

# 3. 设置文件权限
echo "3. 设置文件权限..."
chmod 644 "$SCRIPT_DIR"/*.conf 2>/dev/null || true
chmod 644 "$SCRIPT_DIR"/*.yml 2>/dev/null || true
chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true

# 确保apache配置文件存在且有正确权限
if [ ! -f "$SCRIPT_DIR/apache-servername.conf" ]; then
    echo "❌ 错误: apache-servername.conf 文件不存在"
    exit 1
fi

# 4. 处理SELinux
echo "4. 处理SELinux..."
if command -v getenforce >/dev/null && [ "$(getenforce)" = "Enforcing" ]; then
    echo "SELinux 是 Enforcing 模式，设置正确的上下文..."
    
    # 设置容器文件上下文
    sudo chcon -Rt container_file_t /data/svn/ 2>/dev/null || true
    sudo chcon -t container_file_t "$SCRIPT_DIR/apache-servername.conf" 2>/dev/null || true
    sudo chcon -t container_file_t "$SCRIPT_DIR/nginx.conf" 2>/dev/null || true
    sudo chcon -Rt container_file_t "$SCRIPT_DIR/ssl/" 2>/dev/null || true
    
    # 设置SELinux布尔值
    sudo setsebool -P httpd_can_network_connect 1 2>/dev/null || true
    sudo setsebool -P container_manage_cgroup 1 2>/dev/null || true
    
    echo "SELinux 上下文设置完成"
else
    echo "SELinux 未启用或非 Enforcing 模式"
fi

# 5. 生成SSL证书
echo "5. 检查SSL证书..."
if [ ! -f "$SCRIPT_DIR/ssl/$DOMAIN.crt" ] || [ ! -f "$SCRIPT_DIR/ssl/$DOMAIN.key" ]; then
    echo "生成SSL证书..."
    
    # 清理可能存在的部分文件
    rm -f "$SCRIPT_DIR/ssl/$DOMAIN.crt" "$SCRIPT_DIR/ssl/$DOMAIN.key" "$SCRIPT_DIR/ssl/$DOMAIN.csr" "$SCRIPT_DIR/ssl/$DOMAIN.conf" 2>/dev/null || true
    pkill -f "openssl dhparam" 2>/dev/null || true
    
    # 尝试多个证书生成脚本，按优先级顺序
    SUCCESS=false
    
    # 1. 尝试基础版本（最兼容）
    if [ -f "$SCRIPT_DIR/generate-ssl-basic.sh" ]; then
        echo "尝试基础版证书生成器..."
        chmod +x "$SCRIPT_DIR/generate-ssl-basic.sh"
        if "$SCRIPT_DIR/generate-ssl-basic.sh" "$DOMAIN" 2>/dev/null; then
            SUCCESS=true
            echo "✅ 基础证书生成成功"
        else
            echo "⚠️  基础版本失败"
            rm -f "$SCRIPT_DIR/ssl/$DOMAIN.crt" "$SCRIPT_DIR/ssl/$DOMAIN.key" 2>/dev/null || true
        fi
    fi
    
    # 2. 尝试简化版本
    if [ "$SUCCESS" = false ] && [ -f "$SCRIPT_DIR/generate-ssl-simple.sh" ]; then
        echo "尝试简化版证书生成器..."
        chmod +x "$SCRIPT_DIR/generate-ssl-simple.sh"
        if "$SCRIPT_DIR/generate-ssl-simple.sh" "$DOMAIN" 2>/dev/null; then
            SUCCESS=true
            echo "✅ 简化证书生成成功"
        else
            echo "⚠️  简化版本失败"
            rm -f "$SCRIPT_DIR/ssl/$DOMAIN.crt" "$SCRIPT_DIR/ssl/$DOMAIN.key" 2>/dev/null || true
        fi
    fi
    
    # 3. 尝试标准版本
    if [ "$SUCCESS" = false ] && [ -f "$SCRIPT_DIR/generate-ssl-cert.sh" ]; then
        echo "尝试标准版证书生成器..."
        chmod +x "$SCRIPT_DIR/generate-ssl-cert.sh"
        if "$SCRIPT_DIR/generate-ssl-cert.sh" "$DOMAIN" 2>/dev/null; then
            SUCCESS=true
            echo "✅ 标准证书生成成功"
        else
            echo "⚠️  标准版本失败"
            rm -f "$SCRIPT_DIR/ssl/$DOMAIN.crt" "$SCRIPT_DIR/ssl/$DOMAIN.key" 2>/dev/null || true
        fi
    fi
    
    # 4. 最后尝试Chrome兼容版本（可能有问题但保留选项）
    if [ "$SUCCESS" = false ] && [ -f "$SCRIPT_DIR/generate-ssl-cert-chrome.sh" ]; then
        echo "尝试Chrome兼容版证书生成器..."
        chmod +x "$SCRIPT_DIR/generate-ssl-cert-chrome.sh"
        if "$SCRIPT_DIR/generate-ssl-cert-chrome.sh" "$DOMAIN" 2>/dev/null; then
            SUCCESS=true
            echo "✅ Chrome兼容证书生成成功"
        else
            echo "⚠️  Chrome兼容版本失败"
            rm -f "$SCRIPT_DIR/ssl/$DOMAIN.crt" "$SCRIPT_DIR/ssl/$DOMAIN.key" 2>/dev/null || true
        fi
    fi
    
    if [ "$SUCCESS" = false ]; then
        echo "❌ 错误: 所有证书生成方法都失败了"
        echo "请检查 openssl 是否正确安装"
        exit 1
    fi
else
    echo "SSL证书已存在"
    # 验证证书兼容性
    if [ -f "$SCRIPT_DIR/ssl-troubleshoot.sh" ]; then
        chmod +x "$SCRIPT_DIR/ssl-troubleshoot.sh"
        echo "验证证书兼容性..."
        "$SCRIPT_DIR/ssl-troubleshoot.sh" "$DOMAIN" 2>/dev/null | grep -E "(✅|❌|⚠️)" || true
    fi
fi

# 6. 配置防火墙
echo "6. 配置防火墙..."
if systemctl is-active --quiet firewalld; then
    sudo firewall-cmd --permanent --add-port=443/tcp 2>/dev/null || true
    sudo firewall-cmd --permanent --add-port=3690/tcp 2>/dev/null || true
    # 移除HTTP端口（如果之前添加过）
    sudo firewall-cmd --permanent --remove-port=80/tcp 2>/dev/null || true
    sudo firewall-cmd --reload 2>/dev/null || true
    echo "防火墙端口已配置 (443, 3690)"
fi

# 7. 停止冲突服务
echo "7. 停止冲突服务..."
sudo systemctl stop httpd 2>/dev/null || true
sudo systemctl stop nginx 2>/dev/null || true

# 8. 清理旧容器
echo "8. 清理旧容器..."
$COMPOSE_CMD down 2>/dev/null || true

# 9. 启动服务
echo "9. 启动服务..."
$COMPOSE_CMD up -d

# 10. 等待启动
echo "10. 等待服务启动..."
sleep 15

# 11. 检查状态
echo "11. 检查服务状态..."
$COMPOSE_CMD ps

echo ""
echo "✅ 部署完成！"
echo ""
echo "📋 访问信息:"
echo "  🌐 HTTPS Web: https://$DOMAIN (仅HTTPS访问)"
echo "  📦 SVN 协议:  svn://$DOMAIN:3690"
echo ""
echo "⚠️  注意: 只开放了443端口，不支持HTTP访问"
echo ""
echo "📝 查看日志:"
echo "  $COMPOSE_CMD logs -f"
echo ""
echo "🔧 故障排除:"
echo "  $COMPOSE_CMD logs svnadmin"
echo "  $COMPOSE_CMD logs nginx"
echo ""

# 12. 简单测试
echo "12. 测试HTTPS连接..."
if curl -s -k -o /dev/null -w "%{http_code}" https://localhost | grep -q "200"; then
    echo "✅ HTTPS 连接正常"
else
    echo "⚠️  HTTPS 测试失败，请检查日志"
fi

echo "⚠️  注意: HTTP端口已关闭，只能通过HTTPS访问"
