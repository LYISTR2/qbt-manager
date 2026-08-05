# qBittorrent Manager

Linux 一键脚本：安装、密码提取、修改密码、卸载，支持远程一条命令直接管理。

## 功能

- **安装** — 自动检测架构，下载最新静态编译 qbittorrent-nox，首次启动自动捕获随机密码并持久化保存
- **查看密码** — 显示保存的默认密码
- **修改密码** — 停止服务 → 改密码 → 重启，支持手动输入或自动生成 16 位随机密码
- **卸载** — 停止服务、删 systemd、删二进制，可选删配置和下载数据
- **状态查看** — 版本、服务运行状态、端口、密码文件

## 一键安装

```bash
curl -sSL https://raw.githubusercontent.com/LYISTR2/qbt-manager/main/install.sh | sudo bash
```

## 远程快捷管理

无需登录服务器，一条命令直接操作（自动下载最新脚本）：

```bash
# 查看密码
curl -sSL https://raw.githubusercontent.com/LYISTR2/qbt-manager/main/install.sh | sudo bash -s password

# 修改密码
curl -sSL https://raw.githubusercontent.com/LYISTR2/qbt-manager/main/install.sh | sudo bash -s change-pass

# 查看状态
curl -sSL https://raw.githubusercontent.com/LYISTR2/qbt-manager/main/install.sh | sudo bash -s status

# 卸载
curl -sSL https://raw.githubusercontent.com/LYISTR2/qbt-manager/main/install.sh | sudo bash -s uninstall
```

## 本机命令

安装后 `qbt-manager` 命令可用：

```bash
qbt-manager              # 交互菜单
qbt-manager password     # 查看密码
qbt-manager change-pass  # 改密码
qbt-manager status       # 查看状态
qbt-manager uninstall    # 卸载
```

## 手动使用

```bash
sudo bash qbt-manager.sh            # 交互菜单
sudo bash qbt-manager.sh install    # 直接安装
sudo bash qbt-manager.sh password   # 查看密码
sudo bash qbt-manager.sh change-pass  # 改密码
sudo bash qbt-manager.sh uninstall  # 卸载
sudo bash qbt-manager.sh status     # 查看状态
```

## 支持

- Debian / Ubuntu / CentOS
- x86_64 / aarch64
- qBittorrent 4.x / 5.x
