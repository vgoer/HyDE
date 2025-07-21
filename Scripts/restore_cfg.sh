#!/usr/bin/env bash
# shellcheck disable=SC2154
# shellcheck disable=SC1091
#|---/ /+--------------------------------+---/ /|#
#|--/ /-| Script to restore hyde configs |--/ /-|#
#|-/ /--| Prasanth Rangan                |-/ /--|#
#|/ /---+--------------------------------+/ /---|#
# HyDE配置文件恢复脚本 - 恢复系统配置文件

# 部署列表格式配置文件的函数
# 处理格式：覆盖标志|备份标志|路径|配置文件|依赖包
deploy_list() {

    while read -r lst; do

        # 检查行是否包含5个字段（用|分隔）
        if [ "$(awk -F '|' '{print NF}' <<<"${lst}")" -ne 5 ]; then
            continue
        fi
        # 跳过以'#'开头的注释行
        if [[ "${lst}" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        # 解析配置行
        ovrWrte=$(awk -F '|' '{print $1}' <<<"${lst}")  # 覆盖标志
        bkpFlag=$(awk -F '|' '{print $2}' <<<"${lst}")  # 备份标志
        pth=$(awk -F '|' '{print $3}' <<<"${lst}")      # 目标路径
        pth=$(eval echo "${pth}")                       # 展开路径变量
        cfg=$(awk -F '|' '{print $4}' <<<"${lst}")      # 配置文件
        pkg=$(awk -F '|' '{print $5}' <<<"${lst}")      # 依赖包

        # 检查依赖包是否已安装
        while read -r pkg_chk; do
            if ! pkg_installed "${pkg_chk}"; then
                echo -e "\033[0;33m[skip]\033[0m ${pth}/${cfg} as dependency ${pkg_chk} is not installed..."
                continue 2  # 跳过当前配置
            fi
        done < <(echo "${pkg}" | xargs -n 1)

        # 处理每个配置文件
        echo "${cfg}" | xargs -n 1 | while read -r cfg_chk; do
            if [[ -z "${pth}" ]]; then continue; fi
            tgt="${pth/#$HOME/}"  # 移除HOME路径前缀

            # 如果需要备份且文件存在
            if { [ -d "${pth}/${cfg_chk}" ] || [ -f "${pth}/${cfg_chk}" ]; } && [ "${bkpFlag}" == "Y" ]; then

                # 创建备份目录
                if [ ! -d "${BkpDir}${tgt}" ]; then
                    [[ ${flg_DryRun} -ne 1 ]] && mkdir -p "${BkpDir}${tgt}"
                fi

                # 根据覆盖标志决定备份方式
                if [ "${ovrWrte}" == "Y" ]; then
                    [[ ${flg_DryRun} -ne 1 ]] && mv "${pth}/${cfg_chk}" "${BkpDir}${tgt}"  # 移动备份
                else
                    [[ ${flg_DryRun} -ne 1 ]] && cp -r "${pth}/${cfg_chk}" "${BkpDir}${tgt}"  # 复制备份
                fi
                echo -e "\033[0;34m[backup]\033[0m ${pth}/${cfg_chk} --> ${BkpDir}${tgt}..."
            fi

            # 创建目标目录
            if [ ! -d "${pth}" ]; then
                [[ ${flg_DryRun} -ne 1 ]] && mkdir -p "${pth}"
            fi

            # 恢复配置文件
            if [ ! -f "${pth}/${cfg_chk}" ]; then
                [[ ${flg_DryRun} -ne 1 ]] && cp -r "${CfgDir}${tgt}/${cfg_chk}" "${pth}"
                echo -e "\033[0;32m[restore]\033[0m ${pth} <-- ${CfgDir}${tgt}/${cfg_chk}..."
            elif [ "${ovrWrte}" == "Y" ]; then
                [[ ${flg_DryRun} -ne 1 ]] && cp -r "${CfgDir}${tgt}/${cfg_chk}" "${pth}"
                echo -e "\033[0;33m[overwrite]\033[0m ${pth} <-- ${CfgDir}${tgt}/${cfg_chk}..."
            else
                echo -e "\033[0;33m[preserve]\033[0m Skipping ${pth}/${cfg_chk} to preserve user setting..."
            fi
        done

    done <<<"$(cat "${CfgLst}")"
}

# 部署PSV格式配置文件的函数
# 处理格式：控制标志|路径|配置文件|依赖包
deploy_psv() {
    print_log -g "[file extension]" -b " :: " "File: ${CfgLst}"
    while read -r lst; do

        # 跳过不是4个字段的行
        if [ "$(awk -F '|' '{print NF}' <<<"${lst}")" -ne 4 ]; then
            if [[ "${lst}" =~ ^  ]]; then
                echo ""
                print_log -b "${lst}"  # 显示分组标题
            fi
            continue
        fi
        # 跳过注释行
        if [[ "${lst}" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        # 解析配置行
        ctlFlag=$(awk -F '|' '{print $1}' <<<"${lst}")  # 控制标志
        pth=$(awk -F '|' '{print $2}' <<<"${lst}")      # 目标路径
        pth=$(eval "echo ${pth}")                       # 展开路径变量
        cfg=$(awk -F '|' '{print $3}' <<<"${lst}")      # 配置文件
        pkg=$(awk -F '|' '{print $4}' <<<"${lst}")      # 依赖包

        # 检查是否为忽略标志
        if [[ "${ctlFlag}" = "I" ]]; then
            print_log -r "[ignore] :: " "${pth}/${cfg}"
            continue 2
        fi

        # 检查依赖包
        while read -r pkg_chk; do
            if ! pkg_installed "${pkg_chk}"; then
                print_log -y "[skip] " -r "missing" -b " :: " -y "missing dependency" -g " '${pkg_chk}'" -r " --> " "${pth}/${cfg}"
                continue 2
            fi
        done < <(echo "${pkg}" | xargs -n 1)

        # 处理每个配置文件
        echo "${cfg}" | xargs -n 1 | while read -r cfg_chk; do
            if [[ -z "${pth}" ]]; then continue; fi
            tgt="${pth//${HOME}/}"  # 移除HOME路径前缀
            crnt_cfg="${pth}/${cfg_chk}"

            # 检查源文件是否存在
            if [ ! -e "${CfgDir}${tgt}/${cfg_chk}" ] && [ "${ctlFlag}" != "B" ]; then
                echo "Source: ${CfgDir}${tgt}/${cfg_chk} does not exist, skipping..."
                print_log -y "[skip]" -b "no source" "${CfgDir}${tgt}/${cfg_chk} does not exist"
                continue
            fi

            # 创建目标目录
            [[ ! -d "${pth}" ]] && [[ ${flg_DryRun} -ne 1 ]] && mkdir -p "${pth}"

            if [ -e "${crnt_cfg}" ]; then
                # 创建备份目录
                [[ ! -d "${BkpDir}${tgt}" ]] && [[ ${flg_DryRun} -ne 1 ]] && mkdir -p "${BkpDir}${tgt}"

                # 根据控制标志执行不同操作
                case "${ctlFlag}" in
                "B")  # 仅备份
                    [ "${flg_DryRun}" -ne 1 ] && cp -r "${pth}/${cfg_chk}" "${BkpDir}${tgt}"
                    print_log -g "[copy backup]" -b " :: " "${pth}/${cfg_chk} --> ${BkpDir}${tgt}..."
                    ;;
                "O")  # 覆盖（移动备份后覆盖）
                    [ "${flg_DryRun}" -ne 1 ] && mv "${pth}/${cfg_chk}" "${BkpDir}${tgt}"
                    [ "${flg_DryRun}" -ne 1 ] && cp -r "${CfgDir}${tgt}/${cfg_chk}" "${pth}"
                    print_log -r "[move to backup]" " > " -r "[overwrite]" -b " :: " "${pth}" -r " <-- " "${CfgDir}${tgt}/${cfg_chk}"
                    ;;
                "S")  # 同步（复制备份后覆盖）
                    [ "${flg_DryRun}" -ne 1 ] && cp -r "${pth}/${cfg_chk}" "${BkpDir}${tgt}"
                    [ "${flg_DryRun}" -ne 1 ] && cp -rf "${CfgDir}${tgt}/${cfg_chk}" "${pth}"
                    print_log -g "[copy to backup]" " > " -y "[sync]" -b " :: " "${pth}" -r " <--  " "${CfgDir}${tgt}/${cfg_chk}"
                    ;;
                "P")  # 填充（复制备份后填充，不覆盖现有文件）
                    [ "${flg_DryRun}" -ne 1 ] && cp -r "${pth}/${cfg_chk}" "${BkpDir}${tgt}"
                    if ! [ "${flg_DryRun}" -ne 1 ] && cp -rn "${CfgDir}${tgt}/${cfg_chk}" "${pth}" 2>/dev/null; then
                        print_log -g "[copy to backup]" " > " -y "[populate]" -b " :: " "${pth}${tgt}/${cfg_chk}"
                    else
                        print_log -g "[copy to backup]" " > " -y "[preserved]" -b " :: " "${pth}" + 208 " <--  " "${CfgDir}${tgt}/${cfg_chk}"
                    fi
                    ;;
                esac
            else
                # 文件不存在时的处理
                if [ "${ctlFlag}" != "B" ]; then
                    [ "${flg_DryRun}" -ne 1 ] && cp -r "${CfgDir}${tgt}/${cfg_chk}" "${pth}"
                    print_log -y "[*populate*]" -b " :: " "${pth}" -r " <--  " "${CfgDir}${tgt}/${cfg_chk}"
                fi
            fi

        done

    done <"${1}"
}

# 设置日志部分和测试运行标志
# shellcheck disable=SC2034
log_section="deploy"
flg_DryRun=${flg_DryRun:-0}

# 获取脚本目录并导入全局函数
scrDir=$(dirname "$(realpath "$0")")
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

# 确定默认配置文件列表
[ -f "${scrDir}/restore_cfg.lst" ] && defaultLst="restore_cfg.lst"
[ -f "${scrDir}/restore_cfg.psv" ] && defaultLst="restore_cfg.psv"
[ -f "${scrDir}/restore_cfg.json" ] && defaultLst="restore_cfg.json"
[ -f "${scrDir}/${USER}-restore_cfg.psv" ] && defaultLst="$USER-restore_cfg.psv"

# 设置配置文件路径和目录
CfgLst="${1:-"${scrDir}/${defaultLst}"}"        # 配置文件列表
CfgDir="${2:-${cloneDir}/Configs}"              # 配置源目录
ThemeOverride="${3:-}"                          # 主题覆盖

# 检查文件和目录是否存在
if [ ! -f "${CfgLst}" ] || [ ! -d "${CfgDir}" ]; then
    echo "ERROR: '${CfgLst}' or '${CfgDir}' does not exist..."
    exit 1
fi

# 创建备份目录（带时间戳）
BkpDir="${HOME}/.config/cfg_backups/$(date +'%y%m%d_%Hh%Mm%Ss')${ThemeOverride}"

# 检查备份目录是否已存在
if [ -d "${BkpDir}" ]; then
    echo "ERROR: ${BkpDir} exists!"
    exit 1
else
    [[ ${flg_DryRun} -ne 1 ]] && mkdir -p "${BkpDir}"
fi

# 根据文件扩展名选择部署方法
file_extension="${CfgLst##*.}"
echo ""
print_log -g "[file extension]" -b " :: " "${file_extension}"
case "${file_extension}" in
"lst")
    deploy_list "${CfgLst}"  # 部署列表格式
    ;;
"psv")
    deploy_psv "${CfgLst}"   # 部署PSV格式
    ;;
json)
    deploy_json "${CfgLst}"  # 部署JSON格式
    ;;
esac
echo ""

# 保存版本信息
print_log -g "[version]" -b " :: " "saving version info..."
"${scrDir}/version.sh" --cache || echo "Failed to save version info."
