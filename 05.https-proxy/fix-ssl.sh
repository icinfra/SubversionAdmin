#!/bin/bash

# 快速修复证书生成问题
DOMAIN=${1:-svn.lab.icinfra.ltd}
SSL_DIR="./ssl"

echo "🔧 修复证书生成问题..."
echo "域名: $DOMAIN"

# 1. 清理失败的证书文件
echo "1. 清理失败的证书文件..."
rm -f "$SSL_DIR/$DOMAIN.crt" "$SSL_DIR/$DOMAIN.key" "$SSL_DIR/$DOMAIN.csr" "$SSL_DIR/$DOMAIN.conf" "$SSL_DIR/dhparam.pem" 2>/dev/null || true

# 2. 停止可能在运行的DH参数生成进程
echo "2. 停止可能的后台进程..."
pkill -f "openssl dhparam" 2>/dev/null || true

# 3. 重新生成证书
echo "3. 重新生成证书..."
SUCCESS=false

# 尝试基础版本（最兼容）
if [ -f "generate-ssl-basic.sh" ]; then
    echo "使用基础证书生成器..."
    chmod +x generate-ssl-basic.sh
    if ./generate-ssl-basic.sh "$DOMAIN"; then
        SUCCESS=true
    fi
fi

# 如果基础版本失败，尝试简化版本
if [ "$SUCCESS" = false ] && [ -f "generate-ssl-simple.sh" ]; then
    echo "使用简化证书生成器..."
    chmod +x generate-ssl-simple.sh
    if ./generate-ssl-simple.sh "$DOMAIN"; then
        SUCCESS=true
    fi
fi

# 如果还是失败，尝试标准版本
if [ "$SUCCESS" = false ] && [ -f "generate-ssl-cert.sh" ]; then
    echo "使用标准证书生成器..."
    chmod +x generate-ssl-cert.sh
    if ./generate-ssl-cert.sh "$DOMAIN"; then
        SUCCESS=true
    fi
fi

if [ "$SUCCESS" = false ]; then
    echo "❌ 所有证书生成方法都失败了"
    exit 1
fi

echo "✅ 证书修复完成！"
