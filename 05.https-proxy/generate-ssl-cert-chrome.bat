@echo off
REM Chrome兼容的SSL证书生成脚本 (Windows版本)
REM 使用方法: generate-ssl-cert-chrome.bat svn.lab.icinfra.ltd

if "%1"=="" (
    echo 使用方法: %0 ^<域名^>
    echo 示例: %0 svn.lab.icinfra.ltd
    exit /b 1
)

set DOMAIN=%1
set SSL_DIR=.\ssl

REM 创建SSL目录
if not exist "%SSL_DIR%" mkdir "%SSL_DIR%"

echo 正在为域名 %DOMAIN% 生成Chrome兼容的SSL证书...

REM 生成私钥 (使用4096位)
openssl genrsa -out "%SSL_DIR%\%DOMAIN%.key" 4096

REM 创建证书配置文件（Chrome兼容）
(
echo [req]
echo distinguished_name = req_distinguished_name
echo req_extensions = v3_req
echo prompt = no
echo.
echo [req_distinguished_name]
echo C=CN
echo ST=Shanghai
echo L=Shanghai
echo O=Lab Infrastructure Ltd
echo OU=IT Security Department
echo CN=%DOMAIN%
echo emailAddress=admin@lab.icinfra.ltd
echo.
echo [v3_req]
echo basicConstraints = CA:FALSE
echo keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment, keyAgreement
echo extendedKeyUsage = critical, serverAuth, clientAuth
echo subjectAltName = @alt_names
echo subjectKeyIdentifier = hash
echo.
echo [alt_names]
echo DNS.1 = %DOMAIN%
echo DNS.2 = *.%DOMAIN%
echo DNS.3 = localhost
echo DNS.4 = *.localhost
echo IP.1 = 127.0.0.1
echo IP.2 = ::1
) > "%SSL_DIR%\%DOMAIN%.conf"

REM 生成证书签名请求
echo 生成证书签名请求...
openssl req -new -key "%SSL_DIR%\%DOMAIN%.key" -out "%SSL_DIR%\%DOMAIN%.csr" -config "%SSL_DIR%\%DOMAIN%.conf"

REM 生成自签名证书（有效期2年）
echo 生成自签名证书...
openssl x509 -req -days 730 -in "%SSL_DIR%\%DOMAIN%.csr" -signkey "%SSL_DIR%\%DOMAIN%.key" -out "%SSL_DIR%\%DOMAIN%.crt" -extensions v3_req -extfile "%SSL_DIR%\%DOMAIN%.conf" -sha256

REM 验证证书
echo 验证证书...
openssl x509 -in "%SSL_DIR%\%DOMAIN%.crt" -text -noout | findstr /C:"DNS:" /C:"IP:" /C:"Subject:" /C:"Issuer:" /C:"Not Before:" /C:"Not After:" /C:"Key Usage:"

REM 生成证书链文件
copy "%SSL_DIR%\%DOMAIN%.crt" "%SSL_DIR%\%DOMAIN%-fullchain.crt"

REM 生成DH参数文件
echo 生成DH参数文件（可能需要几分钟）...
openssl dhparam -out "%SSL_DIR%\dhparam.pem" 2048

REM 清理临时文件
del "%SSL_DIR%\%DOMAIN%.csr" "%SSL_DIR%\%DOMAIN%.conf"

echo.
echo ✅ Chrome兼容的SSL证书生成完成！
echo.
echo 📁 生成的文件:
echo   🔑 私钥文件:     %SSL_DIR%\%DOMAIN%.key
echo   📜 证书文件:     %SSL_DIR%\%DOMAIN%.crt
echo   🔗 证书链文件:   %SSL_DIR%\%DOMAIN%-fullchain.crt
echo   🛡️  DH参数文件:   %SSL_DIR%\dhparam.pem
echo.
echo 🔧 如何在Chrome中信任此证书:
echo 1. 在Chrome中打开: chrome://settings/certificates
echo 2. 点击 '管理证书' -^> '受信任的根证书颁发机构'
echo 3. 点击 '导入' 并选择 %SSL_DIR%\%DOMAIN%.crt
echo 4. 重启Chrome浏览器
echo.
echo 🪟 Windows系统中添加信任:
echo certlm.msc -^> 受信任的根证书颁发机构 -^> 证书 -^> 导入
echo.

pause
