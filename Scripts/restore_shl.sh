#!/usr/bin/env bash
#|---/ /+---------------------------+---/ /|#
#|--/ /-| Script to configure shell |--/ /-|#
#|-/ /--| Prasanth Rangan           |-/ /--|#
#|/ /---+---------------------------+/ /---|#
# Shell配置脚本 - 配置用户Shell环境

# 获取脚本所在目录的绝对路径
scrDir=$(dirname "$(realpath "$0")")
# shellcheck disable=SC1091
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

# 设置测试运行标志
flg_DryRun=${flg_DryRun:-0}

# shellcheck disable=SC2154
# 检查Shell是否已安装
if chk_list "myShell" "${shlList[@]}"; then
    print_log -sec "SHELL" -stat "detected" "${myShell}"
else
    print_log -sec "SHELL" -err "error" "no shell found..."
    exit 1
fi

# 安装zsh插件
if pkg_installed zsh; then
    # 询问是否安装oh-my-zsh插件
    prompt_timer 120 "Pre install zsh plugins using oh-my-zsh? [y/n] | q to quit "

    if [ "${PROMPT_INPUT}" == "y" ]; then
        if ! pkg_installed oh-my-zsh-git; then
            # 检查oh-my-zsh是否已安装
            if [[ ! -e "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]; then
                print_log -sec "SHELL" -stat "cloning" "oh-my-zsh"
                # 安装oh-my-zsh
                [ ${flg_DryRun} -eq 1 ] || if ! sh -c "$(curl -fsSL https://install.ohmyz.sh/)" "" --unattended --keep-zshrc; then
                    print_log -err "oh-my-zsh update failed..." "Please resolve this issue manually LATER ..."
                    print_log -warn "Continuing" "with existing oh-my-zsh..."
                    exit 0
                fi

            else
                print_log -sec "SHELL" -stat "updating" "oh-my-zsh"
                # 更新oh-my-zsh
                zsh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/upgrade.sh)"
            fi
        fi
    fi

    # 配置oh-my-zsh插件
    if (pkg_installed oh-my-zsh-git || [[ -f "${HOME}/.oh-my-zsh/oh-my-zsh.sh" ]]) && [ ${flg_DryRun} -ne 1 ]; then
        # 查找oh-my-zsh安装路径
        zsh_paths=(
            "$HOME/.oh-my-zsh"
            "/usr/local/share/oh-my-zsh"
            "/usr/share/oh-my-zsh"
        )
        for zsh_path in "${zsh_paths[@]}"; do [[ -d $zsh_path ]] && Zsh_Path=$zsh_path && break; done

        # 设置变量
        Zsh_rc="${ZDOTDIR:-$HOME}/.zshenv"                    # zsh环境配置文件
        Zsh_Path="${Zsh_Path:-$HOME/.oh-my-zsh}"              # oh-my-zsh路径
        Zsh_Plugins="$Zsh_Path/custom/plugins"                # 插件目录
        Fix_Completion=""                                      # 补全修复

        # 从列表生成插件
        while read -r r_plugin; do
            z_plugin=$(awk -F '/' '{print $NF}' <<<"${r_plugin}")  # 提取插件名
            # 如果是HTTP链接且插件未安装，则克隆插件
            if [ "${r_plugin:0:4}" == "http" ] && [ ! -d "${Zsh_Plugins}/${z_plugin}" ]; then
                if [ -w "${Zsh_Plugins}" ]; then
                    git clone "${r_plugin}" "${Zsh_Plugins}/${z_plugin}"
                else
                    sudo git clone "${r_plugin}" "${Zsh_Plugins}/${z_plugin}"
                fi
            fi
            # 特殊处理zsh-completions插件
            if [ "${z_plugin}" == "zsh-completions" ] && [ "$(grep -c 'fpath+=.*plugins/zsh-completions/src' "${Zsh_rc}")" -eq 0 ]; then
                Fix_Completion='\nfpath+=${ZSH_CUSTOM:-${ZSH:-/usr/share/oh-my-zsh}/custom}/plugins/zsh-completions/src'
            else
                [ -z "${z_plugin}" ] || w_plugin+=" ${z_plugin}"  # 添加到插件列表
            fi
        done < <(cut -d '#' -f 1 "${scrDir}/restore_zsh.lst" | sed 's/ //g')

        # 更新zshrc中的插件数组
        print_log -sec "SHELL" -stat "installing" "plugins (${w_plugin} )"
        sed -i "/^hyde_plugins=/c\hyde_plugins=(${w_plugin} )${Fix_Completion}" "${Zsh_rc}"
    else
        if [ "${flg_DryRun}" -eq "1" ]; then
            # 测试运行模式：只显示要安装的插件
            while read -r r_plugin; do
                z_plugin=$(awk -F '/' '{print $NF}' <<<"${r_plugin}")
                [ -z "${z_plugin}" ] || w_plugin+=" ${z_plugin}"
            done < <(cut -d '#' -f 1 "${scrDir}/restore_zsh.lst" | sed 's/ //g')
            print_log -sec "SHELL" -stat "installing" "plugins (${w_plugin} )"
        else
            print_log -sec "SHELL" -err "error" "oh-my-zsh not installed, skipping plugin installation..."
        fi
    fi

fi

# 设置默认Shell
if [[ "$(grep "/${USER}:" /etc/passwd | awk -F '/' '{print $NF}')" != "${myShell}" ]]; then
    print_log -sec "SHELL" -stat "change" "shell to ${myShell}..."
    [ ${flg_DryRun} -eq 1 ] || chsh -s "$(which "${myShell}")"  # 更改用户默认Shell
else
    print_log -sec "SHELL" -stat "exist" "${myShell} is already set as shell..."
fi
