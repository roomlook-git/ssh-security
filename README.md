# VPS SSH & Fail2ban 安全配置脚本

一个功能完整、交互友好的 VPS 服务器安全配置自动化脚本，帮助你快速配置 SSH 密钥登录和 fail2ban 防护。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

## ✨ 功能特性

### 核心功能（7个）

1. **检查 SSH 密钥配置** - 自动检测密钥配置，生成测试连接命令
2. **禁用密码登录** - 仅允许密钥登录，完全禁止 root 用户登录
3. **一键安装配置 fail2ban** - 自动安装并配置最佳安全策略
4. **查看 fail2ban 状态** - 实时监控所有 jail 状态
5. **手动封禁 IP** - 快速封禁恶意 IP 地址
6. **手动解封 IP** - 解除误封或临时封禁
7. **查看封禁列表** - 查看所有被封禁的 IP 和统计信息

### 扩展功能（3个）

8. **查看 fail2ban 日志** - 彩色高亮显示关键日志，支持实时监控
9. **添加信任 IP 到白名单** - 防止重要 IP 被误封
10. **恢复配置备份** - 一键恢复之前的配置

### 安全特性

- ✅ **双重确认** - 所有危险操作都需要输入 `yes` 确认
- ✅ **自动备份** - 修改配置前自动备份，带时间戳
- ✅ **语法检查** - 配置修改后自动检查语法再重启服务
- ✅ **错误处理** - 完善的错误检查和提示
- ✅ **日志记录** - 所有操作记录到 `/var/log/ssh-security-script.log`
- ✅ **回滚机制** - 提供快速恢复配置的功能

## 🚀 快速开始

### 方式一：一键运行（推荐）

```bash
bash <(curl -s https://raw.githubusercontent.com/roomlook-git/ssh-security/main/ssh-security.sh)
```

### 方式二：下载后运行

```bash
# 下载脚本
curl -O https://raw.githubusercontent.com/roomlook-git/ssh-security/main/ssh-security.sh

# 添加执行权限
chmod +x ssh-security.sh

# 运行脚本
sudo ./ssh-security.sh
```

### 方式三：使用 wget

```bash
wget https://raw.githubusercontent.com/roomlook-git/ssh-security/main/ssh-security.sh
chmod +x ssh-security.sh
sudo ./ssh-security.sh
```

## 📋 系统要求

- **操作系统**: Ubuntu 18.04+ 或 Debian 10+
- **权限**: Root 权限（或使用 sudo）
- **网络**: 需要联网（用于安装 fail2ban）
- **前置条件**: 配置 SSH 密钥（执行功能2前必需）

## 📖 使用指南

### 推荐配置流程

```
1. 检查 SSH 密钥配置 (功能1)
   ↓
2. 在新终端测试密钥登录
   ↓
3. 禁用密码登录 (功能2)
   ↓
4. 再次测试登录确保正常
   ↓
5. 安装配置 fail2ban (功能3)
   ↓
6. 定期使用功能4-7监控和管理
```

### 详细功能说明

#### 功能1：检查 SSH 密钥配置

- 检查 `~/.ssh/authorized_keys` 文件
- 统计密钥数量，显示密钥类型和注释
- 自动获取服务器公网 IP
- 检测当前 SSH 端口
- 生成 Windows/Linux/Mac 测试命令

**示例输出：**
```
找到 2 个SSH密钥
密钥详情：
  1. 类型: ssh-ed25519, 注释: user@laptop
  2. 类型: ssh-rsa, 注释: user@desktop

Windows PowerShell 测试命令：
ssh -i ~/.ssh/id_ed25519 root@1.2.3.4 -p 22
```

#### 功能2：禁用密码登录

- 自动检查是否已配置 SSH 密钥
- 备份当前 `sshd_config`
- 询问是否修改 SSH 端口
- 生成安全的 SSH 配置
- 检查配置语法
- 友好提示并等待确认后重启

**配置效果：**
- ❌ 完全禁止密码登录
- ✅ 仅允许密钥认证
- ✅ 限制最大认证尝试次数（3次）
- ✅ 优化连接性能（禁用 DNS 反查）

#### 功能3：一键安装配置 fail2ban

- 自动检测并安装 fail2ban
- 提示输入要保护的端口（支持多端口）
- 创建优化的 fail2ban 配置
- 启用 `sshd` 和 `recidive` jail

**默认配置：**
```ini
失败尝试次数: 3次
检测时间窗口: 10分钟
初次封禁时间: 24小时
递增封禁倍数: 2倍
最长封禁时间: 168小时（7天）
```

**Recidive 保护：**
对于重复攻击的 IP，自动触发更长时间的封禁（7天）

#### 功能4-7：fail2ban 管理

**功能4** - 查看所有 jail 的详细状态和统计信息
**功能5** - 手动封禁指定 IP（带格式验证）
**功能6** - 手动解封 IP，会先显示当前封禁列表
**功能7** - 查看所有 jail 的封禁统计和 IP 列表

#### 功能8：查看日志

- 显示最近 50 条日志记录
- 彩色高亮关键词（封禁/解封/错误）
- 可选实时监控模式

#### 功能9：添加信任 IP

- 显示当前白名单
- 添加信任 IP 或 IP 段到白名单
- 自动重启 fail2ban 生效

**示例：**
```
添加单个 IP: 192.168.1.100
添加 IP 段: 192.168.1.0/24
```

#### 功能10：恢复配置

- 列出所有带时间戳的备份文件
- 选择要恢复的备份
- 自动识别配置类型并重启相应服务

## 📁 文件位置

| 类型 | 路径 |
|------|------|
| SSH 配置 | `/etc/ssh/sshd_config` |
| fail2ban 配置 | `/etc/fail2ban/jail.local` |
| 脚本日志 | `/var/log/ssh-security-script.log` |
| fail2ban 日志 | `/var/log/fail2ban.log` |
| SSH 认证日志 | `/var/log/auth.log` |
| 备份目录 | `/root/ssh-security-backups/` |

## ⚠️ 重要提示

### 执行功能2前必读

1. **务必先配置 SSH 密钥** - 使用功能1检查确认
2. **保持当前 SSH 会话** - 修改 SSH 配置时不要关闭当前连接
3. **在新终端测试** - 重启 SSH 前在新终端测试密钥登录
4. **记录端口号** - 如果修改了端口，务必记录新端口号
5. **防火墙配置** - 修改端口后确保防火墙已开放新端口



## 🔧 常见问题

### Q1: 执行功能2后无法登录怎么办？

**A:** 如果你还保持着原来的 SSH 会话：

1. 使用功能10恢复最近的备份
2. 或手动编辑：`nano /etc/ssh/sshd_config`
3. 临时启用密码登录：`PasswordAuthentication yes`
4. 重启 SSH：`systemctl restart sshd`

**如果完全无法登录：**
- 联系服务器提供商，使用 VNC 或控制台登录
- 恢复配置文件或重置系统

### Q2: 修改端口后无法连接

**A:** 检查以下几点：

1. **防火墙** - 确保新端口已开放
   ```bash
   # UFW
   sudo ufw allow 新端口/tcp

   # iptables
   sudo iptables -A INPUT -p tcp --dport 新端口 -j ACCEPT
   ```

2. **连接命令** - 使用 `-p` 参数指定端口
   ```bash
   ssh -i ~/.ssh/id_ed25519 user@ip -p 新端口
   ```

3. **云服务商安全组** - 在控制台添加端口规则

### Q3: fail2ban 不生效

**A:** 检查步骤：

1. 检查服务状态：`systemctl status fail2ban`
2. 查看配置语法：`fail2ban-client -d`
3. 检查日志：`tail -f /var/log/fail2ban.log`
4. 确认 jail 已启用：`fail2ban-client status`

### Q4: 如何解除自己的 IP 被封禁

**A:**

1. 通过 VNC 或控制台登录服务器
2. 运行脚本，使用功能6手动解封
3. 或直接命令：`fail2ban-client set sshd unbanip 你的IP`

### Q5: 如何添加自己的 IP 到白名单

**A:**

使用功能9添加，或手动编辑 `/etc/fail2ban/jail.local`：
```ini
ignoreip = 127.0.0.1/8 ::1 你的IP
```
然后重启：`systemctl restart fail2ban`

### Q6: 配置了密钥但功能1检测不到

**A:** 检查：

1. 文件权限：
   ```bash
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/authorized_keys
   ```

2. 文件所有者：
   ```bash
   chown -R root:root /root/.ssh
   ```

3. 密钥格式是否正确（以 `ssh-rsa` 或 `ssh-ed25519` 开头）

## 🔐 安全建议

1. **定期更新系统**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **启用自动安全更新**
   ```bash
   sudo apt install unattended-upgrades -y
   sudo dpkg-reconfigure -plow unattended-upgrades
   ```

3. **使用强密钥**
   - 推荐 ED25519：`ssh-keygen -t ed25519`
   - RSA 至少 4096 位：`ssh-keygen -t rsa -b 4096`

4. **定期检查日志**
   ```bash
   # 查看 fail2ban 封禁记录
   sudo ./ssh-security.sh  # 使用功能7和8

   # 查看 SSH 登录记录
   sudo grep 'Accepted' /var/log/auth.log
   ```

5. **备份配置文件**
   - 脚本会自动备份到 `/root/ssh-security-backups/`
   - 建议定期下载到本地保存

6. **使用非标准端口**
   - 虽然不能完全防止攻击，但可以大幅减少扫描
   - 推荐范围：10000-65535

7. **配置防火墙**
   ```bash
   # 使用 UFW（推荐）
   sudo apt install ufw -y
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   sudo ufw allow 你的SSH端口/tcp
   sudo ufw enable
   ```

## 📊 fail2ban 配置详解

### 关键参数说明

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `maxretry` | 3 | 失败尝试次数阈值 |
| `findtime` | 10m | 检测时间窗口 |
| `bantime` | 24h | 初次封禁时间 |
| `bantime.increment` | true | 启用递增封禁 |
| `bantime.factor` | 2 | 封禁时间倍增因子 |
| `bantime.maxtime` | 168h | 最长封禁时间（7天） |

### 封禁策略示例

假设某 IP 多次攻击：

1. **第1次封禁**：24小时
2. **第2次封禁**：48小时（24 × 2）
3. **第3次封禁**：96小时（48 × 2）
4. **第4次封禁**：168小时（达到上限）
5. **触发 recidive**：直接封禁168小时

### 查看封禁统计

```bash
# 查看 sshd jail 统计
sudo fail2ban-client status sshd

# 查看所有被封禁的 IP
sudo iptables -L -n | grep REJECT

# 查看 fail2ban 数据库
sudo fail2ban-client get sshd actions
```

## 🛠️ 高级配置

### 自定义封禁时间

编辑 `/etc/fail2ban/jail.local`：

```ini
[sshd]
# 更严格：3次失败封禁48小时
maxretry = 3
bantime = 48h

# 更宽松：5次失败封禁12小时
maxretry = 5
bantime = 12h
```

### 添加邮件通知

1. 安装邮件工具：
   ```bash
   sudo apt install mailutils -y
   ```

2. 编辑配置：
   ```ini
   [DEFAULT]
   destemail = your@email.com
   sendername = Fail2Ban
   action = %(action_mwl)s
   ```

### 保护其他服务

在 `/etc/fail2ban/jail.local` 添加：

```ini
# 保护 Nginx
[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

# 保护 MySQL
[mysqld-auth]
enabled = true
port = 3306
logpath = /var/log/mysql/error.log
```

## 📝 更新日志

### v1.0.0 (2024-01-01)

- ✨ 初始版本发布
- ✅ 10个核心功能完整实现
- ✅ 彩色交互式菜单
- ✅ 完善的错误处理和日志记录
- ✅ 自动备份和恢复功能
- ✅ 详细的使用文档

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

### 开发计划

- [ ] 支持 CentOS/RHEL 系统
- [ ] 添加邮件通知功能
- [ ] Web 界面管理
- [ ] 支持更多服务保护（Nginx、MySQL等）
- [ ] 多语言支持（English）

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE)

## ⚡ 致谢

感谢所有为服务器安全做出贡献的开源项目和社区成员。

## 📮 联系方式

- 提交 Issue: [GitHub Issues](https://github.com/roomlook-git/ssh-security/issues)
- Pull Request: [GitHub PR](https://github.com/roomlook-git/ssh-security/pulls)

---

**⭐ 如果这个脚本对你有帮助，请给个 Star！**

**🔒 保护你的服务器，从配置开始！**

