# 项目结构说明

## 📁 文件组织

```
ssh-security-script/
├── ssh-security.sh          # 主脚本文件（可执行）
├── README.md                # 项目主文档
├── QUICKSTART.md            # 快速开始指南
├── EXAMPLES.md              # 使用示例集合
├── CONTRIBUTING.md          # 贡献指南
├── CHANGELOG.md             # 版本更新日志
├── LICENSE                  # MIT 开源许可证
├── .gitignore              # Git 忽略规则
└── PROJECT_STRUCTURE.md    # 本文件（项目结构说明）
```

## 📄 文件说明

### 核心文件

#### `ssh-security.sh`
**主脚本文件** - 约700行

包含10个主要功能：
- 交互式菜单系统
- SSH密钥检查和配置
- fail2ban 自动安装和配置
- IP封禁管理
- 配置备份和恢复

**依赖：**
- bash 4.0+
- systemd
- apt (Debian/Ubuntu)
- 标准Unix工具 (grep, awk, sed等)

**权限要求：**
- 必须以 root 权限运行

### 文档文件

#### `README.md`
**主文档** - 约300行

包含内容：
- 项目介绍和特性
- 安装方法
- 完整使用指南
- 常见问题解答
- 安全建议
- fail2ban 配置详解

**目标读者：** 所有用户

#### `QUICKSTART.md`
**快速开始指南** - 约200行

包含内容：
- 5分钟快速配置流程
- 步骤化操作指南
- 常用命令速查
- 紧急情况处理
- 移动设备连接

**目标读者：** 新手用户

#### `EXAMPLES.md`
**使用示例** - 约400行

包含内容：
- 15个实际使用场景
- 高级配置示例
- 故障排除案例
- 自动化部署示例
- 监控和维护脚本

**目标读者：** 进阶用户

#### `CONTRIBUTING.md`
**贡献指南** - 约150行

包含内容：
- 如何报告问题
- 代码贡献流程
- 代码风格规范
- 测试要求
- PR 提交标准

**目标读者：** 开发者和贡献者

#### `CHANGELOG.md`
**更新日志** - 持续更新

记录内容：
- 版本历史
- 功能变更
- Bug 修复记录
- 升级指南

**目标读者：** 所有用户

### 配置文件

#### `LICENSE`
**开源许可证** - MIT License

允许：
- ✅ 商业使用
- ✅ 修改
- ✅ 分发
- ✅ 私人使用

要求：
- ⚠️ 保留许可证和版权声明

#### `.gitignore`
**Git 忽略规则**

忽略文件：
- 备份文件 (*.bak)
- 日志文件 (*.log)
- 临时文件
- IDE 配置

## 🔄 脚本内部结构

### ssh-security.sh 模块划分

```
ssh-security.sh
│
├── 头部声明
│   ├── Shebang (#!)
│   ├── 脚本信息注释
│   └── set -euo pipefail
│
├── 全局变量定义
│   ├── 路径常量
│   ├── 颜色定义
│   └── 配置变量
│
├── 工具函数模块 (约150行)
│   ├── 日志记录 (log)
│   ├── 彩色输出 (print_*)
│   ├── 确认提示 (confirm)
│   ├── 系统检测 (detect_system)
│   ├── 备份管理 (backup_file)
│   ├── IP验证 (validate_ip)
│   └── SSH服务管理
│
├── 功能1：检查SSH密钥 (约80行)
│   ├── 检查 authorized_keys
│   ├── 统计和显示密钥
│   ├── 获取服务器信息
│   └── 生成测试命令
│
├── 功能2：禁用密码登录 (约120行)
│   ├── 前置检查
│   ├── 端口配置询问
│   ├── 备份旧配置
│   ├── 生成新配置
│   ├── 语法检查
│   └── 重启SSH服务
│
├── 功能3：安装fail2ban (约90行)
│   ├── 检测和安装
│   ├── 端口配置询问
│   ├── 生成配置文件
│   ├── 语法检查
│   └── 启动服务
│
├── 功能4：查看状态 (约40行)
│   ├── 服务检查
│   ├── 获取jail列表
│   └── 显示详细状态
│
├── 功能5：手动封禁 (约60行)
│   ├── 选择jail
│   ├── 输入IP验证
│   ├── 执行封禁
│   └── 显示结果
│
├── 功能6：手动解封 (约60行)
│   ├── 显示已封禁IP
│   ├── 选择要解封的IP
│   ├── 执行解封
│   └── 确认结果
│
├── 功能7：查看封禁列表 (约50行)
│   ├── 遍历所有jail
│   ├── 获取统计信息
│   └── 格式化显示
│
├── 功能8：查看日志 (约50行)
│   ├── 读取日志文件
│   ├── 彩色高亮显示
│   └── 可选实时监控
│
├── 功能9：添加白名单 (约60行)
│   ├── 显示当前白名单
│   ├── 输入新IP
│   ├── 修改配置
│   └── 重启服务
│
├── 功能10：恢复备份 (约70行)
│   ├── 列出备份文件
│   ├── 选择要恢复的备份
│   ├── 恢复文件
│   └── 重启相应服务
│
├── 主菜单 (约30行)
│   └── 循环显示菜单
│
└── 主程序 (约40行)
    ├── 初始化检查
    ├── 创建日志
    └── 菜单循环
```

## 🗂️ 运行时生成的文件

### 在服务器上创建的文件和目录

```
/root/ssh-security-backups/
├── sshd_config.bak.20240101_120000
├── sshd_config.bak.20240115_140000
├── jail.local.bak.20240101_123000
└── jail.conf.bak.20240101_123000

/var/log/
├── ssh-security-script.log      # 脚本操作日志
├── fail2ban.log                 # fail2ban日志
└── auth.log                     # SSH认证日志

/etc/ssh/
└── sshd_config                  # SSH配置（被修改）

/etc/fail2ban/
└── jail.local                   # fail2ban配置（新建）
```

## 📊 代码统计

### 脚本统计

```
文件：ssh-security.sh
- 总行数：约 700 行
- 代码行数：约 550 行
- 注释行数：约 100 行
- 空行：约 50 行
- 函数数量：约 25 个
- 功能模块：10 个
```

### 文档统计

```
总文档量：约 1500 行

README.md：         300 行
QUICKSTART.md：     200 行
EXAMPLES.md：       400 行
CONTRIBUTING.md：   150 行
CHANGELOG.md：      100 行
PROJECT_STRUCTURE： 150 行（本文件）
其他：              200 行
```

## 🔧 技术栈

### Shell 脚本
- Bash 4.0+
- POSIX 兼容

### 系统工具
- systemd/systemctl
- apt/apt-get
- iptables
- grep/awk/sed

### 安全工具
- OpenSSH
- fail2ban
- iptables

## 📦 发布文件

### GitHub Release 包含

```
ssh-security-v1.0.0.tar.gz
├── ssh-security.sh
├── README.md
├── QUICKSTART.md
├── LICENSE
└── CHANGELOG.md
```

### 下载方式

```bash
# 方式1：直接下载主脚本
curl -O https://raw.githubusercontent.com/roomlook-git/ssh-security/main/ssh-security.sh

# 方式2：克隆整个仓库
git clone https://github.com/roomlook-git/ssh-security.git

# 方式3：下载发布包
wget https://github.com/roomlook-git/ssh-security/releases/download/v1.0.0/ssh-security-v1.0.0.tar.gz
```

## 🎯 使用流程

### 用户角度

```
1. 下载脚本
   ↓
2. 添加执行权限
   ↓
3. 以 root 运行
   ↓
4. 选择功能
   ↓
5. 按提示操作
   ↓
6. 完成配置
```

### 脚本内部流程

```
启动
  ↓
检查 root 权限
  ↓
检测系统类型
  ↓
创建备份目录
  ↓
显示主菜单 ←─┐
  ↓          │
用户选择     │
  ↓          │
执行功能     │
  ↓          │
显示结果     │
  ↓          │
等待继续─────┘
  ↓
退出
```

## 🔐 安全考虑

### 脚本安全

- ✅ 不存储密码
- ✅ 不传输敏感信息
- ✅ 所有操作需要确认
- ✅ 完整的日志记录
- ✅ 自动备份机制

### 下载安全

建议验证脚本内容：

```bash
# 下载后检查
cat ssh-security.sh | less

# 或先查看不运行
curl -s https://raw.githubusercontent.com/roomlook-git/ssh-security/main/ssh-security.sh | less
```

## 📈 维护说明

### 版本控制

- 使用语义化版本号
- 主分支：`main`
- 开发分支：`develop`
- 功能分支：`feature/*`
- 修复分支：`fix/*`

### 更新流程

1. 在 `develop` 分支开发
2. 测试完成后合并到 `main`
3. 打标签发布
4. 更新 CHANGELOG.md

## 🤝 贡献

查看 [CONTRIBUTING.md](CONTRIBUTING.md)

## 📞 支持

- Issues: 报告问题
- Pull Requests: 贡献代码
- Discussions: 讨论功能

---

**文档版本：** 1.0.0
**最后更新：** 2024-01-01

