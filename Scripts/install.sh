#!/usr/bin/env bash
# shellcheck disable=SC2154
#|---/ /+--------------------------+---/ /|#
#|--/ /-| Main installation script |--/ /-|#
#|-/ /--| Prasanth Rangan          |-/ /--|#
#|/ /---+--------------------------+/ /---|#
# HyDE 主安装脚本 - 用于安装和配置 Hyprland 桌面环境

# 显示 HyDE 的 ASCII 艺术标题
cat <<"EOF"

-------------------------------------------------
        .
       / \         _       _  _      ___  ___
      /^  \      _| |_    | || |_  _|   \| __|
     /  _  \    |_   _|   | __ | || | |) | _|
    /  | | ~\     |_|     |_||_|\_, |___/|___|
   /.-'   '-.\                  |__/

-------------------------------------------------

EOF

#--------------------------------#
# import variables and functions #
#--------------------------------#
# 导入全局函数和变量
scrDir="$(dirname "$(realpath "$0")")"  # 获取脚本所在目录的绝对路径
# shellcheck disable=SC1091
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

#------------------#
# evaluate options #
#------------------#
# 解析命令行参数
# i 只安装hyprland（不安装配置文件）
# d 全部安装（使用默认设置，无需确认）
# r 恢复配置文件
# s 启用系统服务
# n 忽略Nvidia相关操作
# h 重新评估shell选择
# t 测试运行（不实际执行）
# m 不重新安装主题

# 初始化标志变量
flg_Install=0      # 安装标志
flg_Restore=0      # 恢复配置标志
flg_Service=0      # 启用服务标志
flg_DryRun=0       # 测试运行标志
flg_Shell=0        # 重新评估shell标志
flg_Nvidia=1       # Nvidia处理标志（默认启用）
flg_ThemeInstall=1 # 主题安装标志（默认启用）

# 解析命令行参数
while getopts idrstmnh RunStep; do
    case $RunStep in
    i) flg_Install=1 ;;  # 只安装hyprland
    d)
        flg_Install=1
        export use_default="--noconfirm"  # 使用默认设置，无需确认
        ;;
    r) flg_Restore=1 ;;  # 恢复配置文件
    s) flg_Service=1 ;;  # 启用系统服务
    n)
        # shellcheck disable=SC2034
        export flg_Nvidia=0  # 忽略Nvidia相关操作
        print_log -r "[nvidia] " -b "Ignored :: " "skipping Nvidia actions"
        ;;
    h)
        # shellcheck disable=SC2034
        export flg_Shell=1  # 重新评估shell选择
        print_log -r "[shell] " -b "Reevaluate :: " "shell options"
        ;;
    t) flg_DryRun=1 ;;  # 测试运行模式
    m) flg_ThemeInstall=0 ;;  # 不重新安装主题
    *)
        # 显示使用帮助
        cat <<EOF
Usage: $0 [options]
            i : [i]nstall hyprland without configs
            d : install hyprland [d]efaults without configs --noconfirm
            r : [r]estore config files
            s : enable system [s]ervices
            n : ignore/[n]o [n]vidia actions (-irsn to ignore nvidia)
            h : re-evaluate S[h]ell
            m : no the[m]e reinstallations
            t : [t]est run without executing (-irst to dry run all)

NOTE: 
        running without args is equivalent to -irs
        to ignore nvidia, run -irsn

WRONG:
        install.sh -n # This will not work

EOF
        exit 1
        ;;
    esac
done

# 导出将在其他脚本中使用的变量
HYDE_LOG="$(date +'%y%m%d_%Hh%Mm%Ss')"  # 生成日志文件名（时间戳格式）
export flg_DryRun flg_Nvidia flg_Shell flg_Install flg_ThemeInstall HYDE_LOG

# 处理测试运行模式
if [ "${flg_DryRun}" -eq 1 ]; then
    print_log -n "[test-run] " -b "enabled :: " "Testing without executing"
elif [ $OPTIND -eq 1 ]; then
    # 如果没有提供参数，默认执行安装、恢复和服务启用
    flg_Install=1
    flg_Restore=1
    flg_Service=1
fi

#--------------------#
# pre-install script #
#--------------------#
# 预安装脚本 - 在安装和恢复配置之前执行
if [ ${flg_Install} -eq 1 ] && [ ${flg_Restore} -eq 1 ]; then
    cat <<"EOF"
                _         _       _ _
 ___ ___ ___   |_|___ ___| |_ ___| | |
| . |  _| -_|  | |   |_ -|  _| .'| | |
|  _|_| |___|  |_|_|_|___|_| |__,|_|_|
|_|

EOF

    "${scrDir}/install_pre.sh"  # 执行预安装脚本
fi

#------------#
# installing #
#------------#
# 安装阶段 - 安装所需的软件包
if [ ${flg_Install} -eq 1 ]; then
    cat <<"EOF"

 _         _       _ _ _
|_|___ ___| |_ ___| | |_|___ ___
| |   |_ -|  _| .'| | | |   | . |
|_|_|_|___|_| |__,|_|_|_|_|_|_  |
                            |___|

EOF

    #----------------------#
    # prepare package list #
    #----------------------#
    # 准备软件包列表
    shift $((OPTIND - 1))  # 移除已处理的参数
    custom_pkg=$1  # 获取自定义软件包文件路径
    cp "${scrDir}/pkg_core.lst" "${scrDir}/install_pkg.lst"  # 复制核心软件包列表
    trap 'mv "${scrDir}/install_pkg.lst" "${cacheDir}/logs/${HYDE_LOG}/install_pkg.lst"' EXIT  # 设置退出时保存日志

    echo -e "\n#user packages" >>"${scrDir}/install_pkg.lst"  # 添加用户软件包标记
    if [ -f "${custom_pkg}" ] && [ -n "${custom_pkg}" ]; then
        cat "${custom_pkg}" >>"${scrDir}/install_pkg.lst"  # 添加自定义软件包
    fi

    #--------------------------------#
    # add nvidia drivers to the list #
    #--------------------------------#
    # 检测并添加Nvidia驱动到软件包列表
    if nvidia_detect; then
        if [ ${flg_Nvidia} -eq 1 ]; then
            # 为每个内核添加头文件
            cat /usr/lib/modules/*/pkgbase | while read -r kernel; do
                echo "${kernel}-headers" >>"${scrDir}/install_pkg.lst"
            done
            nvidia_detect --drivers >>"${scrDir}/install_pkg.lst"  # 添加Nvidia驱动
        else
            print_log -warn "Nvidia" "Nvidia GPU detected but ignored..."
        fi
    fi
    nvidia_detect --verbose  # 显示详细的Nvidia检测信息

    #----------------#
    # get user prefs #
    #----------------#
    # 获取用户偏好设置
    echo ""
    # 检查AUR助手选择
    if ! chk_list "aurhlpr" "${aurList[@]}"; then
        print_log -c "\nAUR Helpers :: "
        aurList+=("yay-bin" "paru-bin")  # 添加AUR助手选项
        for i in "${!aurList[@]}"; do
            print_log -sec "$((i + 1))" " ${aurList[$i]} "
        done

        prompt_timer 120 "Enter option number [default: yay-bin] | q to quit "

        case "${PROMPT_INPUT}" in
        1) export getAur="yay" ;;
        2) export getAur="paru" ;;
        3) export getAur="yay-bin" ;;
        4) export getAur="paru-bin" ;;
        q)
            print_log -sec "AUR" -crit "Quit" "Exiting..."
            exit 1
            ;;
        *)
            print_log -sec "AUR" -warn "Defaulting to yay-bin"
            print_log -sec "AUR" -stat "default" "yay-bin"
            export getAur="yay-bin"
            ;;
        esac
        if [[ -z "$getAur" ]]; then
            print_log -sec "AUR" -crit "No AUR helper found..." "Log file at ${cacheDir}/logs/${HYDE_LOG}"
            exit 1
        fi
    fi

    # 检查shell选择
    if ! chk_list "myShell" "${shlList[@]}"; then
        print_log -c "Shell :: "
        for i in "${!shlList[@]}"; do
            print_log -sec "$((i + 1))" " ${shlList[$i]} "
        done
        prompt_timer 120 "Enter option number [default: zsh] | q to quit "

        case "${PROMPT_INPUT}" in
        1) export myShell="zsh" ;;
        2) export myShell="fish" ;;
        q)
            print_log -sec "shell" -crit "Quit" "Exiting..."
            exit 1
            ;;
        *)
            print_log -sec "shell" -warn "Defaulting to zsh"
            export myShell="zsh"
            ;;
        esac
        print_log -sec "shell" -stat "Added as shell" "${myShell}"
        echo "${myShell}" >>"${scrDir}/install_pkg.lst"  # 将选择的shell添加到软件包列表

        if [[ -z "$myShell" ]]; then
            print_log -sec "shell" -crit "No shell found..." "Log file at ${cacheDir}/logs/${HYDE_LOG}"
            exit 1
        else
            print_log -sec "shell" -stat "detected :: " "${myShell}"
        fi
    fi

    # 验证用户软件包列表
    if ! grep -q "^#user packages" "${scrDir}/install_pkg.lst"; then
        print_log -sec "pkg" -crit "No user packages found..." "Log file at ${cacheDir}/logs/${HYDE_LOG}/install.sh"
        exit 1
    fi

    #--------------------------------#
    # install packages from the list #
    #--------------------------------#
    # 从列表安装软件包
    "${scrDir}/install_pkg.sh" "${scrDir}/install_pkg.lst"
fi

#---------------------------#
# restore my custom configs #
#---------------------------#
# 恢复自定义配置文件
if [ ${flg_Restore} -eq 1 ]; then
    cat <<"EOF"

             _           _
 ___ ___ ___| |_ ___ ___|_|___ ___
|  _| -_|_ -|  _| . |  _| |   | . |
|_| |___|___|_| |___|_| |_|_|_|_  |
                              |___|

EOF

    # 如果不在测试模式且Hyprland正在运行，禁用自动重载
    if [ "${flg_DryRun}" -ne 1 ] && [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
        hyprctl keyword misc:disable_autoreload 1 -q
    fi

    # 执行各种恢复脚本
    "${scrDir}/restore_fnt.sh"  # 恢复字体
    "${scrDir}/restore_cfg.sh"  # 恢复配置文件
    "${scrDir}/restore_thm.sh"  # 恢复主题
    
    print_log -g "[generate] " "cache ::" "Wallpapers..."
    if [ "${flg_DryRun}" -ne 1 ]; then
        export PATH="$HOME/.local/lib/hyde:${PATH}"
        "$HOME/.local/lib/hyde/swwwallcache.sh" -t ""  # 生成壁纸缓存
        "$HOME/.local/lib/hyde/theme.switch.sh" -q || true  # 切换主题
        echo "[install] reload :: Hyprland"  # 重新加载Hyprland
    fi

fi

#---------------------#
# post-install script #
#---------------------#
# 后安装脚本 - 在安装和恢复配置之后执行
if [ ${flg_Install} -eq 1 ] && [ ${flg_Restore} -eq 1 ]; then
    cat <<"EOF"

             _      _         _       _ _
 ___ ___ ___| |_   |_|___ ___| |_ ___| | |
| . | . |_ -|  _|  | |   |_ -|  _| .'| | |
|  _|___|___|_|    |_|_|_|___|_| |__,|_|_|
|_|

EOF

    "${scrDir}/install_pst.sh"  # 执行后安装脚本
fi

#------------------------#
# enable system services #
#------------------------#
# 启用系统服务
if [ ${flg_Service} -eq 1 ]; then
    cat <<"EOF"

                 _
 ___ ___ ___ _ _|_|___ ___ ___
|_ -| -_|  _| | | |  _| -_|_ -|
|___|___|_|  \_/|_|___|___|___|

EOF

    "${scrDir}/restore_svc.sh"  # 恢复和启用系统服务
fi

# 显示安装完成信息
if [ $flg_Install -eq 1 ]; then
    echo ""
    print_log -g "Installation" " :: " "COMPLETED!"
fi
print_log -b "Log" " :: " -y "View logs at ${cacheDir}/logs/${HYDE_LOG}"

# 询问是否重启系统
if [ $flg_Install -eq 1 ] ||
    [ $flg_Restore -eq 1 ] ||
    [ $flg_Service -eq 1 ] &&
    [ $flg_DryRun -ne 1 ]; then
    print_log -stat "HyDE" "It is not recommended to use newly installed or upgraded HyDE without rebooting the system. Do you want to reboot the system? (y/N)"
    read -r answer

    if [[ "$answer" == [Yy] ]]; then
        echo "Rebooting system"
        systemctl reboot  # 重启系统
    else
        echo "The system will not reboot"
    fi
fi
