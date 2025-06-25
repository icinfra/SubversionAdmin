#!/bin/bash

# SSL证书故障排除脚本
# 使用方法: ./ssl-troubleshoot.sh svn.lab.icinfra.ltd

DOMAIN=${1:-svn.lab.icinfra.ltd}
SSL_DIR="./ssl"

echo "🔍 SSL证书故障排除工具"
echo "域名: $DOMAIN"
echo "================================"

# 1. 检查证书文件是否存在
echo "1. 检查证书文件..."
if [ -f "$SSL_DIR/$DOMAIN.crt" ] && [ -f "$SSL_DIR/$DOMAIN.key" ]; then
    echo "✅ 证书文件存在"
else
    echo "❌ 证书文件不存在，请先生成证书"
    echo "执行: ./generate-ssl-cert-chrome.sh $DOMAIN"
    exit 1
fi

# 2. 检查证书有效性
echo ""
echo "2. 检查证书详情..."
echo "证书主题:"
openssl x509 -in "$SSL_DIR/$DOMAIN.crt" -noout -subject

echo "证书颁发者:"
openssl x509 -in "$SSL_DIR/$DOMAIN.crt" -noout -issuer

echo "证书有效期:"
openssl x509 -in "$SSL_DIR/$DOMAIN.crt" -noout -dates

echo "证书算法:"
openssl x509 -in "$SSL_DIR/$DOMAIN.crt" -noout -text | grep "Signature Algorithm" | head -1

# 3. 检查密钥用法
echo ""
echo "3. 检查密钥用法（Chrome兼容性）..."
KEY_USAGE=$(openssl x509 -in "$SSL_DIR/$DOMAIN.crt" -noout -text | grep -A5 "Key Usage")
if echo "$KEY_USAGE" | grep -q "Digital Signature" && echo "$KEY_USAGE" | grep -q "Key Encipherment"; then
    echo "✅ 密钥用法正确"
else
    echo "❌ 密钥用法可能有问题"
    echo "$KEY_USAGE"
fi

# 4. 检查扩展密钥用法
echo ""
echo "4. 检查扩展密钥用法..."
EXT_KEY_USAGE=$(openssl x509 -in "$SSL_DIR/$DOMAIN.crt" -noout -text | grep -A3 "Extended Key Usage")
if echo "$EXT_KEY_USAGE" | grep -q "TLS Web Server Authentication"; then
    echo "✅ 扩展密钥用法正确"
else
    echo "❌ 扩展密钥用法可能有问题"
    echo "$EXT_KEY_USAGE"
fi

# 5. 检查SAN (Subject Alternative Names)
echo ""
echo "5. 检查SAN扩展..."
SAN=$(openssl x509 -in "$SSL_DIR/$DOMAIN.crt" -noout -text | grep -A10 "Subject Alternative Name")
if echo "$SAN" | grep -q "$DOMAIN"; then
    echo "✅ SAN包含目标域名"
    echo "$SAN"
else
    echo "❌ SAN可能不包含目标域名"
    echo "$SAN"
fi

# 6. 检查私钥和证书匹配
echo ""
echo "6. 检查私钥和证书匹配性..."
CERT_HASH=$(openssl x509 -in "$SSL_DIR/$DOMAIN.crt" -noout -modulus | openssl md5)
KEY_HASH=$(openssl rsa -in "$SSL_DIR/$DOMAIN.key" -noout -modulus | openssl md5)
if [ "$CERT_HASH" = "$KEY_HASH" ]; then
    echo "✅ 私钥和证书匹配"
else
    echo "❌ 私钥和证书不匹配"
fi

# 7. 测试SSL连接
echo ""
echo "7. 测试SSL连接..."
if command -v docker >/dev/null || command -v podman >/dev/null; then
    if curl -k -s --connect-timeout 5 https://localhost:443 >/dev/null 2>&1; then
        echo "✅ SSL连接测试成功"
        
        # 检查SSL协议版本
        echo "SSL协议版本:"
        curl -k -s -o /dev/null -w "SSL版本: %{ssl_version}\n" https://localhost:443 2>/dev/null || echo "无法获取SSL版本信息"
    else
        echo "❌ SSL连接测试失败"
        echo "请检查容器是否运行: docker-compose ps"
    fi
else
    echo "⚠️  Docker/Podman未安装，跳过连接测试"
fi

# 8. Chrome特定检查
echo ""
echo "8. Chrome兼容性检查..."
CERT_TEXT=$(openssl x509 -in "$SSL_DIR/$DOMAIN.crt" -noout -text)

# 检查证书有效期 (Chrome要求不超过825天)
DAYS_VALID=$(openssl x509 -in "$SSL_DIR/$DOMAIN.crt" -noout -checkend 0 && echo "证书有效" || echo "证书已过期")
echo "证书状态: $DAYS_VALID"

# 检查签名算法 (Chrome不支持SHA-1)
if echo "$CERT_TEXT" | grep -q "sha256"; then
    echo "✅ 使用SHA-256签名算法"
elif echo "$CERT_TEXT" | grep -q "sha1"; then
    echo "❌ 使用SHA-1签名算法（Chrome不支持）"
else
    echo "⚠️  未知签名算法"
fi

# 9. 建议
echo ""
echo "================================"
echo "🛠️  故障排除建议:"
echo ""

if ! echo "$KEY_USAGE" | grep -q "Digital Signature" || ! echo "$KEY_USAGE" | grep -q "Key Encipherment"; then
    echo "❗ 如果Chrome显示 ERR_SSL_KEY_USAGE_INCOMPATIBLE:"
    echo "   重新生成证书: ./generate-ssl-cert-chrome.sh $DOMAIN"
    echo ""
fi

echo "🔧 在Chrome中信任证书的步骤:"
echo "1. 打开 chrome://settings/certificates"
echo "2. 管理证书 -> 受信任的根证书颁发机构"
echo "3. 导入 $SSL_DIR/$DOMAIN.crt"
echo "4. 重启Chrome"
echo ""

echo "🐧 Linux系统信任证书:"
echo "sudo cp $SSL_DIR/$DOMAIN.crt /usr/local/share/ca-certificates/"
echo "sudo update-ca-certificates"
echo ""

echo "📱 移动设备测试建议:"
echo "在手机上访问时，需要在设备上安装证书"
