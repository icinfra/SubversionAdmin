#!/bin/bash

# Chrome兼容的SSL证书生成脚本
# 使用方法: ./generate-ssl-cert-chrome.sh svn.lab.icinfra.ltd

if [ -z "$1" ]; then
    echo "使用方法: $0 <域名>"
    echo "示例: $0 svn.lab.icinfra.ltd"
    exit 1
fi

DOMAIN=$1
SSL_DIR="./ssl"

# 创建SSL目录
mkdir -p $SSL_DIR

echo "正在为域名 $DOMAIN 生成Chrome兼容的SSL证书..."

# 生成私钥 (使用更强的4096位)
openssl genrsa -out $SSL_DIR/$DOMAIN.key 4096

# 创建证书配置文件（Chrome兼容）
cat > $SSL_DIR/$DOMAIN.conf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C=CN
ST=Shanghai
L=Shanghai
O=Lab Infrastructure Ltd
OU=IT Security Department
CN=$DOMAIN
emailAddress=admin@lab.icinfra.ltd

[v3_req]
basicConstraints = CA:FALSE
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment, keyAgreement
extendedKeyUsage = critical, serverAuth, clientAuth
subjectAltName = @alt_names
subjectKeyIdentifier = hash

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = *.$DOMAIN
DNS.3 = localhost
DNS.4 = *.localhost
IP.1 = 127.0.0.1
IP.2 = ::1
EOF

# 生成证书签名请求
echo "生成证书签名请求..."
openssl req -new -key $SSL_DIR/$DOMAIN.key -out $SSL_DIR/$DOMAIN.csr -config $SSL_DIR/$DOMAIN.conf

# 生成自签名证书（有效期2年，Chrome要求不超过825天）
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
openssl x509 -in $SSL_DIR/$DOMAIN.crt -text -noout | grep -E "(DNS:|IP:|Subject:|Issuer:|Not Before:|Not After:|Key Usage:|Extended Key Usage:)"

# 生成证书链文件（某些应用需要）
cp $SSL_DIR/$DOMAIN.crt $SSL_DIR/$DOMAIN-fullchain.crt

# 生成DH参数文件（增强安全性）
echo "生成DH参数文件（可能需要几分钟）..."
openssl dhparam -out $SSL_DIR/dhparam.pem 2048

# 清理临时文件
rm $SSL_DIR/$DOMAIN.csr $SSL_DIR/$DOMAIN.conf

echo ""
echo "✅ Chrome兼容的SSL证书生成完成！"
echo ""
echo "📁 生成的文件:"
echo "  🔑 私钥文件:     $SSL_DIR/$DOMAIN.key"
echo "  📜 证书文件:     $SSL_DIR/$DOMAIN.crt"
echo "  🔗 证书链文件:   $SSL_DIR/$DOMAIN-fullchain.crt"
echo "  🛡️  DH参数文件:   $SSL_DIR/dhparam.pem"
echo ""
echo "🔧 如何在Chrome中信任此证书:"
echo "1. 在Chrome中打开: chrome://settings/certificates"
echo "2. 点击 '管理证书' -> '受信任的根证书颁发机构'"
echo "3. 点击 '导入' 并选择 $SSL_DIR/$DOMAIN.crt"
echo "4. 重启Chrome浏览器"
echo ""
echo "🐧 Linux系统中添加信任:"
echo "sudo cp $SSL_DIR/$DOMAIN.crt /usr/local/share/ca-certificates/"
echo "sudo update-ca-certificates"
echo ""
echo "🍎 macOS系统中添加信任:"
echo "sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $SSL_DIR/$DOMAIN.crt"
echo ""
echo "🪟 Windows系统中添加信任:"
echo "certlm.msc -> 受信任的根证书颁发机构 -> 证书 -> 导入"
