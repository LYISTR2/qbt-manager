#!/bin/bash
# ============================================================
# qBittorrent Manager — 一键安装脚本
# 用法: curl -sSL https://raw.githubusercontent.com/LYISTR2/qbt-manager/main/install.sh | bash
# ============================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

REPO="LYISTR2/qbt-manager"
BRANCH="main"
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="qbt-manager"
SCRIPT_PATH="$INSTALL_DIR/$SCRIPT_NAME"

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[✓]${NC} $1"; }
err()   { echo -e "${RED}[✗]${NC} $1"; }

# 检查 root
if [[ $EUID -ne 0 ]]; then
    err "请用 root 权限运行: curl -sSL ... | sudo bash"
    exit 1
fi

# 检测系统
if ! command -v curl &>/dev/null; then
    info "安装 curl..."
    apt update -qq && apt install -y -qq curl 2>/dev/null || yum install -y curl 2>/dev/null || apk add curl 2>/dev/null
fi

# 下载主脚本
info "下载 $SCRIPT_NAME 到 $SCRIPT_PATH ..."
curl -sSL "https://raw.githubusercontent.com/$REPO/$BRANCH/$SCRIPT_NAME.sh" -o "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"
ok "下载完成: $SCRIPT_PATH"

# 自动安装 qBittorrent
echo ""
info "开始安装 qBittorrent..."
"$SCRIPT_PATH" install

# 完成
echo ""
separator() { echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }
separator
echo -e "${GREEN}  安装完成!${NC}"
echo ""
echo -e "  管理命令:"
echo -e "    ${YELLOW}sudo qbt-manager${NC}          交互菜单"
echo -e "    ${YELLOW}sudo qbt-manager password${NC}  查看密码"
echo -e "    ${YELLOW}sudo qbt-manager change-pass${NC} 修改密码"
echo -e "    ${YELLOW}sudo qbt-manager uninstall${NC} 卸载"
echo -e "    ${YELLOW}sudo qbt-manager status${NC}    查看状态"
echo ""
echo -e "  更新:"
echo -e "    ${YELLOW}sudo curl -sSL https://raw.githubusercontent.com/$REPO/$BRANCH/install.sh | bash${NC}"
echo ""
echo -e "  帮助: https://github.com/$REPO"
separator