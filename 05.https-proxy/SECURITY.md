# HTTPS-Only 安全配置说明

## 🔒 安全架构

此配置采用**HTTPS-Only**模式，只对外开放443端口，提供更高的安全性。

### 端口配置

- **443/tcp**: HTTPS Web访问（对外开放）
- **3690/tcp**: SVN协议访问（对外开放）
- **80/tcp**: 内部容器间通信（不对外开放）

### 网络架构

```
Internet
    ↓ HTTPS (443)
┌─────────────────┐
│   Nginx Proxy   │ ← 只监听443端口
│  (SSL终止)       │
└─────────────────┘
    ↓ HTTP (80)
┌─────────────────┐
│   SVN Admin     │ ← 内部网络
│    容器         │
└─────────────────┘
```

## 🛡️ 安全优势

1. **减少攻击面**: 不开放80端口，避免HTTP相关漏洞
2. **强制加密**: 所有Web流量都通过SSL/TLS加密
3. **防止降级攻击**: 无法通过HTTP访问敏感信息
4. **符合安全最佳实践**: 现代应用应该默认使用HTTPS

## 🚀 使用方式

### 用户访问
- ✅ https://svn.lab.icinfra.ltd (正常访问)
- ❌ http://svn.lab.icinfra.ltd (无法访问)
- ✅ svn://svn.lab.icinfra.ltd:3690 (SVN协议正常)

### 管理员操作
```bash
# 检查服务状态
docker-compose ps

# 查看HTTPS日志
docker-compose logs nginx

# 测试HTTPS连接
curl -k https://svn.lab.icinfra.ltd

# 检查端口监听（应该只有443和3690）
netstat -tlnp | grep -E ':443|:3690'
```

## 🔧 故障排除

### 常见问题

1. **无法通过HTTP访问**
   - 这是正常的，本配置只支持HTTPS

2. **证书警告**
   - 自签名证书会显示警告，生产环境请使用CA证书

3. **端口冲突**
   ```bash
   # 检查443端口是否被占用
   sudo netstat -tlnp | grep :443
   
   # 停止可能冲突的服务
   sudo systemctl stop nginx
   sudo systemctl stop httpd
   ```

### 防火墙配置

**CentOS/RHEL:**
```bash
# 只开放必要端口
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=3690/tcp
sudo firewall-cmd --permanent --remove-port=80/tcp  # 移除HTTP端口
sudo firewall-cmd --reload
```

**Ubuntu/Debian:**
```bash
# 配置ufw
sudo ufw allow 443/tcp
sudo ufw allow 3690/tcp
sudo ufw delete allow 80/tcp  # 移除HTTP端口
```

## 📊 监控建议

### 日志监控
```bash
# 实时监控HTTPS访问日志
docker-compose exec nginx tail -f /var/log/nginx/access.log

# 监控错误日志
docker-compose exec nginx tail -f /var/log/nginx/error.log
```

### 安全检查
```bash
# SSL配置检查
openssl s_client -connect svn.lab.icinfra.ltd:443 -servername svn.lab.icinfra.ltd

# 端口扫描检查
nmap -p 80,443,3690 localhost
```

## 🔄 回退到HTTP+HTTPS模式

如果需要同时支持HTTP（不推荐），可以：

1. 修改compose文件，添加80端口映射
2. 修改nginx.conf，添加HTTP重定向配置
3. 更新防火墙规则，开放80端口

但我们强烈建议保持HTTPS-Only配置以确保安全性。
