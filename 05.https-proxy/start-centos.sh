#!/bin/bash

# CentOS 7.9 SVN Admin HTTPS 代理启动脚本
# 解决权限和SELinux问题，支持可配置数据路径和镜像
# wanlin.wang

set -e

DOMAIN=${1:-svn.lab.icinfra.ltd}
SVN_DATA_PATH=${2:-/data/svn}
SVN_IMAGE=${3:-registry.cn-hangzhou.aliyuncs.com/witersencom/svnadmin:2.5.10}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 启动 SVN Admin HTTPS 代理 (CentOS 7.9)"
echo "域名: $DOMAIN"
echo "数据路径: $SVN_DATA_PATH"
echo "镜像: $SVN_IMAGE"
echo "工作目录: $SCRIPT_DIR"

# 导出环境变量供docker-compose使用
export SVN_DATA_PATH
export SVN_IMAGE

# 1. 检查必要命令并设置命令变量
echo "1. 检查环境..."

# 确定容器运行时命令
CONTAINER_CMD=""
if command -v podman >/dev/null; then
    CONTAINER_CMD="podman"
elif command -v docker >/dev/null; then
    CONTAINER_CMD="docker"
else
    echo "❌ 错误: 未找到 podman 或 docker"
    exit 1
fi

# 确定compose命令
COMPOSE_CMD=""
if command -v podman-compose >/dev/null; then
    COMPOSE_CMD="podman-compose"
elif command -v docker-compose >/dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo "❌ 错误: 未找到 podman-compose 或 docker-compose"
    exit 1
fi

echo "使用容器运行时: $CONTAINER_CMD"
echo "使用Compose: $COMPOSE_CMD"

# 2. 创建目录结构
echo "2. 创建目录结构..."
sudo mkdir -p "$SVN_DATA_PATH"/{svnadmin,conf.d,sasl2}
mkdir -p "$SCRIPT_DIR"/{ssl,logs}

# 3. 检查是否需要初始化配置
echo "3. 检查配置文件..."
NEED_INIT=false

if [ ! -d "$SVN_DATA_PATH/svnadmin" ] || [ -z "$(ls -A "$SVN_DATA_PATH/svnadmin" 2>/dev/null)" ]; then
    echo "需要初始化 svnadmin 配置"
    NEED_INIT=true
fi

if [ ! -d "$SVN_DATA_PATH/conf.d" ] || [ -z "$(ls -A "$SVN_DATA_PATH/conf.d" 2>/dev/null)" ]; then
    echo "需要初始化 conf.d 配置"
    NEED_INIT=true
fi

if [ ! -d "$SVN_DATA_PATH/sasl2" ]; then
    echo "需要初始化 sasl2 配置"
    NEED_INIT=true
fi

# 4. 执行初始化（如果需要）
if [ "$NEED_INIT" = true ]; then
    echo "4. 执行配置初始化..."
    echo "使用镜像: $SVN_IMAGE"

    # 启动临时容器进行初始化
    echo "启动临时初始化容器..."
    CONTAINER_ID=$($CONTAINER_CMD run -d --name svnadmin-init-temp --privileged \
        "$SVN_IMAGE" /usr/sbin/init)

    # 等待容器启动
    echo "等待容器启动..."
    sleep 10

    # 检查容器是否正常运行
    if ! $CONTAINER_CMD ps | grep -q svnadmin-init-temp; then
        echo "❌ 错误: 初始化容器启动失败"
        $CONTAINER_CMD logs svnadmin-init-temp 2>/dev/null || true
        $CONTAINER_CMD rm -f svnadmin-init-temp 2>/dev/null || true
        exit 1
    fi

    # 拷贝配置文件
    echo "拷贝配置文件到 $SVN_DATA_PATH..."
    $CONTAINER_CMD cp svnadmin-init-temp:/home/svnadmin "$SVN_DATA_PATH/" || {
        echo "⚠️  警告: 拷贝 svnadmin 目录失败"
    }
    $CONTAINER_CMD cp svnadmin-init-temp:/etc/httpd/conf.d "$SVN_DATA_PATH/" || {
        echo "⚠️  警告: 拷贝 conf.d 目录失败"
    }
    $CONTAINER_CMD cp svnadmin-init-temp:/etc/sasl2 "$SVN_DATA_PATH/" || {
        echo "⚠️  警告: 拷贝 sasl2 目录失败"
    }

    # 清理临时容器
    echo "清理临时容器..."
    $CONTAINER_CMD stop svnadmin-init-temp 2>/dev/null || true
    $CONTAINER_CMD rm svnadmin-init-temp 2>/dev/null || true

    # 验证拷贝结果
    echo "验证配置文件..."
    INIT_SUCCESS=true

    if [ ! -d "$SVN_DATA_PATH/svnadmin" ] || [ -z "$(ls -A "$SVN_DATA_PATH/svnadmin" 2>/dev/null)" ]; then
        echo "❌ 错误: svnadmin 配置拷贝失败"
        INIT_SUCCESS=false
    fi

    if [ ! -d "$SVN_DATA_PATH/conf.d" ] || [ -z "$(ls -A "$SVN_DATA_PATH/conf.d" 2>/dev/null)" ]; then
        echo "❌ 错误: conf.d 配置拷贝失败"
        INIT_SUCCESS=false
    fi

    if [ ! -d "$SVN_DATA_PATH/sasl2" ]; then
        echo "❌ 错误: sasl2 配置拷贝失败"
        INIT_SUCCESS=false
    fi

    if [ "$INIT_SUCCESS" = false ]; then
        echo "❌ 配置初始化失败，请检查权限和镜像是否正确"
        exit 1
    fi

    echo "✅ 配置初始化完成"
else
    echo "4. 配置文件已存在，跳过初始化"
fi

# 5. 设置文件权限
echo "5. 设置文件权限..."
# 确保配置目录权限正确
sudo chown -R $(id -u):$(id -g) "$SVN_DATA_PATH" 2>/dev/null || true
chmod -R 755 "$SVN_DATA_PATH" 2>/dev/null || true

chmod 644 "$SCRIPT_DIR"/*.conf 2>/dev/null || true
chmod 644 "$SCRIPT_DIR"/*.yml 2>/dev/null || true
chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true

# 确保apache配置文件存在且有正确权限
if [ ! -f "$SCRIPT_DIR/apache-servername.conf" ]; then
    echo "❌ 错误: apache-servername.conf 文件不存在"
    exit 1
fi

# 6. 处理SELinux
echo "6. 处理SELinux..."
if command -v getenforce >/dev/null && [ "$(getenforce)" = "Enforcing" ]; then
    echo "SELinux 是 Enforcing 模式，设置正确的上下文..."

    # 设置容器文件上下文
    sudo chcon -Rt container_file_t "$SVN_DATA_PATH"/ 2>/dev/null || true
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

# 7. 生成SSL证书
echo "7. 检查SSL证书..."
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

# 8. 配置防火墙
echo "8. 配置防火墙..."
if systemctl is-active --quiet firewalld; then
    sudo firewall-cmd --permanent --add-port=443/tcp 2>/dev/null || true
    sudo firewall-cmd --permanent --add-port=3690/tcp 2>/dev/null || true
    # 移除HTTP端口（如果之前添加过）
    sudo firewall-cmd --permanent --remove-port=80/tcp 2>/dev/null || true
    sudo firewall-cmd --reload 2>/dev/null || true
    echo "防火墙端口已配置 (443, 3690)"
fi

# 9. 停止冲突服务
echo "9. 停止冲突服务..."
sudo systemctl stop httpd 2>/dev/null || true
sudo systemctl stop nginx 2>/dev/null || true

# 10. 清理旧容器
echo "10. 清理旧容器..."
$COMPOSE_CMD down 2>/dev/null || true

# 11. 启动服务并等待
echo "11. 启动服务..."
echo "使用容器运行时: $CONTAINER_CMD"
echo "使用镜像: $SVN_IMAGE"
COMPOSE_PROFILES=default $COMPOSE_CMD up -d
echo "12. 等待服务启动..."
sleep 10

# 12. 修改权限
if [ "$NEED_INIT" = true ]; then
    $CONTAINER_CMD exec -it svnadmin chown -R apache:apache /home/svnadmin
fi

# 13. 检查状态
echo "13. 检查服务状态..."
$COMPOSE_CMD ps

echo ""
echo "✅ 部署完成！"
echo ""
echo "📋 访问信息:"
echo "  🌐 HTTPS Web: https://$DOMAIN (仅HTTPS访问)"
echo "  📦 SVN 协议:  svn://$DOMAIN:3690"
echo "  📁 数据路径: $SVN_DATA_PATH"
echo "  🐳 使用镜像: $SVN_IMAGE"
echo "  🔧 容器运行时: $CONTAINER_CMD"
echo "  📦 Compose工具: $COMPOSE_CMD"
echo ""
echo "⚠️  注意: 只开放了443端口，不支持HTTP访问"
echo ""
echo "📝 查看日志:"
echo "  $COMPOSE_CMD logs -f"
echo ""
echo "🔧 故障排除:"
echo "  $COMPOSE_CMD logs svnadmin"
echo "  $COMPOSE_CMD logs nginx"
echo "  $CONTAINER_CMD ps -a"
echo "  $CONTAINER_CMD logs <container_name>"
echo ""

# 14. 简单测试
echo "14. 测试HTTPS连接..."
if curl -s -k -o /dev/null -w "%{http_code}" https://localhost | grep -q "200"; then
    echo "✅ HTTPS 连接正常"
else
    echo "⚠️  HTTPS 测试失败，请检查日志"
fi

echo "⚠️  注意: HTTP端口已关闭，只能通过HTTPS访问"
