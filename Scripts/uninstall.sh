#!/usr/bin/env bash
#|---/ /+-------------------------------+---/ /|#
#|--/ /-| Script to remove HyDE configs |--/ /-|#
#|-/ /--| Prasanth Rangan               |-/ /--|#
#|/ /---+-------------------------------+/ /---|#
# HyDE卸载脚本 - 移除HyDE配置文件

# 显示警告信息
cat <<"EOF"

-------------------------------------------------
        .
       / \                 _  _      ___  ___
      /^  \      _____    | || |_  _|   \| __|
     /  _  \    |_____|   | __ | || | |) | _|
    /  | | ~\             |_||_|\_, |___/|___|
   /.-'   '-.\                  |__/

-------------------------------------------------


.: WARNING :: This will remove all config files related to HyDE :.

please type "DONT HYDE" to continue...
EOF

# 用户确认
read -r PROMPT_INPUT
[ "${PROMPT_INPUT}" == "DONT HYDE" ] || exit 0

# 显示卸载标题
cat <<"EOF"

         _         _       _ _
 _ _ ___|_|___ ___| |_ ___| | |
| | |   | |   |_ -|  _| .'| | |
|___|_|_|_|_|_|___|_| |__,|_|_|


EOF

# 获取脚本目录并导入全局函数
scrDir=$(dirname "$(realpath "$0")")
source "${scrDir}/global_fn.sh"
if [ $? -ne 0 ]; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

# 设置配置文件列表路径
CfgLst="${scrDir}/restore_cfg.lst"
if [ ! -f "${CfgLst}" ]; then
    echo "ERROR: '${CfgLst}' does not exist..."
    exit 1
fi

# 创建备份目录（用于保存被移除的配置文件）
BkpDir="${HOME}/.config/cfg_backups/$(date +'%y%m%d_%Hh%Mm%Ss')_remove"
mkdir -p "${BkpDir}"

# 读取配置文件列表并移除配置文件
cat "${CfgLst}" | while read lst; do
    # 解析配置行
    pth=$(echo "${lst}" | awk -F '|' '{print $3}')  # 路径
    pth=$(eval echo "${pth}")                       # 展开路径变量
    cfg=$(echo "${lst}" | awk -F '|' '{print $4}')  # 配置文件

    # 处理每个配置文件
    echo "${cfg}" | xargs -n 1 | while read -r cfg_chk; do
        [[ -z "${pth}" ]] && continue
        # 如果配置文件存在，移动到备份目录
        if [ -d "${pth}/${cfg_chk}" ] || [ -f "${pth}/${cfg_chk}" ]; then
            tgt=$(echo "${pth}" | sed "s+^${HOME}++g")  # 移除HOME路径前缀
            if [ ! -d "${BkpDir}${tgt}" ]; then
                mkdir -p "${BkpDir}${tgt}"
            fi
            mv "${pth}/${cfg_chk}" "${BkpDir}${tgt}"  # 移动文件到备份目录
            echo -e "\033[0;34m[removed]\033[0m ${pth}/${cfg_chk}"
        fi
    done
done

# 移除HyDE相关目录
[ -d "$HOME/.config/hyde" ] && rm -rf "$HOME/.config/hyde"      # 配置目录
[ -d "$HOME/.cache/hyde" ] && rm -rf "$HOME/.cache/hyde"        # 缓存目录
[ -d "$HOME/.local/state/hyde" ] && rm -rf "$HOME/.local/state/hyde"  # 状态目录

# 显示手动操作说明
cat <<"NOTE"
-------------------------------------------------------
.: Manual action required to complete uninstallation :.
-------------------------------------------------------

Remove HyDE related backups/icons/fonts/themes manually from these paths
$HOME/.config/cfg_backups               # remove all previous backups
$HOME/.local/share/fonts                # remove fonts from here
$HOME/.local/share/icons                # remove fonts from here
$HOME/.local/share/themes               # remove fonts from here
$HOME/.icons                            # remove icons from here
$HOME/.themes                           # remove themes from here

Revert back bootloader/pacman/sddm settings manually from these backups
/boot/loader/entries/*.conf.hyde.bkp    # restore systemd-boot from this backup
/etc/default/grub.hyde.bkp              # restore grub from this backup
/boot/grub/grub.hyde.bkp                # restore grub from this backup
/usr/share/grub/themes                  # remove grub themes from here
/etc/pacman.conf.hyde.bkp               # restore pacman from this backup
/etc/sddm.conf.d/kde_settings.hyde.bkp  # restore sddm from this backup
/usr/share/sddm/themes                  # remove sddm themes from here

Uninstall the packages manually that are no longer required based on these list
${scrDir}/pkg_core.lst
${scrDir}/pkg_extra.lst
NOTE
