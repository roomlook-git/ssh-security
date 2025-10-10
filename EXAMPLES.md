# 使用示例

本文档提供各种使用场景的详细示例。

## 📋 目录

- [基础使用](#基础使用)
- [高级场景](#高级场景)
- [故障排除](#故障排除)
- [自动化部署](#自动化部署)

## 基础使用

### 场景1：全新服务器初始配置

```bash
# 第一次登录新服务器
ssh root@new_server_ip

# 下载并运行脚本
bash <(curl -s https://raw.githubusercontent.com/[用户名]/[仓库名]/main/ssh-security.sh)

# 执行流程：
# 1. 先配置SSH密钥（在本地电脑）
ssh-keygen -t ed25519 -C "myemail@example.com"
ssh-copy-id root@new_server_ip

# 2. 运行脚本，选择功能1检查
# 3. 在新终端测试密钥登录
# 4. 回到脚本，选择功能2禁用密码
# 5. 选择功能3安装fail2ban
# 6. 完成！
```

### 场景2：已有服务器加固

```bash
# 服务器已经运行一段时间，想要加强安全

# 1. 检查是否已有SSH密钥
sudo ./ssh-security.sh
# 选择: 1

# 2. 如果没有密钥，先配置
# 本地执行：
ssh-copy-id root@server_ip

# 3. 禁用密码登录
# 选择: 2

# 4. 安装fail2ban
# 选择: 3
```

### 场景3：修改SSH端口

```bash
# 想要将SSH端口从22改为2222

sudo ./ssh-security.sh
# 选择: 2

# 询问是否修改端口时选择: 2
# 输入新端口: 2222

# ⚠️ 重要：修改防火墙规则
sudo ufw allow 2222/tcp
sudo ufw delete allow 22/tcp  # 可选：删除旧规则

# 测试新端口
ssh -i ~/.ssh/id_ed25519 root@server_ip -p 2222
```

## 高级场景

### 场景4：多用户环境配置

```bash
# 创建管理员用户
sudo adduser admin
sudo usermod -aG sudo admin

# 为新用户配置SSH密钥
sudo mkdir -p /home/admin/.ssh
sudo cp /root/.ssh/authorized_keys /home/admin/.ssh/
sudo chown -R admin:admin /home/admin/.ssh
sudo chmod 700 /home/admin/.ssh
sudo chmod 600 /home/admin/.ssh/authorized_keys

# 测试新用户登录
ssh -i ~/.ssh/id_ed25519 admin@server_ip

# 创建普通用户
sudo adduser user1

# 为普通用户添加密钥（在本地电脑）
ssh-copy-id -i ~/.ssh/id_ed25519 user1@server_ip

# 配置SSH禁止root登录
# 编辑 /etc/ssh/sshd_config
PermitRootLogin no

# 重启SSH
sudo systemctl restart sshd
```

### 场景5：fail2ban高级配置

```bash
# 运行脚本安装fail2ban
sudo ./ssh-security.sh
# 选择: 3

# 添加常用IP到白名单
# 选择: 9
# 输入: 203.0.113.100  (你的办公室IP)

# 手动编辑配置以自定义参数
sudo nano /etc/fail2ban/jail.local

# 修改为更严格的配置：
[sshd]
maxretry = 2        # 2次失败就封禁
findtime = 5m       # 5分钟内
bantime = 48h       # 封禁48小时

# 重启应用
sudo systemctl restart fail2ban

# 验证配置
sudo fail2ban-client status sshd
```

### 场景6：保护多个服务

```bash
# 安装基础fail2ban
sudo ./ssh-security.sh
# 选择: 3

# 添加Nginx保护
sudo nano /etc/fail2ban/jail.local

# 添加以下内容：
[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 5
bantime = 1h

[nginx-noscript]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 6
bantime = 1h

# 重启fail2ban
sudo systemctl restart fail2ban

# 查看所有jail
sudo fail2ban-client status
```

### 场景7：配置邮件通知

```bash
# 安装邮件工具
sudo apt install mailutils -y

# 配置Postfix或使用SMTP

# 编辑fail2ban配置
sudo nano /etc/fail2ban/jail.local

# 添加邮件配置：
[DEFAULT]
destemail = admin@example.com
sendername = Fail2Ban-Server1
mta = sendmail

# 修改动作为发送邮件
action = %(action_mwl)s

# 重启fail2ban
sudo systemctl restart fail2ban

# 测试封禁以验证邮件
sudo fail2ban-client set sshd banip 8.8.8.8
# 检查邮箱是否收到通知
```

## 故障排除

### 场景8：被锁在外面的恢复

```bash
# 情况：修改SSH配置后无法登录

# 方法1：通过服务商控制台（VNC/Serial Console）
# 1. 登录服务商控制台
# 2. 使用VNC连接服务器
# 3. 以root登录
# 4. 运行脚本恢复配置

sudo ./ssh-security.sh
# 选择: 10
# 选择最近的sshd_config备份

# 方法2：手动恢复
sudo cp /root/ssh-security-backups/sshd_config.bak.* /etc/ssh/sshd_config
sudo systemctl restart sshd

# 方法3：临时启用密码登录
sudo nano /etc/ssh/sshd_config
# 修改: PasswordAuthentication yes
sudo systemctl restart sshd
```

### 场景9：fail2ban误封本地IP

```bash
# 发现无法SSH连接

# 方法1：通过VNC登录后解封
sudo fail2ban-client set sshd unbanip YOUR_IP

# 方法2：停止fail2ban
sudo systemctl stop fail2ban
# 现在可以登录了
ssh root@server_ip

# 登录后添加到白名单
sudo ./ssh-security.sh
# 选择: 9
# 添加你的IP

# 重启fail2ban
sudo systemctl start fail2ban

# 方法3：直接编辑iptables（紧急）
# 通过VNC登录
sudo iptables -L -n --line-numbers
# 找到封禁规则的行号
sudo iptables -D f2b-sshd 行号
```

### 场景10：SSH配置测试失败

```bash
# 运行语法检查
sudo sshd -t

# 常见错误1：端口冲突
# 错误: Bind to port 2222 on 0.0.0.0 failed
# 解决: 检查端口是否被占用
sudo netstat -tlnp | grep 2222
sudo lsof -i :2222

# 常见错误2：配置文件语法错误
# 错误: Bad configuration option
# 解决: 检查拼写和格式
sudo nano /etc/ssh/sshd_config

# 恢复工作配置
sudo ./ssh-security.sh
# 选择: 10
```

## 自动化部署

### 场景11：批量部署多台服务器

```bash
#!/bin/bash
# deploy_security.sh - 批量部署脚本

SERVERS=(
    "192.168.1.101"
    "192.168.1.102"
    "192.168.1.103"
)

for server in "${SERVERS[@]}"; do
    echo "配置服务器: $server"

    # 上传SSH密钥
    ssh-copy-id root@$server

    # 上传脚本
    scp ssh-security.sh root@$server:/tmp/

    # 执行配置（需要交互）
    ssh root@$server "bash /tmp/ssh-security.sh"

    echo "完成: $server"
    echo "---"
done
```

### 场景12：使用Ansible自动化

```yaml
# playbook.yml
---
- name: 配置SSH安全和fail2ban
  hosts: all
  become: yes

  tasks:
    - name: 确保SSH密钥已配置
      authorized_key:
        user: root
        key: "{{ lookup('file', '~/.ssh/id_ed25519.pub') }}"
        state: present

    - name: 下载安全配置脚本
      get_url:
        url: https://raw.githubusercontent.com/[用户名]/[仓库名]/main/ssh-security.sh
        dest: /tmp/ssh-security.sh
        mode: '0755'

    - name: 配置SSH (非交互模式需要修改脚本)
      shell: |
        # 这里需要非交互式版本的脚本
        echo "手动执行或修改脚本支持环境变量配置"
```

### 场景13：Docker容器中测试

```bash
# 创建测试环境
docker run -d --name ssh-test \
    -p 2222:22 \
    ubuntu:22.04 \
    sleep infinity

# 进入容器
docker exec -it ssh-test bash

# 安装必要工具
apt update
apt install openssh-server sudo curl -y

# 启动SSH
service ssh start

# 运行脚本测试
bash <(curl -s https://raw.githubusercontent.com/[用户名]/[仓库名]/main/ssh-security.sh)
```

### 场景14：Terraform自动化

```hcl
# main.tf
resource "null_resource" "security_config" {
  count = length(var.server_ips)

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("~/.ssh/id_ed25519")
    host        = var.server_ips[count.index]
  }

  provisioner "file" {
    source      = "ssh-security.sh"
    destination = "/tmp/ssh-security.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/ssh-security.sh",
      # 需要非交互式执行
      "# 手动执行或修改脚本"
    ]
  }
}
```

## 监控和维护

### 场景15：定期监控封禁情况

```bash
#!/bin/bash
# monitor_bans.sh - 每日监控脚本

LOG_FILE="/var/log/ban-monitor.log"
EMAIL="admin@example.com"

echo "=== $(date) ===" >> $LOG_FILE

# 获取封禁统计
banned_count=$(sudo fail2ban-client status sshd | grep "Currently banned" | awk '{print $NF}')

echo "当前封禁IP数量: $banned_count" >> $LOG_FILE

if [ $banned_count -gt 10 ]; then
    # 发送警告邮件
    sudo fail2ban-client status sshd | mail -s "警告: 封禁IP数量过多 ($banned_count)" $EMAIL
fi

# 记录详细信息
sudo fail2ban-client status sshd >> $LOG_FILE
```

### 场景16：设置定时任务

```bash
# 添加到crontab
crontab -e

# 每天凌晨2点检查
0 2 * * * /root/monitor_bans.sh

# 每周一清理旧备份（保留最近10个）
0 3 * * 1 cd /root/ssh-security-backups && ls -t | tail -n +11 | xargs rm -f

# 每月生成安全报告
0 4 1 * * /root/security_report.sh
```

## 🎓 学习参考

### 查看实际配置

```bash
# 查看当前SSH配置
cat /etc/ssh/sshd_config | grep -v "^#" | grep -v "^$"

# 查看fail2ban配置
cat /etc/fail2ban/jail.local

# 查看iptables规则
sudo iptables -L -n -v

# 查看活动连接
ss -tunap | grep :22
```

### 日志分析

```bash
# 查看成功登录
sudo grep "Accepted" /var/log/auth.log | tail -20

# 查看失败登录
sudo grep "Failed password" /var/log/auth.log | tail -20

# 统计攻击来源
sudo grep "Failed password" /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -nr

# 查看fail2ban封禁历史
sudo grep "Ban" /var/log/fail2ban.log | tail -20
```

## 💡 最佳实践总结

1. **始终在测试环境先测试**
2. **保持多个SSH会话打开**
3. **定期备份配置文件**
4. **记录所有修改**
5. **监控日志文件**
6. **定期更新系统**
7. **使用强密钥**
8. **配置白名单**

---

**更多示例和用例持续更新中...**

有问题？查看 [README.md](README.md) 或提交 [Issue](https://github.com/[用户名]/[仓库名]/issues)

