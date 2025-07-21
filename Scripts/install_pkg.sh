#!/usr/bin/env bash
# shellcheck disable=SC2154
# shellcheck disable=SC1091
#|---/ /+----------------------------------------+---/ /|#
#|--/ /-| Script to install pkgs from input list |--/ /-|#
#|-/ /--| Prasanth Rangan                        |-/ /--|#
#|/ /---+----------------------------------------+/ /---|#
# 软件包安装脚本 - 从输入列表安装软件包

# 获取脚本所在目录的绝对路径
scrDir=$(dirname "$(realpath "$0")")
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

# 设置测试运行标志（如果未定义则默认为0）
flg_DryRun=${flg_DryRun:-0}
export log_section="package"

# 安装AUR助手
"${scrDir}/install_aur.sh" "${getAur}" 2>&1
# 检查AUR助手是否已安装
chk_list "aurhlpr" "${aurList[@]}"
# 设置软件包列表文件路径（默认为核心软件包列表）
listPkg="${1:-"${scrDir}/pkg_core.lst"}"
# 初始化软件包数组
archPkg=()  # Arch官方仓库软件包
aurhPkg=()  # AUR软件包
ofs=$IFS    # 保存原始字段分隔符
IFS='|'     # 设置字段分隔符为管道符

#-----------------------------#
# remove blacklisted packages #
#-----------------------------#
# 移除黑名单中的软件包
if [ -f "${scrDir}/pkg_black.lst" ]; then
    # 过滤掉黑名单中的软件包
    grep -v -f <(grep -v '^#' "${scrDir}/pkg_black.lst" | sed 's/#.*//;s/ //g;/^$/d') <(sed 's/#.*//' "${scrDir}/install_pkg.lst") >"${scrDir}/install_pkg_filtered.lst"
    mv "${scrDir}/install_pkg_filtered.lst" "${scrDir}/install_pkg.lst"
fi

# 读取软件包列表并分类
while read -r pkg deps; do
    pkg="${pkg// /}"  # 移除软件包名中的空格
    if [ -z "${pkg}" ]; then
        continue  # 跳过空行
    fi

    # 检查依赖项
    if [ -n "${deps}" ]; then
        deps="${deps%"${deps##*[![:space:]]}"}"  # 移除尾部空格
        while read -r cdep; do
            # 检查依赖项是否在软件包列表中
            pass=$(cut -d '#' -f 1 "${listPkg}" | awk -F '|' -v chk="${cdep}" '{if($1 == chk) {print 1;exit}}')
            if [ -z "${pass}" ]; then
                if pkg_installed "${cdep}"; then
                    pass=1  # 依赖项已安装
                else
                    break   # 依赖项未安装且不在列表中
                fi
            fi
        done < <(xargs -n1 <<<"${deps}")

        # 如果依赖项检查失败，跳过此软件包
        if [[ ${pass} -ne 1 ]]; then
            print_log -warn "missing" "dependency [ ${deps} ] for ${pkg}..."
            continue
        fi
    fi

    # 分类软件包
    if pkg_installed "${pkg}"; then
        print_log -y "[skip] " "${pkg}"  # 软件包已安装，跳过
    elif pkg_available "${pkg}"; then
        # 软件包在官方仓库中可用
        repo=$(pacman -Si "${pkg}" | awk -F ': ' '/Repository / {print $2}' | tr '\n' ' ')
        print_log -b "[queue] " "${pkg}" -b " :: " -g "${repo}"
        archPkg+=("${pkg}")  # 添加到官方仓库软件包数组
    elif aur_available "${pkg}"; then
        # 软件包在AUR中可用
        print_log -b "[queue] " "${pkg}" -b " :: " -g "aur"
        aurhPkg+=("${pkg}")  # 添加到AUR软件包数组
    else
        print_log -r "[error] " "unknown package ${pkg}..."  # 未知软件包
    fi
done < <(cut -d '#' -f 1 "${listPkg}")

# 恢复原始字段分隔符
IFS=${ofs}

# 安装软件包的函数
# 参数: $1 - 软件包数组引用, $2 - 软件包类型, $3 - 安装命令
install_packages() {
    local -n pkg_array=$1
    local pkg_type=$2
    local install_cmd=$3

    if [[ ${#pkg_array[@]} -gt 0 ]]; then
        print_log -b "[install] " "$pkg_type packages..."
        if [ "${flg_DryRun}" -eq 1 ]; then
            # 测试运行模式：只显示要安装的软件包
            for pkg in "${pkg_array[@]}"; do
                print_log -b "[pkg] " "${pkg}"
            done
        else
            # 实际安装模式：执行安装命令
            $install_cmd ${use_default:+"$use_default"} -S "${pkg_array[@]}"
        fi
    fi
}

# 安装官方仓库软件包
echo ""
install_packages archPkg "arch" "sudo pacman"
# 安装AUR软件包
echo ""
install_packages aurhPkg "aur" "${aurhlpr}"
