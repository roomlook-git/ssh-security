#!/bin/bash
#
# VPS SSH & Fail2ban 安全配置工具
# 作者: AI Assistant
# 版本: 1.0.0
# 描述: 自动化配置SSH密钥登录和fail2ban防护
#

set -euo pipefail

# ==================== 全局变量 ====================
readonly SCRIPT_NAME="SSH安全配置工具"
readonly SCRIPT_VERSION="1.0.0"
readonly LOG_FILE="/var/log/ssh-security-script.log"
readonly SSHD_CONFIG="/etc/ssh/sshd_config"
readonly SSHD_CONFIG_DIR="/etc/ssh/sshd_config.d"
readonly SSHD_SECURITY_CONF="/etc/ssh/sshd_config.d/99-security.conf"
readonly FAIL2BAN_JAIL="/etc/fail2ban/jail.local"
readonly BACKUP_DIR="/root/ssh-security-backups"

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# ==================== 工具函数 ====================

# 日志记录函数
log() {
    local level="$1"
    shift
    local message="$*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

# 彩色输出函数
print_success() {
    echo -e "${GREEN}✓ $*${NC}"
    log "SUCCESS" "$*"
}

print_error() {
    echo -e "${RED}✗ $*${NC}"
    log "ERROR" "$*"
}

print_warning() {
    echo -e "${YELLOW}⚠ $*${NC}"
    log "WARNING" "$*"
}

print_info() {
    echo -e "${BLUE}ℹ $*${NC}"
    log "INFO" "$*"
}

# 分隔线
print_separator() {
    echo -e "${BLUE}================================================${NC}"
}

# 确认函数
confirm() {
    local prompt="$1"
    local response
    while true; do
        echo -e "${YELLOW}$prompt (输入 yes/y 继续, no/n 取消): ${NC}"
        read -r response
        # 转换为小写
        response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
        if [[ "$response" =~ ^(yes|y)$ ]]; then
            return 0
        elif [[ "$response" =~ ^(no|n)$ ]]; then
            return 1
        else
            print_warning "请输入 yes/y 或 no/n"
        fi
    done
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本必须以root权限运行"
        print_info "请使用: sudo $0"
        exit 1
    fi
}

# 检测系统类型
detect_system() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=${ID:-unknown}
        VER=${VERSION_ID:-unknown}
    else
        print_error "无法检测系统类型"
        exit 1
    fi

    if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
        print_warning "检测到非Ubuntu/Debian系统: $OS $VER"
        print_warning "脚本主要针对Ubuntu/Debian设计，可能无法正常工作"
        echo
        if ! confirm "确认继续执行？"; then
            print_info "已取消执行"
            exit 1
        fi
        echo
    else
        print_success "系统检测: $OS $VER"
    fi
}

# 创建备份目录
create_backup_dir() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        print_success "创建备份目录: $BACKUP_DIR"
    fi
}

# 备份文件
backup_file() {
    local file="$1"
    local backup_name

    if [[ ! -f "$file" ]]; then
        print_warning "文件不存在，无需备份: $file"
        return 1
    fi

    backup_name="$(basename "$file").bak.$(date +%Y%m%d_%H%M%S)"
    cp "$file" "$BACKUP_DIR/$backup_name"
    print_success "已备份: $file -> $BACKUP_DIR/$backup_name"
    return 0
}

# IP地址格式验证
validate_ip() {
    local ip="$1"
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

    if [[ ! $ip =~ $regex ]]; then
        return 1
    fi

    local IFS='.'
    local -a octets=($ip)
    for octet in "${octets[@]}"; do
        if ((octet > 255)); then
            return 1
        fi
    done

    return 0
}

# 获取服务器公网IP
get_public_ip() {
    local ip

    # 尝试多个服务
    ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || \
         curl -s --max-time 5 icanhazip.com 2>/dev/null || \
         curl -s --max-time 5 ipinfo.io/ip 2>/dev/null || \
         echo "无法获取")

    echo "$ip"
}

# 获取当前SSH端口
get_ssh_port() {
    local port

    # 优先使用sshd -T命令（更可靠）
    port=$(sshd -T 2>/dev/null | grep "^port " | awk '{print $2}' | head -1 || true)

    # 如果失败，尝试从配置文件读取（只取第一个匹配）
    if [[ -z "$port" ]] && [[ -f "$SSHD_CONFIG" ]]; then
        port=$(grep -E "^Port\s+" "$SSHD_CONFIG" | awk '{print $2}' | head -1 || true)
    fi

    # 默认端口
    if [[ -z "$port" ]]; then
        port=22
    fi

    # 清理可能的空白字符并只返回第一个值
    port=$(echo "$port" | tr -d '[:space:]' | head -c 10)
    echo "$port"
}

# 检查SSH服务状态
check_ssh_service() {
    if systemctl is-active --quiet sshd || systemctl is-active --quiet ssh; then
        return 0
    else
        return 1
    fi
}

# 重启SSH服务
restart_ssh() {
    local service_name=""

    # 方法1: 检查 unit-files（最可靠）
    if systemctl list-unit-files 2>/dev/null | grep -q "^sshd.service"; then
        service_name="sshd"
    elif systemctl list-unit-files 2>/dev/null | grep -q "^ssh.service"; then
        service_name="ssh"
    # 方法2: 尝试检查服务状态
    elif systemctl status sshd &>/dev/null || systemctl is-enabled sshd &>/dev/null; then
        service_name="sshd"
    elif systemctl status ssh &>/dev/null || systemctl is-enabled ssh &>/dev/null; then
        service_name="ssh"
    # 方法3: 检查进程
    elif pgrep -x "sshd" &>/dev/null; then
        service_name="sshd"
    else
        print_error "无法找到SSH服务"
        print_info "尝试查看系统服务列表："
        systemctl list-unit-files | grep -i ssh || true
        return 1
    fi

    print_info "检测到SSH服务: $service_name"

    # 执行重启
    if systemctl restart "$service_name" 2>&1; then
        print_success "SSH服务已重启"
        return 0
    else
        print_error "SSH服务重启失败"
        print_info "查看服务状态："
        systemctl status "$service_name" --no-pager -l || true
        return 1
    fi
}

# ==================== 功能1: 检查SSH密钥配置 ====================
check_ssh_keys() {
    print_separator
    print_info "检查SSH密钥配置..."
    echo

    local authorized_keys_file
    local key_count=0
    local current_user

    # 确定当前用户和authorized_keys文件位置
    if [[ $EUID -eq 0 ]]; then
        current_user="root"
        authorized_keys_file="/root/.ssh/authorized_keys"
    else
        current_user="$USER"
        authorized_keys_file="$HOME/.ssh/authorized_keys"
    fi

    # 检查文件是否存在
    if [[ ! -f "$authorized_keys_file" ]]; then
        print_error "未找到SSH密钥文件: $authorized_keys_file"
        echo
        print_warning "请先配置SSH密钥："
        print_info "1. 在本地生成密钥: ssh-keygen -t ed25519"
        print_info "2. 上传到服务器: ssh-copy-id $current_user@服务器IP"
        echo
        return 1
    fi

    # 检查 .ssh 目录权限
    local ssh_dir="$(dirname "$authorized_keys_file")"
    local ssh_dir_perms=$(stat -c "%a" "$ssh_dir" 2>/dev/null)
    if [[ "$ssh_dir_perms" != "700" ]]; then
        print_warning ".ssh 目录权限不正确: $ssh_dir_perms (应为 700)"
        print_info "修复命令: chmod 700 $ssh_dir"
        echo
        if confirm "是否自动修复权限？"; then
            chmod 700 "$ssh_dir"
            print_success ".ssh 目录权限已修复"
        fi
        echo
    else
        print_success ".ssh 目录权限正确: 700"
    fi

    # 检查 authorized_keys 文件权限
    local file_perms=$(stat -c "%a" "$authorized_keys_file" 2>/dev/null)
    if [[ "$file_perms" != "600" ]]; then
        print_warning "authorized_keys 文件权限不正确: $file_perms (应为 600)"
        print_info "修复命令: chmod 600 $authorized_keys_file"
        echo
        if confirm "是否自动修复权限？"; then
            chmod 600 "$authorized_keys_file"
            print_success "authorized_keys 文件权限已修复"
        fi
        echo
    else
        print_success "authorized_keys 文件权限正确: 600"
    fi

    echo

    # 统计密钥数量（支持所有密钥类型）
    # 匹配: ssh-rsa, ssh-dss, ssh-ed25519, ecdsa-sha2-*, sk-ssh-*, sk-ecdsa-*
    key_count=$(grep -cE "^(ssh-|ecdsa-sha2-|sk-ssh-|sk-ecdsa-)" "$authorized_keys_file" 2>/dev/null || echo "0")

    if [[ $key_count -eq 0 ]]; then
        print_error "authorized_keys文件存在但没有有效的密钥"
        return 1
    fi

    print_success "找到 $key_count 个SSH密钥"
    echo

    # 显示密钥信息
    print_info "密钥详情："
    local line_num=0
    while IFS= read -r line; do
        # 匹配所有合法的密钥类型
        if [[ $line =~ ^(ssh-|ecdsa-sha2-|sk-ssh-|sk-ecdsa-) ]]; then
            ((line_num++))
            local key_type=$(echo "$line" | awk '{print $1}')
            local comment=$(echo "$line" | awk '{$1=$2=""; print $0}' | xargs)

            if [[ -n "$comment" ]]; then
                echo "  $line_num. 类型: $key_type, 注释: $comment"
            else
                echo "  $line_num. 类型: $key_type"
            fi
        fi
    done < "$authorized_keys_file"

    echo

    # 获取服务器信息
    print_info "生成测试连接命令..."
    local server_ip=$(get_public_ip)
    local ssh_port=$(get_ssh_port)

    echo
    print_success "服务器信息："
    echo "  用户: $current_user"
    echo "  IP: $server_ip"
    echo "  端口: $ssh_port"
    echo

    # 生成测试命令
    print_success "Windows PowerShell 测试命令："
    echo -e "${GREEN}ssh -i ~/.ssh/id_ed25519 $current_user@$server_ip -p $ssh_port${NC}"
    echo

    print_success "Linux/Mac 测试命令："
    echo -e "${GREEN}ssh -i ~/.ssh/id_ed25519 $current_user@$server_ip -p $ssh_port${NC}"
    echo

    print_warning "请在另一个终端测试上述命令，确保可以免密登录后再禁用密码登录！"
    echo

    return 0
}

# ==================== 功能2: 禁用密码登录 ====================
disable_password_login() {
    print_separator
    print_info "禁用密码登录（仅允许密钥登录）"
    echo

    # 先检查是否有密钥（检查 root 和 sudo 用户）
    print_info "正在检查SSH密钥配置..."
    local has_keys=false
    local checked_users=""

    # 检查 root 用户
    if [[ -f "/root/.ssh/authorized_keys" ]] && [[ -s "/root/.ssh/authorized_keys" ]]; then
        local root_key_count=$(grep -cE "^(ssh-|ecdsa-sha2-|sk-ssh-|sk-ecdsa-)" "/root/.ssh/authorized_keys" 2>/dev/null || echo "0")
        if [[ $root_key_count -gt 0 ]]; then
            print_success "root 用户已配置 $root_key_count 个SSH密钥"
            has_keys=true
            checked_users="root"
        fi
    fi

    # 检查通过 sudo 执行脚本的原始用户
    if [[ -n "${SUDO_USER-}" ]] && [[ "$SUDO_USER" != "root" ]]; then
        local sudo_user_home=$(eval echo ~"$SUDO_USER")
        if [[ -f "$sudo_user_home/.ssh/authorized_keys" ]] && [[ -s "$sudo_user_home/.ssh/authorized_keys" ]]; then
            local user_key_count=$(grep -cE "^(ssh-|ecdsa-sha2-|sk-ssh-|sk-ecdsa-)" "$sudo_user_home/.ssh/authorized_keys" 2>/dev/null || echo "0")
            if [[ $user_key_count -gt 0 ]]; then
                print_success "$SUDO_USER 用户已配置 $user_key_count 个SSH密钥"
                has_keys=true
                if [[ -n "$checked_users" ]]; then
                    checked_users="$checked_users, $SUDO_USER"
                else
                    checked_users="$SUDO_USER"
                fi
            fi
        fi
    fi

    if [[ "$has_keys" == false ]]; then
        print_error "未检测到任何SSH密钥配置！"
        print_warning "请先运行【功能1：检查SSH密钥配置】确保密钥正确配置"
        echo
        return 1
    fi

    print_success "SSH密钥检查通过 (已检查用户: $checked_users)"
    echo

    # 添加配置策略说明
    print_separator
    print_info "注意：本脚本配置策略说明"
    echo "  • 允许 root 用户通过密钥登录"
    echo "  • 禁止所有用户使用密码登录"
    echo "  • 仅接受SSH密钥认证方式"
    print_separator
    echo

    # 检查当前SSH会话数
    local session_count=$(who | wc -l)
    print_info "当前活动SSH会话数: $session_count"

    if [[ $session_count -lt 2 ]]; then
        print_warning "建议在修改SSH配置前，保持至少2个活动SSH会话"
        print_warning "以防配置错误导致无法登录"
        echo
    fi

    # 询问是否修改端口
    local new_port
    local current_port=$(get_ssh_port)

    echo -e "${YELLOW}是否修改SSH端口？当前端口: $current_port${NC}"
    echo "1) 保持不变 (推荐)"
    echo "2) 修改端口"
    read -p "请选择 [1-2]: " port_choice

    if [[ "$port_choice" == "2" ]]; then
        while true; do
            read -p "请输入新端口号 (1024-65535): " new_port
            if [[ "$new_port" =~ ^[0-9]+$ ]] && [[ $new_port -ge 1024 ]] && [[ $new_port -le 65535 ]]; then
                break
            else
                print_error "无效的端口号，请输入1024-65535之间的数字"
            fi
        done
    else
        new_port=$current_port
    fi

    echo

    # 备份当前配置
    print_info "备份当前SSH配置..."
    create_backup_dir
    backup_file "$SSHD_CONFIG"

    # 如果已存在 drop-in 配置，也备份
    if [[ -f "$SSHD_SECURITY_CONF" ]]; then
        backup_file "$SSHD_SECURITY_CONF"
    fi

    # 确保 drop-in 目录存在
    if [[ ! -d "$SSHD_CONFIG_DIR" ]]; then
        print_info "创建 sshd_config.d 目录..."
        mkdir -p "$SSHD_CONFIG_DIR"
        chmod 755 "$SSHD_CONFIG_DIR"
    fi

    # 检查主配置文件是否包含 Include 指令
    print_info "检查主配置文件的 Include 指令..."
    if ! grep -q "^Include /etc/ssh/sshd_config.d/\*.conf" "$SSHD_CONFIG" 2>/dev/null; then
        print_info "添加 Include 指令到主配置文件..."
        # 在文件开头分别插入注释与 Include 指令（两次插入确保换行正确）
        sed -i '1i\# Include drop-in configurations' "$SSHD_CONFIG"
        sed -i '2i\Include /etc/ssh/sshd_config.d/*.conf' "$SSHD_CONFIG"
        print_success "已添加 Include 指令"
    else
        print_success "Include 指令已存在"
    fi

    # 创建新的 drop-in 配置
    print_info "生成新的 SSH 安全配置 (drop-in)..."
    print_info "配置文件: $SSHD_SECURITY_CONF"

    cat > "$SSHD_SECURITY_CONF" << EOF
# SSH 安全配置 (Drop-in)
# 由 $SCRIPT_NAME 自动生成
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
#
# 说明：本配置文件仅覆盖必要的安全设置，不影响主配置文件中的其他配置

# 端口配置
Port $new_port

# 认证配置 - 仅允许密钥认证
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
UsePAM yes

# Root登录配置 - 允许密钥登录，禁止密码
PermitRootLogin prohibit-password

# 安全选项
MaxAuthTries 3
MaxSessions 10
IgnoreRhosts yes
HostbasedAuthentication no

# 性能优化
UseDNS no
TCPKeepAlive yes
ClientAliveInterval 300
ClientAliveCountMax 2

# 安全加固
X11Forwarding no
PrintMotd no
EOF

    print_success "新配置已生成"
    echo

    # 检查配置语法
    print_info "检查配置文件语法..."
    if sshd -t 2>&1; then
        print_success "配置文件语法检查通过"
    else
        print_error "配置文件语法检查失败"
        print_info "正在恢复备份..."

        local latest_backup=$(ls -t "$BACKUP_DIR"/sshd_config.bak.* 2>/dev/null | head -1 || true)
        if [[ -n "$latest_backup" ]]; then
            cp "$latest_backup" "$SSHD_CONFIG"
            print_success "已恢复备份配置"
        fi

        return 1
    fi

    echo

    # 检测并配置防火墙（如果端口有变化）
    if [[ "$new_port" != "$current_port" ]]; then
        echo
        print_info "检测到 SSH 端口变更: $current_port -> $new_port"
        print_info "检查防火墙配置..."
        echo

        # 检测 ufw
        if command -v ufw &> /dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
            print_success "检测到 UFW 防火墙"
            print_warning "需要在防火墙中放行新端口 $new_port"
            echo
            if confirm "是否自动配置 UFW 放行新端口？"; then
                if ufw allow "$new_port"/tcp; then
                    print_success "UFW 已放行端口 $new_port"
                    if [[ "$current_port" != "22" ]]; then
                        echo
                        if confirm "是否删除旧端口 $current_port 的规则？"; then
                            ufw delete allow "$current_port"/tcp
                            print_success "已删除旧端口规则"
                        fi
                    fi
                else
                    print_error "UFW 配置失败，请手动执行: ufw allow $new_port/tcp"
                fi
                echo
            else
                print_warning "请手动执行: ufw allow $new_port/tcp"
                echo
            fi
        # 检测 firewalld
        elif command -v firewall-cmd &> /dev/null && systemctl is-active --quiet firewalld 2>/dev/null; then
            print_success "检测到 Firewalld 防火墙"
            print_warning "需要在防火墙中放行新端口 $new_port"
            echo
            if confirm "是否自动配置 Firewalld 放行新端口？"; then
                if firewall-cmd --permanent --add-port="$new_port"/tcp && firewall-cmd --reload; then
                    print_success "Firewalld 已放行端口 $new_port"
                    if [[ "$current_port" != "22" ]]; then
                        echo
                        if confirm "是否删除旧端口 $current_port 的规则？"; then
                            firewall-cmd --permanent --remove-port="$current_port"/tcp
                            firewall-cmd --reload
                            print_success "已删除旧端口规则"
                        fi
                    fi
                else
                    print_error "Firewalld 配置失败，请手动执行: firewall-cmd --permanent --add-port=$new_port/tcp && firewall-cmd --reload"
                fi
                echo
            else
                print_warning "请手动执行: firewall-cmd --permanent --add-port=$new_port/tcp && firewall-cmd --reload"
                echo
            fi
        else
            print_info "未检测到 UFW 或 Firewalld，如使用其他防火墙请手动放行端口 $new_port"
            echo
        fi
    fi

    # 显示重要信息
    print_warning "===== 重要提示 ====="
    echo
    echo "即将重启SSH服务，请注意："
    echo "1. 确保你已经测试过SSH密钥登录可用"
    echo "2. 保持当前SSH会话不要关闭"
    echo "3. 新端口: $new_port"

    if [[ "$new_port" != "$current_port" ]]; then
        echo "4. 下次登录命令: ssh -i ~/.ssh/id_ed25519 root@$(get_public_ip) -p $new_port"
    fi

    echo
    echo "重启后将："
    echo "  - 完全禁止密码登录"
    echo "  - 允许root用户使用密钥登录（禁止密码登录）"
    echo "  - 仅允许密钥认证"
    echo

    if ! confirm "确认要重启SSH服务吗？"; then
        print_warning "已取消操作"
        print_info "配置文件已修改但未生效，如需恢复请使用【功能10】"
        return 1
    fi

    echo
    print_info "正在重启SSH服务..."

    if restart_ssh; then
        print_success "SSH服务重启成功！"
        echo
        print_success "配置已生效："
        echo "  ✓ 密码登录已禁用"
        echo "  ✓ Root用户可通过密钥登录（密码已禁用）"
        echo "  ✓ SSH端口: $new_port"
        echo
        print_warning "请立即在新终端测试登录，不要关闭当前会话！"
    else
        print_error "SSH服务重启失败"
        return 1
    fi

    echo
}

# ==================== 功能3: 一键安装配置fail2ban ====================
install_fail2ban() {
    print_separator
    print_info "一键安装配置 fail2ban"
    echo

    # 检查是否已安装
    if command -v fail2ban-client &> /dev/null; then
        print_warning "检测到 fail2ban 已安装"
        if ! confirm "是否重新配置？"; then
            return 0
        fi
    else
        print_info "开始安装 fail2ban..."

        # 严格检查系统类型
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            local current_id="${ID:-unknown}"
            if [[ "$current_id" != "ubuntu" && "$current_id" != "debian" ]]; then
                print_error "自动安装仅支持 Ubuntu/Debian 系统"
                print_info "检测到系统: $current_id"
                print_info "请手动安装 fail2ban："
                print_info "  - CentOS/RHEL: yum install fail2ban"
                print_info "  - Fedora: dnf install fail2ban"
                print_info "  - Arch: pacman -S fail2ban"
                print_info "安装完成后，可以重新运行本功能进行配置"
                return 1
            fi
        fi

        # 更新软件包列表
        if ! apt update; then
            print_error "系统更新失败，请检查网络连接"
            return 1
        fi

        # 安装fail2ban
        if ! apt install fail2ban -y; then
            print_error "fail2ban 安装失败"
            return 1
        fi

        # 验证安装
        if command -v fail2ban-client &> /dev/null; then
            print_success "fail2ban 安装成功"
        else
            print_error "fail2ban 安装失败：命令未找到"
            return 1
        fi
    fi

    echo

    # 询问SSH端口
    local ssh_port=$(get_ssh_port)
    local ports

    print_info "当前SSH端口: $ssh_port"
    read -p "请输入要保护的端口 (多个端口用逗号分隔，直接回车使用 $ssh_port): " ports

    # 清理输入：去除前后空白、换行符，转换多个空格为单个
    ports=$(echo "$ports" | xargs)

    if [[ -z "$ports" ]]; then
        ports="$ssh_port"
    fi

    echo
    print_info "保护端口: $ports"
    echo

    # 检测当前SSH连接IP并询问是否加入白名单
    local current_ssh_client
    local ignoreip="127.0.0.1/8 ::1 192.168.0.0/16 10.0.0.0/8 172.16.0.0/12"

    current_ssh_client=$(echo "${SSH_CLIENT-}" | awk '{print $1}')
    if [[ -n "$current_ssh_client" ]] && validate_ip "$current_ssh_client"; then
        print_warning "检测到当前连接IP: $current_ssh_client"
        if confirm "是否将当前IP加入白名单（防止误封）？"; then
            ignoreip="$ignoreip $current_ssh_client"
            print_success "当前IP已加入白名单"
        fi
        echo
    fi

    # 备份原配置
    create_backup_dir
    if [[ -f /etc/fail2ban/jail.conf ]]; then
        backup_file /etc/fail2ban/jail.conf
    fi

    if [[ -f "$FAIL2BAN_JAIL" ]]; then
        backup_file "$FAIL2BAN_JAIL"
    fi

    # 检测防火墙类型
    print_info "检测防火墙类型..."
    local banaction="iptables-multiport"
    local banaction_allports="iptables-allports"

    if command -v nft &> /dev/null && systemctl is-active --quiet nftables 2>/dev/null; then
        print_success "检测到 nftables"
        banaction="nftables-multiport"
        banaction_allports="nftables-allports"
    elif command -v firewall-cmd &> /dev/null && systemctl is-active --quiet firewalld 2>/dev/null; then
        print_success "检测到 firewalld"
        banaction="firewallcmd-multiport"
        banaction_allports="firewallcmd-allports"
    elif command -v iptables &> /dev/null; then
        print_success "检测到 iptables"
        banaction="iptables-multiport"
        banaction_allports="iptables-allports"
    else
        print_warning "未检测到防火墙，使用默认 iptables 配置"
        print_info "如果系统使用其他防火墙，请手动调整配置文件"
    fi

    # 创建配置文件
    print_info "生成 fail2ban 配置..."

    cat > "$FAIL2BAN_JAIL" << EOF
# ==============================
# Fail2ban SSH 防暴力破解配置
# 由 $SCRIPT_NAME 自动生成
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')
# ==============================

[DEFAULT]
# 忽略列表 (本机和内网IP)
ignoreip = $ignoreip

# 封禁时间设置
bantime = 24h
findtime = 10m
maxretry = 3

# 递增封禁时间（重复攻击者）
bantime.increment = true
bantime.factor = 2
bantime.maxtime = 168h

# 封禁动作（自动检测防火墙类型）
banaction = $banaction
banaction_allports = $banaction_allports

# ==============================
# SSH 保护
# ==============================
[sshd]
enabled = true
port = $ports
filter = sshd
logpath = /var/log/auth.log
backend = systemd
maxretry = 3
findtime = 10m
bantime = 24h

# ==============================
# 防重复攻击者 (Recidive)
# 针对多次被封后再次攻击的IP
# ==============================
[recidive]
enabled = true
logpath = /var/log/fail2ban.log
banaction = $banaction_allports
bantime = 168h
findtime = 1d
maxretry = 5
EOF

    print_success "配置文件已生成: $FAIL2BAN_JAIL"
    echo

    # 检查配置语法
    print_info "检查 fail2ban 配置语法..."
    # 使用 fail2ban-client 测试配置（先停止服务，测试后再启动）
    # 或者直接尝试重启并检查状态
    if systemctl is-active --quiet fail2ban; then
        print_info "测试配置（重载服务）..."
        if fail2ban-client reload &> /dev/null; then
            print_success "配置语法检查通过"
        else
            print_error "配置重载失败，配置可能有误"
            print_info "尝试查看详细错误信息..."
            systemctl status fail2ban --no-pager -l
            return 1
        fi
    else
        print_info "服务未运行，将在启动时验证配置"
    fi

    echo

    # 启动服务
    print_info "启动 fail2ban 服务..."

    systemctl enable fail2ban
    systemctl restart fail2ban

    sleep 2

    if systemctl is-active --quiet fail2ban; then
        print_success "fail2ban 服务已启动"
    else
        print_error "fail2ban 服务启动失败"
        systemctl status fail2ban
        return 1
    fi

    echo

    # 显示状态
    print_success "fail2ban 配置完成！"
    echo
    print_info "配置详情："
    echo "  - 失败尝试次数: 3次"
    echo "  - 检测时间窗口: 10分钟"
    echo "  - 初次封禁时间: 24小时"
    echo "  - 最长封禁时间: 168小时(7天)"
    echo "  - 保护端口: $ports"
    echo

    print_info "检查服务状态..."
    fail2ban-client status

    echo
    print_success "使用【功能4】查看详细状态"
    echo
}

# ==================== 功能4: 查看fail2ban状态 ====================
show_fail2ban_status() {
    print_separator
    print_info "查看 fail2ban 状态"
    echo

    # 检查服务
    if ! systemctl is-active --quiet fail2ban; then
        print_error "fail2ban 服务未运行"
        print_info "请先使用【功能3】安装配置 fail2ban"
        return 1
    fi

    print_success "fail2ban 服务运行中"
    echo

    # 获取所有jail
    print_info "活动的 jail 列表:"
    fail2ban-client status || true

    echo

    # 获取jail列表
    local jails=$(fail2ban-client status | grep "Jail list:" | sed 's/.*Jail list:\s*//' | tr ',' '\n' | xargs || true)

    if [[ -z "$jails" ]]; then
        print_warning "没有活动的 jail"
        return 0
    fi

    # 显示每个jail的详细状态
    for jail in $jails; do
        print_separator
        print_info "Jail: $jail"
        fail2ban-client status "$jail" || true
        echo
    done

    print_separator
}

# ==================== 功能5: 手动封禁IP ====================
ban_ip_manual() {
    print_separator
    print_info "手动封禁 IP"
    echo

    # 检查服务
    if ! systemctl is-active --quiet fail2ban; then
        print_error "fail2ban 服务未运行"
        return 1
    fi

    # 获取jail列表
    local jails=$(fail2ban-client status | grep "Jail list:" | sed 's/.*Jail list:\s*//' | tr ',' '\n' | xargs || true)

    if [[ -z "$jails" ]]; then
        print_error "没有活动的 jail"
        return 1
    fi

    # 选择jail
    print_info "可用的 jail:"
    local -a jail_array=($jails)
    local i=1
    for jail in "${jail_array[@]}"; do
        echo "  $i) $jail"
        ((i++))
    done

    echo
    read -p "请选择 jail (直接回车选择 sshd): " jail_choice

    local selected_jail
    if [[ -z "$jail_choice" ]]; then
        selected_jail="sshd"
    elif [[ "$jail_choice" =~ ^[0-9]+$ ]] && [[ $jail_choice -ge 1 ]] && [[ $jail_choice -le ${#jail_array[@]} ]]; then
        selected_jail="${jail_array[$((jail_choice-1))]}"
    else
        print_error "无效的选择"
        return 1
    fi

    echo

    # 输入IP
    local ip_to_ban
    while true; do
        read -p "请输入要封禁的IP地址: " ip_to_ban

        if [[ -z "$ip_to_ban" ]]; then
            print_warning "已取消"
            return 0
        fi

        if validate_ip "$ip_to_ban"; then
            break
        else
            print_error "无效的IP地址格式"
        fi
    done

    echo
    print_info "正在封禁 IP: $ip_to_ban (jail: $selected_jail)..."

    if fail2ban-client set "$selected_jail" banip "$ip_to_ban"; then
        print_success "IP 封禁成功: $ip_to_ban"
        echo

    print_info "当前封禁列表:"
    fail2ban-client status "$selected_jail" | grep -A 1 "Banned IP list" || true
    else
        print_error "IP 封禁失败"
        return 1
    fi

    echo
}

# ==================== 功能6: 手动解封IP ====================
unban_ip_manual() {
    print_separator
    print_info "手动解封 IP"
    echo

    # 检查服务
    if ! systemctl is-active --quiet fail2ban; then
        print_error "fail2ban 服务未运行"
        return 1
    fi

    # 获取jail列表
    local jails=$(fail2ban-client status | grep "Jail list:" | sed 's/.*Jail list:\s*//' | tr ',' '\n' | xargs || true)

    if [[ -z "$jails" ]]; then
        print_error "没有活动的 jail"
        return 1
    fi

    # 选择jail
    print_info "可用的 jail:"
    local -a jail_array=($jails)
    local i=1
    for jail in "${jail_array[@]}"; do
        echo "  $i) $jail"
        ((i++))
    done

    echo
    read -p "请选择 jail (直接回车选择 sshd): " jail_choice

    local selected_jail
    if [[ -z "$jail_choice" ]]; then
        selected_jail="sshd"
    elif [[ "$jail_choice" =~ ^[0-9]+$ ]] && [[ $jail_choice -ge 1 ]] && [[ $jail_choice -le ${#jail_array[@]} ]]; then
        selected_jail="${jail_array[$((jail_choice-1))]}"
    else
        print_error "无效的选择"
        return 1
    fi

    echo

    # 显示当前封禁的IP
    print_info "当前封禁的IP列表 (jail: $selected_jail):"
    local banned_ips=$(fail2ban-client status "$selected_jail" | grep "Banned IP list:" | sed 's/.*Banned IP list:\s*//' || true)

    if [[ -z "$banned_ips" ]] || [[ "$banned_ips" == "" ]]; then
        print_warning "没有被封禁的IP"
        return 0
    fi

    echo "  $banned_ips"
    echo

    # 输入IP
    local ip_to_unban
    read -p "请输入要解封的IP地址: " ip_to_unban

    if [[ -z "$ip_to_unban" ]]; then
        print_warning "已取消"
        return 0
    fi

    echo
    print_info "正在解封 IP: $ip_to_unban (jail: $selected_jail)..."

    if fail2ban-client set "$selected_jail" unbanip "$ip_to_unban"; then
        print_success "IP 解封成功: $ip_to_unban"
        echo

    print_info "当前封禁列表:"
    fail2ban-client status "$selected_jail" | grep -A 1 "Banned IP list" || true
    else
        print_error "IP 解封失败"
        return 1
    fi

    echo
}

# ==================== 功能7: 查看封禁列表 ====================
show_banned_list() {
    print_separator
    print_info "查看 fail2ban 封禁列表"
    echo

    # 检查服务
    if ! systemctl is-active --quiet fail2ban; then
        print_error "fail2ban 服务未运行"
        return 1
    fi

    # 获取jail列表
    local jails=$(fail2ban-client status | grep "Jail list:" | sed 's/.*Jail list:\s*//' | tr ',' '\n' | xargs || true)

    if [[ -z "$jails" ]]; then
        print_error "没有活动的 jail"
        return 1
    fi

    # 遍历所有jail
    local has_banned=0
    for jail in $jails; do
        print_info "Jail: $jail"

        local status_output=$(fail2ban-client status "$jail" || true)
        local currently_failed=$(echo "$status_output" | grep "Currently failed:" | awk '{print $NF}' || true)
        local total_failed=$(echo "$status_output" | grep "Total failed:" | awk '{print $NF}' || true)
        local currently_banned=$(echo "$status_output" | grep "Currently banned:" | awk '{print $NF}' || true)
        local total_banned=$(echo "$status_output" | grep "Total banned:" | awk '{print $NF}' || true)
        local banned_ips=$(echo "$status_output" | grep "Banned IP list:" | sed 's/.*Banned IP list:\s*//' || true)

        echo "  当前失败次数: $currently_failed"
        echo "  总失败次数: $total_failed"
        echo "  当前封禁数量: $currently_banned"
        echo "  总封禁次数: $total_banned"

        if [[ -n "$banned_ips" ]] && [[ "$banned_ips" != "" ]]; then
            echo -e "  ${RED}封禁IP列表: $banned_ips${NC}"
            has_banned=1
        else
            echo "  封禁IP列表: (无)"
        fi

        echo
    done

    if [[ $has_banned -eq 0 ]]; then
        print_success "当前没有被封禁的IP"
    fi

    print_separator
}

# ==================== 功能8: 查看fail2ban日志 ====================
show_fail2ban_logs() {
    print_separator
    print_info "查看 fail2ban 日志"
    echo

    local log_file="/var/log/fail2ban.log"

    if [[ ! -f "$log_file" ]]; then
        print_error "日志文件不存在: $log_file"
        return 1
    fi

    print_info "最近50条日志记录:"
    echo

    # 使用颜色高亮关键词
    tail -n 50 "$log_file" | while IFS= read -r line; do
        if [[ $line =~ Ban|banned ]]; then
            echo -e "${RED}$line${NC}"
        elif [[ $line =~ Unban|unbanned ]]; then
            echo -e "${GREEN}$line${NC}"
        elif [[ $line =~ ERROR|Error|error ]]; then
            echo -e "${YELLOW}$line${NC}"
        elif [[ $line =~ Found ]]; then
            echo -e "${BLUE}$line${NC}"
        else
            echo "$line"
        fi
    done

    echo

    # 询问是否实时查看
    print_info "是否实时查看日志？(按Ctrl+C退出)"
    read -p "输入 yes 开启实时查看: " -t 5 realtime || true
    # 处理超时或非yes输入
    if [[ $? -ne 0 ]] || [[ "$realtime" != "yes" ]]; then
        realtime="no"
    fi

    if [[ "$realtime" == "yes" ]]; then
        echo
        print_info "实时日志 (按 Ctrl+C 退出):"
        tail -f "$log_file" | while IFS= read -r line; do
            if [[ $line =~ Ban|banned ]]; then
                echo -e "${RED}$line${NC}"
            elif [[ $line =~ Unban|unbanned ]]; then
                echo -e "${GREEN}$line${NC}"
            elif [[ $line =~ ERROR|Error|error ]]; then
                echo -e "${YELLOW}$line${NC}"
            elif [[ $line =~ Found ]]; then
                echo -e "${BLUE}$line${NC}"
            else
                echo "$line"
            fi
        done
    fi

    echo
}

# ==================== 功能9: 添加信任IP到白名单 ====================
add_trusted_ip() {
    print_separator
    print_info "添加信任IP到白名单"
    echo

    if [[ ! -f "$FAIL2BAN_JAIL" ]]; then
        print_error "fail2ban 配置文件不存在: $FAIL2BAN_JAIL"
        print_info "请先使用【功能3】安装配置 fail2ban"
        return 1
    fi

    # 显示当前白名单
    print_info "当前白名单:"
    local current_ignore=$(grep "^ignoreip" "$FAIL2BAN_JAIL" | sed 's/ignoreip = //' || true)
    echo "  $current_ignore"
    echo

    # 输入新IP
    print_info "输入要添加的信任IP或IP段"
    print_info "示例: 192.168.1.100 或 192.168.1.0/24"
    read -p "IP地址: " new_ip

    if [[ -z "$new_ip" ]]; then
        print_warning "已取消"
        return 0
    fi

    # 简单验证
    if [[ ! $new_ip =~ ^[0-9./]+ ]]; then
        print_error "无效的IP格式"
        return 1
    fi

    # 检查是否已存在（使用单词边界精确匹配，避免误判）
    # 例如：白名单有 192.168.1.10，添加 192.168.1.1 不应该误判为已存在
    if echo "$current_ignore" | grep -qw "$new_ip"; then
        print_warning "该IP已在白名单中"
        return 0
    fi

    # 备份配置
    create_backup_dir
    backup_file "$FAIL2BAN_JAIL"

    # 添加IP到白名单
    print_info "添加 IP 到白名单..."

    # 使用awk安全地添加IP（使用纯文本匹配，避免正则误判）
    awk -v new_ip="$new_ip" '
        /^ignoreip/ {
            # 纯文本匹配：检查IP是否作为完整单词存在
            found = 0
            # 分割行内容，逐个检查每个字段
            for (i = 1; i <= NF; i++) {
                if ($i == new_ip) {
                    found = 1
                    break
                }
            }
            # 如果未找到，添加到行尾
            if (!found) {
                $0 = $0 " " new_ip
            }
        }
        {print}
    ' "$FAIL2BAN_JAIL" > "$FAIL2BAN_JAIL.tmp"

    if [[ -s "$FAIL2BAN_JAIL.tmp" ]]; then
        mv "$FAIL2BAN_JAIL.tmp" "$FAIL2BAN_JAIL"
        print_success "IP 已添加到白名单"
    else
        print_error "添加IP失败"
        rm -f "$FAIL2BAN_JAIL.tmp"
        return 1
    fi
    echo

    # 显示新白名单
    print_info "更新后的白名单:"
    local new_ignore=$(grep "^ignoreip" "$FAIL2BAN_JAIL" | sed 's/ignoreip = //' || true)
    echo "  $new_ignore"
    echo

    # 重启服务
    print_info "重启 fail2ban 服务以应用更改..."

    if systemctl restart fail2ban; then
        print_success "fail2ban 服务已重启"
        print_success "白名单配置已生效"
    else
        print_error "fail2ban 服务重启失败"
        return 1
    fi

    echo
}

# ==================== 功能10: 恢复配置备份 ====================
restore_backup() {
    print_separator
    print_info "恢复配置备份"
    echo

    if [[ ! -d "$BACKUP_DIR" ]]; then
        print_error "备份目录不存在: $BACKUP_DIR"
        return 1
    fi

    # 列出所有备份文件
    local backups=$(ls -t "$BACKUP_DIR"/*.bak.* 2>/dev/null || true)

    if [[ -z "$backups" ]]; then
        print_error "没有找到备份文件"
        return 1
    fi

    print_info "可用的备份文件:"
    echo

    local -a backup_array=()
    local i=1
    while IFS= read -r backup; do
        backup_array+=("$backup")
        local basename=$(basename "$backup")
        local size=$(du -h "$backup" | cut -f1)
        echo "  $i) $basename ($size)"
        ((i++))
    done <<< "$backups"

    echo
    read -p "请选择要恢复的备份 (1-${#backup_array[@]}): " choice

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#backup_array[@]} ]]; then
        print_error "无效的选择"
        return 1
    fi

    local selected_backup="${backup_array[$((choice-1))]}"
    local backup_name=$(basename "$selected_backup")

    echo
    print_info "选择的备份: $backup_name"

    # 确定目标文件
    local target_file
    if [[ $backup_name =~ sshd_config ]]; then
        target_file="$SSHD_CONFIG"
        print_warning "警告: 恢复 SSH 配置可能导致无法登录！"
    elif [[ $backup_name =~ jail ]]; then
        target_file="$FAIL2BAN_JAIL"
    else
        print_error "无法识别的备份文件类型"
        return 1
    fi

    echo
    print_warning "即将恢复备份到: $target_file"

    if ! confirm "确认恢复备份？"; then
        print_warning "已取消"
        return 0
    fi

    # 恢复备份前检查完整性
    print_info "检查备份文件完整性..."

    if [[ ! -s "$selected_backup" ]]; then
        print_error "备份文件为空或不存在"
        return 1
    fi

    print_success "备份文件完整性检查通过"

    # 恢复备份
    print_info "正在恢复备份..."

    cp "$selected_backup" "$target_file"

    # 验证恢复结果
    if [[ ! -s "$target_file" ]]; then
        print_error "恢复失败：目标文件为空"
        return 1
    fi

    print_success "备份已恢复: $target_file"
    echo

    # 根据文件类型重启服务
    if [[ $backup_name =~ sshd_config ]]; then
        print_info "检查SSH配置语法..."
        if sshd -t 2>&1; then
            print_success "配置语法正确"

            if confirm "是否重启SSH服务？"; then
                restart_ssh
                print_success "SSH配置已生效"
            else
                print_warning "配置已恢复但未重启服务"
            fi
        else
            print_error "配置语法错误！"
            sshd -t
        fi
    elif [[ $backup_name =~ jail ]]; then
        print_info "重启 fail2ban 服务..."
        if systemctl restart fail2ban; then
            print_success "fail2ban 配置已生效"
        else
            print_error "fail2ban 服务重启失败"
        fi
    fi

    echo
}

# ==================== 主菜单 ====================
show_menu() {
    clear
    print_separator
    echo -e "${BLUE}        $SCRIPT_NAME v$SCRIPT_VERSION${NC}"
    print_separator
    echo
    echo "  1.  检查 SSH 密钥配置"
    echo "  2.  禁用密码登录（仅密钥）"
    echo "  3.  一键安装配置 fail2ban"
    echo "  4.  查看 fail2ban 状态"
    echo "  5.  fail2ban 手动封禁 IP"
    echo "  6.  fail2ban 手动解封 IP"
    echo "  7.  查看 fail2ban 封禁列表"
    echo "  8.  查看 fail2ban 日志"
    echo "  9.  添加信任 IP 到白名单"
    echo "  10. 恢复配置备份"
    echo "  0.  退出"
    echo
    print_separator
}

# ==================== 主程序 ====================
main() {
    # 初始化
    check_root
    detect_system
    create_backup_dir

    # 创建日志文件
    touch "$LOG_FILE"
    log "INFO" "脚本启动 - 版本 $SCRIPT_VERSION"

    # 主循环
    while true; do
        show_menu
        read -p "请选择功能 [0-10]: " choice

        case $choice in
            1)
                check_ssh_keys
                ;;
            2)
                disable_password_login
                ;;
            3)
                install_fail2ban
                ;;
            4)
                show_fail2ban_status
                ;;
            5)
                ban_ip_manual
                ;;
            6)
                unban_ip_manual
                ;;
            7)
                show_banned_list
                ;;
            8)
                show_fail2ban_logs
                ;;
            9)
                add_trusted_ip
                ;;
            10)
                restore_backup
                ;;
            0)
                print_info "感谢使用 $SCRIPT_NAME"
                log "INFO" "脚本正常退出"
                exit 0
                ;;
            *)
                print_error "无效的选择，请输入 0-10"
                ;;
        esac

        echo
        read -p "按回车键继续..." -r
    done
}

# 运行主程序
main

