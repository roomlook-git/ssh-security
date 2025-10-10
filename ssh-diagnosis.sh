#!/bin/bash

# SSH 配置诊断脚本
# 用于诊断为什么 root 用户仍可以使用密码登录

echo "=========================================="
echo "SSH 配置诊断工具"
echo "=========================================="
echo

# 1. 检查当前生效的 SSH 配置
echo "【1】当前生效的 SSH 配置："
echo "-------------------------------------------"
sshd -T | grep -E "(passwordauthentication|permitrootlogin|pubkeyauthentication)"
echo

# 2. 检查所有配置文件
echo "【2】/etc/ssh/sshd_config.d/ 目录下的所有配置文件："
echo "-------------------------------------------"
if [[ -d "/etc/ssh/sshd_config.d" ]]; then
    ls -la /etc/ssh/sshd_config.d/*.conf 2>/dev/null | awk '{print $9}' | sort
else
    echo "目录不存在"
fi
echo

# 3. 检查每个配置文件中的关键配置
echo "【3】各配置文件中的认证相关设置："
echo "-------------------------------------------"
if [[ -d "/etc/ssh/sshd_config.d" ]]; then
    for file in /etc/ssh/sshd_config.d/*.conf; do
        if [[ -f "$file" ]]; then
            echo "文件: $file"
            grep -iE "^[[:space:]]*(PasswordAuthentication|PermitRootLogin|PubkeyAuthentication)" "$file" 2>/dev/null | sed 's/^/  /'
            if [[ $? -ne 0 ]]; then
                echo "  (无相关配置)"
            fi
            echo
        fi
    done
fi

# 4. 检查主配置文件
echo "【4】主配置文件 /etc/ssh/sshd_config 中的认证设置："
echo "-------------------------------------------"
grep -iE "^[[:space:]]*(PasswordAuthentication|PermitRootLogin|PubkeyAuthentication)" /etc/ssh/sshd_config 2>/dev/null | sed 's/^/  /'
if [[ $? -ne 0 ]]; then
    echo "  (无相关配置)"
fi
echo

# 5. 检查是否有 Match 块
echo "【5】检查是否存在 Match 条件块（可能覆盖全局配置）："
echo "-------------------------------------------"
grep -A 5 "^Match" /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null | grep -E "(Match|PasswordAuthentication|PermitRootLogin)" | sed 's/^/  /'
if [[ $? -ne 0 ]]; then
    echo "  (未发现 Match 块)"
fi
echo

# 6. 检查 PAM 配置
echo "【6】检查 PAM SSH 配置："
echo "-------------------------------------------"
if [[ -f "/etc/pam.d/sshd" ]]; then
    echo "PAM SSH 配置存在: /etc/pam.d/sshd"
    echo "  关键配置:"
    grep -v "^#" /etc/pam.d/sshd | grep -v "^$" | head -5 | sed 's/^/  /'
else
    echo "  PAM 配置文件不存在"
fi
echo

# 7. 建议修复方案
echo "=========================================="
echo "【诊断结果与修复建议】"
echo "=========================================="
echo

# 分析当前生效的配置
current_password_auth=$(sshd -T | grep "^passwordauthentication" | awk '{print $2}')
current_root_login=$(sshd -T | grep "^permitrootlogin" | awk '{print $2}')

echo "当前生效配置："
echo "  PasswordAuthentication: $current_password_auth"
echo "  PermitRootLogin: $current_root_login"
echo

if [[ "$current_password_auth" == "yes" ]] || [[ "$current_root_login" == "yes" ]] || [[ "$current_root_login" == "prohibit-password" && "$current_password_auth" == "yes" ]]; then
    echo "⚠️  问题确认：当前配置允许密码登录"
    echo
    echo "可能的原因："

    # 检查是否有冲突文件
    conflict_found=false
    if [[ -d "/etc/ssh/sshd_config.d" ]]; then
        for file in /etc/ssh/sshd_config.d/*.conf; do
            if [[ -f "$file" ]] && [[ "$file" != "/etc/ssh/sshd_config.d/99-security.conf" ]]; then
                if grep -qE "^[[:space:]]*(PasswordAuthentication|PermitRootLogin)" "$file" 2>/dev/null; then
                    if [[ "$conflict_found" == false ]]; then
                        echo "  1. 发现冲突的配置文件（按加载顺序）："
                        conflict_found=true
                    fi
                    echo "     - $(basename "$file")"
                fi
            fi
        done
    fi

    if [[ "$conflict_found" == true ]]; then
        echo
        echo "修复建议："
        echo "  选项1：删除或重命名冲突文件（推荐）"
        echo "    cd /etc/ssh/sshd_config.d/"
        echo "    # 备份冲突文件"
        echo "    for f in 0*.conf 5*.conf; do [[ -f \"\$f\" ]] && mv \"\$f\" \"\$f.disabled\"; done"
        echo
        echo "  选项2：重命名我们的配置文件，使其优先加载"
        echo "    mv /etc/ssh/sshd_config.d/99-security.conf /etc/ssh/sshd_config.d/00-security.conf"
        echo
        echo "  选项3：直接修改主配置文件（适用于无法删除 drop-in 的情况）"
        echo "    编辑 /etc/ssh/sshd_config"
        echo "    在文件最开始添加："
        echo "      PasswordAuthentication no"
        echo "      PermitRootLogin prohibit-password"
        echo
    else
        echo "  未发现明显冲突的 drop-in 配置文件"
        echo "  可能是主配置文件或 Match 块的问题"
    fi

    echo "修复后请执行："
    echo "  sshd -t                    # 检查配置语法"
    echo "  systemctl restart sshd     # 重启 SSH 服务"
    echo "  sshd -T | grep -E '(passwordauthentication|permitrootlogin)'  # 验证配置"
else
    echo "✓ 配置正常：密码认证已正确禁用"
    echo
    echo "如果仍能用密码登录，请检查："
    echo "  1. 是否重启了 SSH 服务"
    echo "  2. 是否连接到了正确的服务器和端口"
    echo "  3. SSH 客户端是否有本地配置覆盖"
fi

echo
echo "=========================================="

