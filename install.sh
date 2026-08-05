#!/bin/bash
# ============================================================
# qBittorrent Manager — 一键安装 / 快捷管理脚本
#
# 用法:
#   完整安装:  curl -sSL <url> | sudo bash
#   查看密码:  curl -sSL <url> | sudo bash -s password
#   修改密码:  curl -sSL <url> | sudo bash -s change-pass
#   查看状态:  curl -sSL <url> | sudo bash -s status
#   卸载:      curl -sSL <url> | sudo bash -s uninstall
# ============================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

REPO="LYISTR2/qbt-manager"
BRANCH="main"
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="qbt-manager"
SCRIPT_PATH="$INSTALL_DIR/$SCRIPT_NAME"
BASE_URL="https://raw.githubusercontent.com/$REPO/$BRANCH"

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[✓]${NC} $1"; }
err()   { echo -e "${RED}[✗]${NC} $1"; }

# 检查 root
if [[ $EUID -ne 0 ]]; then
    err "请用 root 权限运行: curl -sSL ... | sudo bash"
    exit 1
fi

# 检测并安装 curl
if ! command -v curl &>/dev/null; then
    info "安装 curl..."
    apt update -qq && apt install -y -qq curl 2>/dev/null || yum install -y curl 2>/dev/null || apk add curl 2>/dev/null
fi

# 下载主脚本 (始终获取最新版)
info "下载 $SCRIPT_NAME 到 $SCRIPT_PATH ..."
curl -sSL "$BASE_URL/$SCRIPT_NAME.sh" -o "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"
ok "下载完成: $SCRIPT_PATH"

# 有子命令 → 直接透传给 qbt-manager
if [[ $# -gt 0 ]]; then
    case "$1" in
        install|i)
            "$SCRIPT_PATH" install
            ;;
        password|pass|p)
            "$SCRIPT_PATH" password
            ;;
        change-pass|c)
            "$SCRIPT_PATH" change-pass
            ;;
        status|s)
            "$SCRIPT_PATH" status
            ;;
        uninstall|u)
            "$SCRIPT_PATH" uninstall
            ;;
        *)
            err "未知命令: $1"
            echo ""
            echo "  可用命令: install | password | change-pass | status | uninstall"
            exit 1
            ;;
    esac
    exit $?
fi

# 无子命令 → 完整安装
echo ""
info "开始安装 qBittorrent..."
"$SCRIPT_PATH" install

# 完成
echo ""
separator() { echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }
separator
echo -e "${GREEN}  安装完成!${NC}"
echo ""
echo -e "  本机管理:"
echo -e "    ${YELLOW}sudo qbt-manager${NC}                   交互菜单"
echo -e "    ${YELLOW}sudo qbt-manager password${NC}           查看密码"
echo -e "    ${YELLOW}sudo qbt-manager change-pass${NC}        修改密码"
echo -e "    ${YELLOW}sudo qbt-manager status${NC}             查看状态"
echo -e "    ${YELLOW}sudo qbt-manager uninstall${NC}          卸载"
echo ""
echo -e "  远程快捷管理 (免登录服务器执行):"
echo -e "    ${YELLOW}curl -sSL $BASE_URL/install.sh | sudo bash -s password${NC}"
echo -e "    ${YELLOW}curl -sSL $BASE_URL/install.sh | sudo bash -s change-pass${NC}"
echo -e "    ${YELLOW}curl -sSL $BASE_URL/install.sh | sudo bash -s status${NC}"
echo ""
echo -e "  更新本脚本:"
echo -e "    ${YELLOW}sudo curl -sSL $BASE_URL/install.sh | bash${NC}"
echo ""
echo -e "  帮助: https://github.com/$REPO"
separator