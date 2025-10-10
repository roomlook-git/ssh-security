# 快速开始指南

## 🎯 5分钟快速配置

### 步骤1：下载并运行脚本

```bash
# 方式1：一键运行（推荐）
bash <(curl -s https://raw.githubusercontent.com/roomlook-git/ssh-security/main/ssh-security.sh)

# 方式2：下载后运行
curl -O https://raw.githubusercontent.com/roomlook-git/ssh-security/main/ssh-security.sh
chmod +x ssh-security.sh
sudo ./ssh-security.sh
```

### 步骤2：检查SSH密钥（功能1）

```
选择: 1

会显示：
✓ 找到 1 个SSH密钥
  1. 类型: ssh-ed25519, 注释: user@laptop

Windows PowerShell 测试命令：
ssh -i ~/.ssh/id_ed25519 root@1.2.3.4 -p 22
```

**如果没有密钥，请先配置：**

```bash
# 本地电脑执行（不是服务器）
ssh-keygen -t ed25519 -C "your_email@example.com"

# 上传到服务器
ssh-copy-id root@your_server_ip
```

### 步骤3：在新终端测试密钥登录

**重要：** 不要关闭当前SSH会话！

在新终端执行：

```bash
# 使用功能1生成的命令
ssh -i ~/.ssh/id_ed25519 root@1.2.3.4 -p 22
```

如果能够免密登录，继续下一步。

### 步骤4：禁用密码登录（功能2）

回到脚本菜单：

```
选择: 2

询问是否修改端口:
1) 保持不变 (推荐)
2) 修改端口
请选择 [1-2]: 1

确认要重启SSH服务吗？(输入 yes 继续): yes
```

### 步骤5：测试新配置

在另一个新终端测试：

```bash
# 测试密钥登录（应该成功）
ssh -i ~/.ssh/id_ed25519 root@1.2.3.4

# 测试密码登录（应该失败）
ssh root@1.2.3.4
# 预期结果: Permission denied (publickey)
```

### 步骤6：安装fail2ban（功能3）

```
选择: 3

请输入要保护的端口 (多个端口用逗号分隔，直接回车使用 22):
[直接回车]

等待安装...

✓ fail2ban 服务已启动
✓ fail2ban 配置完成！
```

### 步骤7：验证fail2ban

```
选择: 4

输出示例:
Status
|- Number of jail:      2
`- Jail list:   sshd, recidive

Jail: sshd
|- Currently banned: 0
`- Total banned:     0
```

## ✅ 完成！

现在你的服务器已经配置了：

- ✅ SSH密钥登录
- ✅ 禁用密码登录
- ✅ fail2ban防暴力破解

## 📊 日常维护

### 每周检查一次

```bash
sudo ./ssh-security.sh

# 选择功能7：查看封禁列表
# 选择功能8：查看日志
```

### 添加新的SSH密钥

```bash
# 在新电脑生成密钥
ssh-keygen -t ed25519

# 上传公钥到服务器
# 方式1：如果还能密码登录
ssh-copy-id user@server

# 方式2：手动添加（在服务器上执行）
nano ~/.ssh/authorized_keys
# 粘贴新的公钥（一行）
```

### 紧急情况处理

#### 如果被锁在外面

1. **通过VNC/控制台登录**（联系服务器提供商）

2. **临时恢复密码登录**

```bash
# 编辑SSH配置
nano /etc/ssh/sshd_config

# 修改这一行
PasswordAuthentication yes

# 重启SSH
systemctl restart sshd

# 现在可以用密码登录了
```

3. **或使用脚本恢复备份**

```bash
sudo ./ssh-security.sh

# 选择功能10：恢复配置备份
# 选择最近的sshd_config备份
```

#### 如果自己的IP被封禁

```bash
# 方式1：使用脚本
sudo ./ssh-security.sh
# 选择功能6：手动解封IP

# 方式2：直接命令
sudo fail2ban-client set sshd unbanip 你的IP

# 方式3：停止fail2ban
sudo systemctl stop fail2ban
```

## 🔧 常用命令速查

### SSH相关

```bash
# 查看SSH状态
sudo systemctl status sshd

# 测试SSH配置
sudo sshd -t

# 重启SSH
sudo systemctl restart sshd

# 查看SSH日志
sudo tail -f /var/log/auth.log

# 查看当前SSH连接
who
```

### fail2ban相关

```bash
# 查看fail2ban状态
sudo systemctl status fail2ban

# 查看所有jail
sudo fail2ban-client status

# 查看sshd jail详情
sudo fail2ban-client status sshd

# 手动封禁IP
sudo fail2ban-client set sshd banip 1.2.3.4

# 手动解封IP
sudo fail2ban-client set sshd unbanip 1.2.3.4

# 查看日志
sudo tail -f /var/log/fail2ban.log

# 重启fail2ban
sudo systemctl restart fail2ban
```

### 系统安全

```bash
# 查看登录历史
last -20

# 查看失败的登录尝试
sudo grep "Failed password" /var/log/auth.log

# 查看成功的登录
sudo grep "Accepted" /var/log/auth.log

# 查看当前登录用户
w

# 更新系统
sudo apt update && sudo apt upgrade -y
```

## 📱 移动设备连接

### iOS (使用Termius)

1. 下载 Termius 应用
2. 添加主机
   - Hostname: 服务器IP
   - Port: SSH端口
   - Username: 用户名
3. 添加密钥
   - 生成新密钥或导入现有密钥
   - 将公钥添加到服务器

### Android (使用JuiceSSH)

1. 下载 JuiceSSH 应用
2. 创建新连接
   - Address: 服务器IP
   - Port: SSH端口
   - Identity: 选择或创建密钥
3. 连接测试

## 🎓 进阶配置

### 创建普通用户（推荐）

```bash
# 创建新用户
sudo adduser username

# 添加到sudo组
sudo usermod -aG sudo username

# 为新用户配置SSH密钥
sudo mkdir -p /home/username/.ssh
sudo cp /root/.ssh/authorized_keys /home/username/.ssh/
sudo chown -R username:username /home/username/.ssh
sudo chmod 700 /home/username/.ssh
sudo chmod 600 /home/username/.ssh/authorized_keys

# 测试新用户登录
ssh -i ~/.ssh/id_ed25519 username@server_ip
```

### 配置UFW防火墙

```bash
# 安装UFW
sudo apt install ufw -y

# 允许SSH端口（重要！）
sudo ufw allow 22/tcp
# 如果修改了SSH端口，使用实际端口号

# 启用防火墙
sudo ufw enable

# 查看状态
sudo ufw status
```

### 启用双因素认证（2FA）

```bash
# 安装Google Authenticator
sudo apt install libpam-google-authenticator -y

# 配置
google-authenticator

# 编辑PAM配置
sudo nano /etc/pam.d/sshd
# 添加: auth required pam_google_authenticator.so

# 编辑SSH配置
sudo nano /etc/ssh/sshd_config
# 修改: ChallengeResponseAuthentication yes

# 重启SSH
sudo systemctl restart sshd
```

## 💡 小贴士

1. **保持多个SSH会话**：修改配置时至少保持2个SSH连接
2. **记录端口号**：修改SSH端口后务必记录
3. **定期备份**：脚本自动备份，但建议定期下载到本地
4. **监控日志**：定期查看fail2ban日志和SSH登录记录
5. **更新系统**：定期运行系统更新
6. **白名单IP**：将常用IP添加到fail2ban白名单

## 🆘 获取帮助

- 查看完整文档：[README.md](README.md)
- 提交问题：[GitHub Issues](https://github.com/roomlook-git/ssh-security/issues)
- 安全建议：阅读 README.md 中的"安全建议"章节

---

**🎉 配置完成后，你的服务器安全性将大大提升！**

