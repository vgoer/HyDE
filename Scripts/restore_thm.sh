#!/usr/bin/env bash
# 主题恢复脚本 - 导入和安装主题

# 获取脚本所在目录的绝对路径
scrDir="$(dirname "$(realpath "$0")")"
# shellcheck disable=SC1091
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

# 设置主题导入相关变量
THEME_IMPORT_ASYNC=${THEME_IMPORT_ASYNC:-0}                    # 异步导入标志
THEME_IMPORT_FILE="${1:-${scrDir}/themepatcher.lst}"          # 主题列表文件
confDir=${confDir:-"$HOME/.config"}                           # 配置目录
flg_ThemeInstall=${flg_ThemeInstall:-1}                       # 主题安装标志
flg_DryRun=${flg_DryRun:-0}                                   # 测试运行标志

# 检查主题列表文件是否存在
if [ ! -f "$THEME_IMPORT_FILE" ] || [ -z "$THEME_IMPORT_FILE" ]; then
    print_log -crit "error" "'$THEME_IMPORT_FILE'  No such file or directory"
    exit 1
fi

# 如果启用主题安装
if [ "$flg_ThemeInstall" -eq 1 ]; then
    print_log -g "[THEME] " -warn "imports" "from List $THEME_IMPORT_FILE"
    
    # 读取主题列表文件
    while IFS='"' read -r _ themeName _ themeRepo; do
        # 将主题名称和仓库添加到数组
        themeNameQ+=("${themeName//\"/}")                      # 主题名称数组
        themeRepoQ+=("${themeRepo//\"/}")                      # 主题仓库数组
        
        # 创建主题目录
        themePath="${confDir}/hyde/themes/${themeName}"
        [ -d "${themePath}" ] || mkdir -p "${themePath}"
        
        # 创建排序文件（如果不存在）
        [ -f "${themePath}/.sort" ] || echo "${#themeNameQ[@]}" >"${themePath}/.sort"

        # 同步导入模式
        if [ "${THEME_IMPORT_ASYNC}" -ne 1 ] && [ "${flg_DryRun}" -ne 1 ]; then
            # 使用themepatcher.sh导入主题
            if ! "${scrDir}/themepatcher.sh" "${themeName}" "${themeRepo}" "--skipcaching" "false"; then
                print_log -r "[THEME] " -crit "error" "importing" "${themeName}"
            else
                print_log -g "[THEME] " -stat "added" "${themeName}"
            fi
        else
            # 测试运行模式或异步模式：只显示添加信息
            print_log -g "[THEME] " -stat "added" "${themeName}"
        fi

    done <"$THEME_IMPORT_FILE"

    # 异步导入模式
    if [ "${THEME_IMPORT_ASYNC}" -eq 1 ]; then
        set +e  # 禁用错误退出
        # 使用parallel并行导入主题
        parallel --bar --link "\"${scrDir}/themepatcher.sh\"" "{1}" "{2}" "{3}" "{4}" ::: "${themeNameQ[@]}" ::: "${themeRepoQ[@]}" ::: "--skipcaching" ::: "false"
        set -e  # 重新启用错误退出
    fi
    
    # 提醒用户缓存壁纸
    print_log -y "Be sure to cache the wallpapers!"
fi
