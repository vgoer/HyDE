#!/usr/bin/env bash
# shellcheck disable=SC2154
#|---/ /+------------------------------------+---/ /|#
#|--/ /-| Script to extract fonts and themes |--/ /-|#
#|-/ /--| Prasanth Rangan                    |-/ /--|#
#|/ /---+------------------------------------+/ /---|#
# 字体和主题提取脚本 - 解压字体和主题文件

# 设置测试运行标志
flg_DryRun=${flg_DryRun:-0}

# 获取脚本所在目录的绝对路径
scrDir=$(dirname "$(realpath "$0")")
export log_section="extract"
# shellcheck disable=SC1091
if ! source "${scrDir}/global_fn.sh"; then
    echo -e "\e[31mError: unable to source global_fn.sh...\e[0m"
    exit 1
fi

# 读取字体列表文件
while read -r lst; do
    # 跳过以#开头的注释行
    if [[ "$lst" =~ ^[[:space:]]*# ]]; then
        continue
    fi
    # 检查行是否包含正确的字段数（用|分隔的2个字段）
    if [ "$(echo "$lst" | awk -F '|' '{print NF}')" -ne 2 ]; then
        continue
    fi

    # 解析字体文件名和目标路径
    fnt=$(awk -F '|' '{print $1}' <<<"$lst")  # 字体文件名
    tgt=$(awk -F '|' '{print $2}' <<<"$lst")  # 目标路径
    tgt=$(eval "echo $tgt")                    # 展开路径变量

    # 检测NixOS系统并调整目标路径
    if [[ "${tgt}" =~ /(usr|usr\/local)\/share/ && -d /run/current-system/sw/share/ ]]; then
        echo "Detected NixOS system, changing target to /run/current-system/sw/share/..."
        continue
    fi

    # 创建目标目录（如果不存在）
    if [ ! -d "${tgt}" ]; then
        if ! mkdir -p "${tgt}"; then
            print_log -warn "create" "directory as root instead..."
            [ "${flg_DryRun}" -eq 1 ] || sudo mkdir -p "${tgt}"
        fi

    fi

    # 解压字体文件
    if [ -w "${tgt}" ]; then
        # 目标目录可写，直接解压
        # shellcheck disable=SC2154
        [ "${flg_DryRun}" -eq 1 ] || tar -xzf "${cloneDir}/Source/arcs/${fnt}.tar.gz" -C "${tgt}/"
    else
        # 目标目录不可写，使用sudo解压
        print_log -warn "not writable" "Extracting as root: ${tgt} "
        if [ "${flg_DryRun}" -ne 1 ]; then
            if ! sudo tar -xzf "${cloneDir}/Source/arcs/${fnt}.tar.gz" -C "${tgt}/" 2>/dev/null; then
                print_log -err "extraction by root FAILED" " giving up..."
                print_log "The above error can be ignored if the '${tgt}' is not writable..."
            fi
        fi
    fi
    print_log "${fnt}.tar.gz" -r " --> " "${tgt}... "

done <"${scrDir}/restore_fnt.lst"

# 重建字体缓存
echo ""
print_log -stat "rebuild" "font cache"
[ "${flg_DryRun}" -eq 1 ] || fc-cache -f
