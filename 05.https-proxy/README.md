# SVN Admin HTTPS 代理

这个目录包含了为 SVN Admin 服务配置 HTTPS 代理的完整解决方案。

## 文件说明

- `docker-compose.yml` - Docker Compose 编排文件
- `podman-compose.yml` - Podman Compose 编排文件（备份）
- `nginx.conf` - Nginx 代理配置
- `generate-ssl-cert.sh` - Linux/Mac 自签名证书生成脚本
- `generate-ssl-cert.bat` - Windows 自签名证书生成脚本

## 使用方法

### 1. 生成SSL证书

**Linux/Mac:**
```bash
chmod +x generate-ssl-cert.sh
./generate-ssl-cert.sh svn.lab.icinfra.ltd
```

**Windows:**
```cmd
generate-ssl-cert.bat svn.lab.icinfra.ltd
```

这将在 `ssl/` 目录下生成以下文件：
- `svn.lab.icinfra.ltd.crt` - SSL证书
- `svn.lab.icinfra.ltd.key` - SSL私钥

### 2. 创建必要的目录

```bash
mkdir -p logs ssl
```

### 3. 启动服务

**使用 Docker Compose:**
```bash
docker-compose up -d
```

**使用 Podman Compose:**
```bash
podman-compose up -d
```

### 4. 访问服务

- HTTPS: https://svn.lab.icinfra.ltd
- HTTP: http://svn.lab.icinfra.ltd (自动重定向到HTTPS)
- SVN协议: svn://svn.lab.icinfra.ltd:3690

## 架构说明

1. **Nginx** 作为反向代理，处理HTTPS请求并转发到后端SVN Admin服务
2. **SVN Admin** 运行在内部网络中，只通过Nginx暴露
3. **SSL终止** 在Nginx层完成，后端通信使用HTTP
4. **SVN协议** 直接透传，不经过Nginx代理

## 安全特性

- 强制HTTPS重定向
- 现代SSL/TLS配置
- 安全头设置
- 自签名证书支持

## 注意事项

1. 自签名证书会在浏览器中显示安全警告
2. 生产环境建议使用CA签发的证书
3. 确保防火墙允许80、443和3690端口
4. SVN Admin数据目录需要正确挂载

## 故障排除

### 常见问题

**1. Apache ServerName 警告**
```
AH00558: httpd: Could not reliably determine the server's fully qualified domain name
```
解决方案：已添加 `apache-servername.conf` 配置文件自动解决

**2. Nginx 权限拒绝错误**
```
nginx: [alert] could not open error log file: open() "/var/log/nginx/error.log" failed (13: Permission denied)
```
解决方案：
```bash
chmod +x fix-permissions.sh
./fix-permissions.sh
```

**3. CentOS 7.9 特殊设置**
```bash
# 设置SELinux上下文
sudo chcon -Rt container_file_t logs/ ssl/ nginx.conf apache-servername.conf

# 或者临时禁用SELinux
sudo setenforce 0
```

### 诊断命令

查看日志：
```bash
docker-compose logs -f
```

查看容器状态：
```bash
docker-compose ps
```

查看Nginx日志：
```bash
tail -f logs/svnadmin_access.log
tail -f logs/svnadmin_error.log
```

检查端口占用：
```bash
sudo netstat -tlnp | grep -E ':80|:443|:3690'
```

### 完全重置
```bash
# 停止并删除容器
docker-compose down

# 清理日志
rm -f logs/*.log

# 重新启动
docker-compose up -d
```
