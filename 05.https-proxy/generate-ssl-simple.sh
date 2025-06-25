#!/bin/bash

# 简化的Chrome兼容SSL证书生成脚本
# 使用方法: ./generate-ssl-simple.sh svn.lab.icinfra.ltd

if [ -z "$1" ]; then
    echo "使用方法: $0 <域名>"
    echo "示例: $0 svn.lab.icinfra.ltd"
    exit 1
fi

DOMAIN=$1
SSL_DIR="./ssl"

# 创建SSL目录
mkdir -p $SSL_DIR

echo "正在为域名 $DOMAIN 生成简化的SSL证书..."

# 生成私钥
echo "生成私钥..."
openssl genrsa -out $SSL_DIR/$DOMAIN.key 2048

# 创建简化的证书配置文件
cat > $SSL_DIR/$DOMAIN.conf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C=CN
ST=Shanghai
L=Shanghai
O=Lab Infrastructure
OU=IT Department
CN=$DOMAIN

[v3_req]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = localhost
IP.1 = 127.0.0.1
EOF

# 生成证书签名请求
echo "生成证书签名请求..."
openssl req -new -key $SSL_DIR/$DOMAIN.key -out $SSL_DIR/$DOMAIN.csr -config $SSL_DIR/$DOMAIN.conf

# 生成自签名证书
echo "生成自签名证书..."
openssl x509 -req -days 730 \
    -in $SSL_DIR/$DOMAIN.csr \
    -signkey $SSL_DIR/$DOMAIN.key \
    -out $SSL_DIR/$DOMAIN.crt \
    -extensions v3_req \
    -extfile $SSL_DIR/$DOMAIN.conf \
    -sha256

# 验证证书
echo "验证证书..."
if [ -f "$SSL_DIR/$DOMAIN.crt" ]; then
    echo "✅ 证书生成成功"
    openssl x509 -in $SSL_DIR/$DOMAIN.crt -text -noout | grep -E "(Subject:|Not After:|DNS:|IP:)"
else
    echo "❌ 证书生成失败"
    exit 1
fi

# 清理临时文件
rm $SSL_DIR/$DOMAIN.csr $SSL_DIR/$DOMAIN.conf

echo ""
echo "✅ 简化SSL证书生成完成！"
echo ""
echo "📁 生成的文件:"
echo "  🔑 私钥文件: $SSL_DIR/$DOMAIN.key"
echo "  📜 证书文件: $SSL_DIR/$DOMAIN.crt"
echo ""
echo "🔧 在Chrome中信任此证书:"
echo "1. 打开 chrome://settings/certificates"
echo "2. 管理证书 -> 受信任的根证书颁发机构"
echo "3. 导入 $SSL_DIR/$DOMAIN.crt"
echo "4. 重启Chrome"
