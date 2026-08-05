#!/bin/bash
# ============================================================
# qBittorrent 管理脚本 (Linux)
# 功能: 安装 / 查看默认密码 / 修改密码 / 卸载
# 支持: Debian/Ubuntu/CentOS
# 用法: bash qbt-manager.sh
# ============================================================

set -e

# ---- 颜色 ----
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

# ---- 路径配置 ----
QB_DIR="/opt/qbittorrent"
QB_BIN="$QB_DIR/qbittorrent-nox"
QB_CONFIG_DIR="$HOME/.config/qBittorrent"
QB_CONF="$QB_CONFIG_DIR/qBittorrent.conf"
QB_LOG="/tmp/qbt_first_run.log"
PASS_FILE="$QB_DIR/.default_password"
SERVICE_FILE="/etc/systemd/system/qbittorrent-nox.service"
WEBUI_PORT=8080

# ============================================================
# 工具函数
# ============================================================
info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[✗]${NC} $1"; }
separator() { echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        err "部分操作需要 root 权限，请用 sudo bash $0 运行"
        exit 1
    fi
}

check_qbt_installed() {
    if [[ -f "$QB_BIN" ]]; then
        return 0
    fi
    return 1
}

# ============================================================
# 1. 安装
# ============================================================
install_qbt() {
    separator
    echo -e "${CYAN}  qBittorrent 安装${NC}"
    separator

    check_root

    # 检测发行版
    local os=""
    local pkg_manager=""
    if command -v apt &>/dev/null; then
        os="debian"; pkg_manager="apt"
    elif command -v yum &>/dev/null; then
        os="rhel"; pkg_manager="yum"
    elif command -v dnf &>/dev/null; then
        os="rhel"; pkg_manager="dnf"
    elif command -v apk &>/dev/null; then
        os="alpine"; pkg_manager="apk"
    else
        err "不支持的发行版，请手动安装依赖"
        exit 1
    fi
    info "检测到: $os 系 ($pkg_manager)"

    # 安装依赖
    info "安装依赖..."
    case "$os" in
        debian)
            apt update -qq
            apt install -y -qq curl wget unzip jq systemd 2>/dev/null || true
            # 针对 Ubuntu 22.04+ 可能需要额外库
            apt install -y -qq libqt5network5 libqt5xml5 libqt5sql5-sqlite 2>/dev/null || true
            ;;
        rhel)
            $pkg_manager install -y curl wget unzip jq 2>/dev/null || true
            $pkg_manager install -y epel-release 2>/dev/null || true
            ;;
        alpine)
            apk add curl wget unzip jq 2>/dev/null || true
            ;;
    esac
    ok "依赖安装完成"

    # 创建目录
    mkdir -p "$QB_DIR"
    mkdir -p "$QB_CONFIG_DIR"

    # 获取最新版本号
    info "获取 qBittorrent 最新版本..."
    local latest_version
    latest_version=$(curl -sL "https://api.github.com/repos/userdocs/qbittorrent-nox-static/releases/latest" | jq -r '.tag_name' 2>/dev/null || echo "")

    if [[ -z "$latest_version" || "$latest_version" == "null" ]]; then
        warn "获取版本号失败，使用默认版本"
        latest_version="release-4.6.7_v2.0.10"
    fi
    info "最新版本: $latest_version"

    # 下载静态编译版
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  arch="x86_64" ;;
        aarch64) arch="aarch64" ;;
        *)       err "不支持的架构: $arch"; exit 1 ;;
    esac

    local download_url
    download_url="https://github.com/userdocs/qbittorrent-nox-static/releases/download/${latest_version}/${arch}-qbittorrent-nox"

    info "下载: $download_url"
    curl -#L -o "$QB_BIN" "$download_url" || {
        err "下载失败，尝试备用源..."
        # 备用: 官方 PPA
        if [[ "$os" == "debian" ]]; then
            warn "切换到 apt 安装方式..."
            apt install -y qbittorrent-nox 2>/dev/null || {
                add-apt-repository -y ppa:qbittorrent-team/qbittorrent-stable 2>/dev/null || true
                apt update -qq
                apt install -y -qq qbittorrent-nox
            }
            ok "apt 安装完成"
            QB_BIN=$(which qbittorrent-nox)
        else
            err "所有安装方式均失败"
            exit 1
        fi
    }

    chmod +x "$QB_BIN" 2>/dev/null || true
    ok "qBittorrent 下载完成: $QB_BIN"

    # 创建 systemd 服务 (可选)
    if command -v systemctl &>/dev/null; then
        cat > "$SERVICE_FILE" << SERVICEEOF
[Unit]
Description=qBittorrent-nox (headless)
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/qbittorrent/qbittorrent-nox
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
SERVICEEOF
        systemctl daemon-reload 2>/dev/null || true
        ok "systemd 服务创建完成: $SERVICE_FILE"
    fi

    # 首次启动，获取默认密码
    separator
    echo -e "${YELLOW}  首次启动，获取默认密码...${NC}"
    echo -e "${YELLOW}  (启动后等待 5 秒自动退出)${NC}"
    separator

    # 确保配置文件目录存在
    mkdir -p "$QB_CONFIG_DIR"

    # 启动并捕获密码
    timeout 8 "$QB_BIN" 2>&1 | tee "$QB_LOG" &
    local pid=$!
    sleep 5
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true

    # 从日志提取密码 - 优先从 "temporary password: xxxx" 截取
    local password=""
    password=$(grep -oP 'temporary password is provided for this session: \K\S+' "$QB_LOG" 2>/dev/null | head -1)
    # 兼容旧版本格式
    if [[ -z "$password" ]]; then
        password=$(grep -oP 'password[^a-z].*?:\s*\K\S+' "$QB_LOG" 2>/dev/null | head -1)
    fi
    # 最后兜底: 随机8位以上字母数字组合
    if [[ -z "$password" ]]; then
        password=$(grep -i "password" "$QB_LOG" 2>/dev/null | grep -oP '\b[A-Za-z0-9]{8,}\b' | grep -vi "administrator\|password\|temporary\|provided" | head -1)
    fi

    if [[ -n "$password" ]]; then
        echo "$password" > "$PASS_FILE"
        chmod 600 "$PASS_FILE"
        separator
        echo -e "${GREEN}  ┌─────────────────────────────────────────────┐${NC}"
        echo -e "${GREEN}  │  Web UI 地址: http://$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'):$WEBUI_PORT${NC}"
        echo -e "${GREEN}  │  用户名:     admin${NC}"
        echo -e "${GREEN}  │  默认密码:   ${YELLOW}$password${NC}${GREEN}${NC}"
        echo -e "${GREEN}  │  (已保存至: $PASS_FILE)${NC}"
        echo -e "${GREEN}  └─────────────────────────────────────────────┘${NC}"
        separator
    else
        warn "未检测到随机密码，可能是旧版本"
        echo -e "  ${YELLOW}用户名: admin${NC}"
        echo -e "  ${YELLOW}默认密码: adminadmin${NC}"
        echo -e "  ${YELLOW}或尝试: admin${NC}"
        echo "adminadmin" > "$PASS_FILE"
        chmod 600 "$PASS_FILE"
    fi

    # 确保配置使用正确的 WebUI 端口
    if [[ -f "$QB_CONF" ]]; then
        sed -i 's/WebUI\\Port=.*/WebUI\\Port=8080/' "$QB_CONF" 2>/dev/null || true
    fi

    ok "安装完成！"
    echo ""
    info "启动服务: qbittorrent-nox"
    info "开机自启: systemctl enable qbittorrent-nox"
    info "配置文件: $QB_CONF"
}

# ============================================================
# 2. 查看默认密码
# ============================================================
show_password() {
    separator
    echo -e "${CYAN}  qBittorrent 默认密码${NC}"
    separator

    if [[ -f "$PASS_FILE" ]]; then
        local pass
        pass=$(cat "$PASS_FILE")
        echo -e "  ${GREEN}用户名: ${NC}admin"
        echo -e "  ${GREEN}密  码: ${YELLOW}$pass${NC}"
        echo -e "  ${GREEN}保存于: ${NC}$PASS_FILE"
    else
        warn "未找到保存的密码文件"
        echo ""
        echo "  尝试从配置文件获取:"
        if [[ -f "$QB_CONF" ]]; then
            grep -i "password" "$QB_CONF" 2>/dev/null || echo "  配置文件中无密码字段"
        fi
        echo ""
        echo "  ${YELLOW}旧版本默认凭据:${NC}"
        echo "    用户名: admin"
        echo "    密码:   adminadmin"
        echo ""
        echo "  ${YELLOW}或从日志中查找:${NC}"
        echo "    journalctl -u qbittorrent-nox --no-pager | grep -i password"
        echo "    cat /tmp/qbt_first_run.log 2>/dev/null | grep -i password"
    fi
    separator
}

# ============================================================
# 3. 修改密码
# ============================================================
change_password() {
    separator
    echo -e "${CYAN}  修改 qBittorrent WebUI 密码${NC}"
    separator

    if ! check_qbt_installed; then
        err "qBittorrent 未安装，请先安装"
        return 1
    fi

    # 停止服务
    if command -v systemctl &>/dev/null && systemctl is-active --quiet qbittorrent-nox 2>/dev/null; then
        info "停止 qBittorrent 服务..."
        systemctl stop qbittorrent-nox
        sleep 1
    fi

    # 确保进程已停止
    pkill -f qbittorrent-nox 2>/dev/null || true
    sleep 1

    echo ""
    read -r -p "  请输入新密码 (留空则生成随机密码): " new_pass

    if [[ -z "$new_pass" ]]; then
        new_pass=$(tr -dc 'A-Za-z0-9!@#$%^&*_' < /dev/urandom | head -c 16)
        echo -e "  ${YELLOW}生成随机密码: $new_pass${NC}"
    fi

    # 方法1: 使用 qbittorrent-nox 自带的 --set-webui-password (v4.6.0+)
    if "$QB_BIN" --help 2>&1 | grep -q "set-webui-password"; then
        info "使用内置密码修改功能..."
        if "$QB_BIN" --set-webui-password="$new_pass" 2>&1; then
            ok "密码修改成功 (内置方法)"
        else
            warn "内置方法失败，尝试配置文件法..."
            edit_config_password "$new_pass"
        fi
    else
        # 方法2: 直接修改配置文件
        edit_config_password "$new_pass"
    fi

    # 保存新密码
    echo "$new_pass" > "$PASS_FILE"
    chmod 600 "$PASS_FILE"
    ok "新密码已保存至: $PASS_FILE"

    # 重启服务
    if command -v systemctl &>/dev/null; then
        systemctl start qbittorrent-nox 2>/dev/null || true
        info "服务已重启"
    fi

    separator
    echo -e "${GREEN}  ┌─────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}  │  Web UI 地址: http://<你的IP>:$WEBUI_PORT${NC}"
    echo -e "${GREEN}  │  用户名:     admin${NC}"
    echo -e "${GREEN}  │  新密码:     ${YELLOW}$new_pass${NC}${GREEN}${NC}"
    echo -e "${GREEN}  └─────────────────────────────────────────────┘${NC}"
    separator
}

# 通过配置文件修改密码
edit_config_password() {
    local new_pass="$1"

    # 确保配置文件存在
    if [[ ! -f "$QB_CONF" ]]; then
        mkdir -p "$QB_CONFIG_DIR"
        cat > "$QB_CONF" << 'CONFEOF'
[Preferences]
General\Locale=zh
Connection\PortRangeMin=6881
Downloads\SavePath=/root/Downloads
Downloads\TempPath=/root/Downloads/temp
CONFEOF
    fi

    # qBittorrent 5.x 密码格式: @ByteArray(base64(salt):base64(hash))
    # PBKDF2-HMAC-SHA512, 100000 次迭代, salt 12字节, hash 64字节, 冒号分隔
    # (4.x 及以下是 salt+hash 拼接后整体 base64, 此处兼容 5.x)
    local hashed_pass
    hashed_pass=$(python3 -c "
import base64, hashlib, os
password = '$new_pass'
salt = os.urandom(12)
dk = hashlib.pbkdf2_hmac('sha512', password.encode('utf-8'), salt, 100000, dklen=64)
b64_salt = base64.b64encode(salt).decode('ascii')
b64_hash = base64.b64encode(dk).decode('ascii')
print('@ByteArray({}:{})'.format(b64_salt, b64_hash))
")

    # 修改配置文件
    if grep -q "WebUI\\Password_PBKDF2" "$QB_CONF" 2>/dev/null; then
        # 有 PBKDF2 字段，清空它让 qBittorrent 重新生成
        sed -i '/WebUI\\Password_PBKDF2/d' "$QB_CONF"
    fi

    # 删除旧密码相关字段
    sed -i '/WebUI\\Password[^_]/d' "$QB_CONF" 2>/dev/null || true
    sed -i '/WebUI\\Password_PBKDF2/d' "$QB_CONF" 2>/dev/null || true

    # 写入新密码 (PBKDF2 格式)
    echo "" >> "$QB_CONF"
    echo "WebUI\\Password_PBKDF2=$hashed_pass" >> "$QB_CONF"

    ok "配置文件已更新"
}

# ============================================================
# 4. 卸载
# ============================================================
uninstall_qbt() {
    separator
    echo -e "${RED}  qBittorrent 卸载${NC}"
    separator

    if ! check_qbt_installed && ! command -v qbittorrent-nox &>/dev/null; then
        err "qBittorrent 未安装"
        return 1
    fi

    echo -e "${RED}  ⚠ 此操作将完全删除 qBittorrent 及其所有数据!${NC}"
    echo ""
    read -r -p "  确认卸载? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        info "取消卸载"
        return 0
    fi

    # 停止服务
    if command -v systemctl &>/dev/null; then
        systemctl stop qbittorrent-nox 2>/dev/null || true
        systemctl disable qbittorrent-nox 2>/dev/null || true
        rm -f "$SERVICE_FILE"
        systemctl daemon-reload
        ok "systemd 服务已移除"
    fi

    # 杀死进程
    pkill -f qbittorrent-nox 2>/dev/null || true
    sleep 1

    # 删除二进制文件
    if [[ -f "$QB_BIN" ]]; then
        rm -rf "$QB_DIR"
        ok "安装目录已删除: $QB_DIR"
    fi

    # apt 安装的也一并删除
    if command -v apt &>/dev/null; then
        if apt remove -y qbittorrent-nox 2>/dev/null; then
            ok "apt 包已移除"
        else
            true
        fi
    fi

    # 询问是否删除配置和数据
    echo ""
    read -r -p "  删除配置文件和下载数据? (yes/no): " del_data
    if [[ "$del_data" == "yes" ]]; then
        rm -rf "$QB_CONFIG_DIR"
        rm -f "$QB_LOG"
        rm -f "$PASS_FILE"
        ok "配置文件已删除: $QB_CONFIG_DIR"
        ok "密码文件已删除"
        echo ""
        warn "下载数据目录 (~/Downloads/qBittorrent 等) 需手动删除"
    else
        info "保留配置文件: $QB_CONFIG_DIR"
    fi

    ok "卸载完成!"
    separator
}

# ============================================================
# 5. 状态查看
# ============================================================
show_status() {
    separator
    echo -e "${CYAN}  qBittorrent 状态${NC}"
    separator

    if check_qbt_installed; then
        local ver
        ver=$("$QB_BIN" --version 2>/dev/null || echo "未知")
        echo -e "  ${GREEN}安装状态: ${NC}已安装"
        echo -e "  ${GREEN}版本:     ${NC}$ver"
        echo -e "  ${GREEN}路径:     ${NC}$QB_BIN"
    elif command -v qbittorrent-nox &>/dev/null; then
        echo -e "  ${GREEN}安装状态: ${NC}已安装 (apt)"
        echo -e "  ${GREEN}路径:     ${NC}$(which qbittorrent-nox)"
    else
        echo -e "  ${RED}安装状态: ${NC}未安装"
    fi

    if command -v systemctl &>/dev/null; then
        if systemctl is-active --quiet qbittorrent-nox 2>/dev/null; then
            echo -e "  ${GREEN}服务状态: ${NC}运行中"
        else
            echo -e "  ${YELLOW}服务状态: ${NC}未运行"
        fi
        local enabled
        enabled=$(systemctl is-enabled qbittorrent-nox 2>/dev/null) || enabled="未设置"
        echo -e "  ${GREEN}开机自启: ${NC}$enabled"
    fi

    if [[ -f "$QB_CONF" ]]; then
        echo -e "  ${GREEN}配置文件: ${NC}$QB_CONF"
        local port
        port=$(grep -oP 'WebUI\\Port=\K\d+' "$QB_CONF" 2>/dev/null || echo "$WEBUI_PORT")
        echo -e "  ${GREEN}WebUI 端口:${NC} $port"
    fi

    if [[ -f "$PASS_FILE" ]]; then
        echo -e "  ${GREEN}密码文件: ${NC}$PASS_FILE (已保存)"
    fi

    separator
}

# ============================================================
# 主菜单
# ============================================================
main_menu() {
    while true; do
        if [[ -n "${TERM:-}" && "$TERM" != "dumb" ]]; then clear; fi
        separator
        echo -e "  ${CYAN}qBittorrent 管理脚本${NC}"
        echo -e "  ${BLUE}Linux 一键安装 / 密码管理 / 卸载${NC}"
        separator
        echo ""
        echo -e "  ${GREEN}1.${NC} 安装 qBittorrent"
        echo -e "  ${GREEN}2.${NC} 查看默认密码"
        echo -e "  ${GREEN}3.${NC} 修改 WebUI 密码"
        echo -e "  ${GREEN}4.${NC} 卸载 qBittorrent"
        echo -e "  ${GREEN}5.${NC} 查看状态"
        echo -e "  ${GREEN}0.${NC} 退出"
        echo ""
        separator
        read -r -p "  请选择 [0-5]: " choice
        echo ""

        case "$choice" in
            1) install_qbt ;;
            2) show_password ;;
            3) change_password ;;
            4) uninstall_qbt ;;
            5) show_status ;;
            0)
                info "bye!"
                exit 0
                ;;
            *)
                warn "无效选项: $choice"
                ;;
        esac

        echo ""
        read -r -p "  按 Enter 返回菜单..."
    done
}

# ============================================================
# 入口：支持命令行参数
# ============================================================
case "${1:-}" in
    install|i)      install_qbt ;;
    password|pass|p) show_password ;;
    change-pass|c)  change_password ;;
    uninstall|u)    uninstall_qbt ;;
    status|s)       show_status ;;
    *)              main_menu ;;
esac