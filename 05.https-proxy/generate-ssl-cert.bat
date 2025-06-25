@echo off
REM 自签名SSL证书生成脚本 (Windows版本)
REM 使用方法: generate-ssl-cert.bat svn.lab.icinfra.ltd

if "%1"=="" (
    echo 使用方法: %0 ^<域名^>
    echo 示例: %0 svn.lab.icinfra.ltd
    exit /b 1
)

set DOMAIN=%1
set SSL_DIR=.\ssl

REM 创建SSL目录
if not exist "%SSL_DIR%" mkdir "%SSL_DIR%"

echo 正在为域名 %DOMAIN% 生成自签名SSL证书...

REM 生成私钥
openssl genrsa -out "%SSL_DIR%\%DOMAIN%.key" 2048

REM 创建证书配置文件
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
echo O=Lab Infrastructure
echo OU=IT Department
echo CN=%DOMAIN%
echo.
echo [v3_req]
echo basicConstraints = CA:FALSE
echo keyUsage = nonRepudiation, digitalSignature, keyEncipherment
echo extendedKeyUsage = serverAuth
echo subjectAltName = @alt_names
echo.
echo [alt_names]
echo DNS.1 = %DOMAIN%
echo DNS.2 = *.%DOMAIN%
echo IP.1 = 127.0.0.1
) > "%SSL_DIR%\%DOMAIN%.conf"

REM 生成证书签名请求
openssl req -new -key "%SSL_DIR%\%DOMAIN%.key" -out "%SSL_DIR%\%DOMAIN%.csr" -config "%SSL_DIR%\%DOMAIN%.conf"

REM 生成自签名证书（有效期365天）
openssl x509 -req -days 365 -in "%SSL_DIR%\%DOMAIN%.csr" -signkey "%SSL_DIR%\%DOMAIN%.key" -out "%SSL_DIR%\%DOMAIN%.crt" -extensions v3_req -extfile "%SSL_DIR%\%DOMAIN%.conf"

REM 清理临时文件
del "%SSL_DIR%\%DOMAIN%.csr" "%SSL_DIR%\%DOMAIN%.conf"

echo SSL证书生成完成！
echo 证书文件: %SSL_DIR%\%DOMAIN%.crt
echo 私钥文件: %SSL_DIR%\%DOMAIN%.key
echo.
echo 注意: 这是自签名证书，浏览器会显示安全警告。
echo 请将证书添加到浏览器的受信任根证书颁发机构中。

pause
