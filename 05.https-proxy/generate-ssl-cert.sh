#!/bin/bash

# 自签名SSL证书生成脚本
# 使用方法: ./generate-ssl-cert.sh svn.lab.icinfra.ltd

if [ -z "$1" ]; then
    echo "使用方法: $0 <域名>"
    echo "示例: $0 svn.lab.icinfra.ltd"
    exit 1
fi

DOMAIN=$1
SSL_DIR="./ssl"

# 创建SSL目录
mkdir -p $SSL_DIR

echo "正在为域名 $DOMAIN 生成自签名SSL证书..."

# 生成私钥
openssl genrsa -out $SSL_DIR/$DOMAIN.key 2048

# 创建证书配置文件
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
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = *.$DOMAIN
IP.1 = 127.0.0.1
EOF

# 生成证书签名请求
openssl req -new -key $SSL_DIR/$DOMAIN.key -out $SSL_DIR/$DOMAIN.csr -config $SSL_DIR/$DOMAIN.conf

# 生成自签名证书（有效期365天）
openssl x509 -req -days 365 -in $SSL_DIR/$DOMAIN.csr -signkey $SSL_DIR/$DOMAIN.key -out $SSL_DIR/$DOMAIN.crt -extensions v3_req -extfile $SSL_DIR/$DOMAIN.conf

# 清理临时文件
rm $SSL_DIR/$DOMAIN.csr $SSL_DIR/$DOMAIN.conf

echo "SSL证书生成完成！"
echo "证书文件: $SSL_DIR/$DOMAIN.crt"
echo "私钥文件: $SSL_DIR/$DOMAIN.key"
echo ""
echo "注意: 这是自签名证书，浏览器会显示安全警告。"
echo "请将证书添加到浏览器的受信任根证书颁发机构中。"
