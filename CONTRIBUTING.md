# 贡献指南

感谢你考虑为 VPS SSH & Fail2ban 安全配置脚本做出贡献！

## 🤝 如何贡献

### 报告问题

如果你发现了bug或有功能建议：

1. 在提交前搜索现有的 [Issues](https://github.com/[用户名]/[仓库名]/issues)
2. 如果没有找到相关问题，创建新的 Issue
3. 使用清晰的标题和详细的描述
4. 包含复现步骤（如果是bug）
5. 包含系统信息（OS、版本等）

### 提交代码

1. **Fork 仓库**

2. **创建特性分支**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **进行修改**
   - 遵循现有代码风格
   - 添加注释说明复杂逻辑
   - 确保代码可读性

4. **测试修改**
   ```bash
   # 检查语法
   bash -n ssh-security.sh

   # 在测试环境运行
   sudo ./ssh-security.sh
   ```

5. **提交更改**
   ```bash
   git add .
   git commit -m "feat: 添加新功能描述"
   ```

6. **推送到 Fork**
   ```bash
   git push origin feature/your-feature-name
   ```

7. **创建 Pull Request**
   - 描述你的更改
   - 引用相关的 Issue
   - 等待审核

## 📝 代码风格

### Bash 脚本规范

1. **使用 `set -euo pipefail`**
   ```bash
   set -euo pipefail
   ```

2. **函数命名**
   - 使用小写字母和下划线
   - 描述性命名
   ```bash
   check_ssh_keys() {
       # 函数体
   }
   ```

3. **变量命名**
   - 常量使用大写：`readonly SSH_CONFIG="/etc/ssh/sshd_config"`
   - 局部变量使用小写：`local user_input`

4. **注释**
   ```bash
   # 单行注释说明下面代码的作用

   # 多行注释说明复杂逻辑
   # 第二行
   # 第三行
   ```

5. **错误处理**
   ```bash
   if ! command_that_might_fail; then
       print_error "错误信息"
       return 1
   fi
   ```

6. **引用变量**
   - 始终使用双引号：`"$variable"`
   - 避免未引用的变量扩展

### 提交信息规范

使用语义化的提交信息：

```
feat: 添加新功能
fix: 修复bug
docs: 文档更新
style: 代码格式（不影响功能）
refactor: 重构代码
test: 添加测试
chore: 构建过程或辅助工具的变动
```

示例：
```
feat: 添加自动检测系统架构功能
fix: 修复SSH端口检测错误
docs: 更新README中的安装说明
```

## 🧪 测试

### 测试环境

推荐使用虚拟机或容器测试：

```bash
# 使用 Docker
docker run -it --rm ubuntu:22.04 bash

# 或使用虚拟机（VirtualBox、VMware等）
```

### 测试清单

在提交 PR 前，请确保：

- [ ] 代码语法检查通过：`bash -n ssh-security.sh`
- [ ] 在 Ubuntu 22.04 上测试通过
- [ ] 在 Debian 11 上测试通过（如果可能）
- [ ] 所有功能菜单可以正常访问
- [ ] 错误处理正常工作
- [ ] 备份和恢复功能正常
- [ ] 不会破坏现有功能
- [ ] 文档已更新（如果添加新功能）

### 功能测试

```bash
# 1. 测试菜单系统
sudo ./ssh-security.sh
# 输入 0-10 确保所有选项可访问

# 2. 测试SSH密钥检查
# 选择功能1

# 3. 测试fail2ban（需要安装）
# 选择功能3、4、7

# 4. 测试备份恢复
# 选择功能10
```

## 🎯 开发优先级

### 高优先级

- [ ] 支持 CentOS/RHEL 系统
- [ ] 改进错误提示信息
- [ ] 添加更多安全检查

### 中优先级

- [ ] 添加邮件通知功能
- [ ] 支持更多语言（英语）
- [ ] 添加配置导入/导出

### 低优先级

- [ ] Web 界面
- [ ] 图形化统计
- [ ] 插件系统

## 📚 文档贡献

文档同样重要！你可以：

- 修正拼写和语法错误
- 改进现有文档的清晰度
- 添加使用示例
- 翻译文档到其他语言
- 添加常见问题解答

## 🐛 Bug 修复流程

1. 确认 bug 存在
2. 创建 Issue（如果没有）
3. 在 Issue 中说明你正在处理
4. 创建分支：`git checkout -b fix/bug-description`
5. 修复并测试
6. 提交 PR，引用 Issue

## ✨ 新功能开发流程

1. 在 Issue 中讨论新功能
2. 获得维护者同意后开始开发
3. 创建分支：`git checkout -b feature/feature-name`
4. 实现功能
5. 添加文档
6. 测试
7. 提交 PR

## 🔍 代码审查

所有 PR 都会经过审查，可能会要求：

- 代码风格调整
- 添加注释
- 改进错误处理
- 添加测试
- 更新文档

请耐心等待反馈并积极回应。

## 📧 联系方式

- GitHub Issues: 技术问题和bug报告
- Pull Requests: 代码贡献
- Discussions: 功能讨论和建议

## 🙏 感谢

感谢每一位贡献者！你的帮助让这个项目变得更好。

### 贡献者列表

- [贡献者1](https://github.com/contributor1)
- [贡献者2](https://github.com/contributor2)

（你的名字也可以出现在这里！）

## 📜 行为准则

- 尊重所有贡献者
- 提供建设性的反馈
- 关注代码而非个人
- 保持友好和专业

---

**再次感谢你的贡献！🎉**

