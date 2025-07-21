#!/usr/bin/env bash
#|---/ /+-------------------------------------------+---/ /|#
#|--/ /-| Script to install aur helper, yay or paru |--/ /-|#
#|-/ /--| Prasanth Rangan                           |-/ /--|#
#|/ /---+-------------------------------------------+/ /---|#
# AUR助手安装脚本 - 安装yay或paru

# 获取脚本所在目录的绝对路径
scrDir=$(dirname "$(realpath "$0")")
# shellcheck disable=SC1091
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

# shellcheck disable=SC2154
# 检查AUR助手是否已安装
if chk_list "aurhlpr" "${aurList[@]}"; then
    print_log -sec "AUR" -stat "Detected" "${aurhlpr}"
    exit 0  # 如果已安装，直接退出
fi

# 设置AUR助手名称（默认为yay-bin）
aurhlpr="${1:-yay-bin}"

# 创建或检查Clone目录
if [ -d "$HOME/Clone" ]; then
    print_log -sec "AUR" -stat "exist" "$HOME/Clone directory..."
    # 如果目录存在，删除旧的AUR助手目录
    rm -rf "$HOME/Clone/${aurhlpr}"
else
    # 创建Clone目录
    mkdir "$HOME/Clone"
    # 创建目录图标文件
    echo -e "[Desktop Entry]\nIcon=default-folder-git" >"$HOME/Clone/.directory"
    print_log -sec "AUR" -stat "created" "$HOME/Clone directory..."
fi

# 检查git是否已安装
if pkg_installed git; then
    # 克隆AUR助手仓库
    git clone "https://aur.archlinux.org/${aurhlpr}.git" "$HOME/Clone/${aurhlpr}"
else
    print_log -sec "AUR" -stat "missing" "'git' as dependency..."
    exit 1  # git未安装，退出
fi

# 进入AUR助手目录
cd "$HOME/Clone/${aurhlpr}" || exit
# shellcheck disable=SC2154
# 编译并安装AUR助手
if makepkg "${use_default}" -si; then
    print_log -sec "AUR" -stat "installed" "${aurhlpr} aur helper..."
    exit 0  # 安装成功
else
    print_log -r "AUR" -stat "failed" "${aurhlpr} installation failed..."
    echo "${aurhlpr} installation failed..."
    exit 1  # 安装失败
fi
