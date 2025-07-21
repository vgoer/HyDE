#!/usr/bin/env bash
#|---/ /+------------------------------+---/ /|#
#|--/ /-| Script to patch custom theme |--/ /-|#
#|-/ /--| kRHYME7                      |-/ /--|#
#|/ /---+------------------------------+/ /---|#
# 主题补丁脚本 - 应用自定义主题

# 打印提示信息的函数
print_prompt() {
    [[ "${verbose}" == "false" ]] && return 0
    while (("$#")); do
        case "$1" in
        -r)
            echo -ne "\e[31m$2\e[0m"
            shift 2
            ;; # 红色
        -g)
            echo -ne "\e[32m$2\e[0m"
            shift 2
            ;; # 绿色
        -y)
            echo -ne "\e[33m$2\e[0m"
            shift 2
            ;; # 黄色
        -b)
            echo -ne "\e[34m$2\e[0m"
            shift 2
            ;; # 蓝色
        -m)
            echo -ne "\e[35m$2\e[0m"
            shift 2
            ;; # 洋红色
        -c)
            echo -ne "\e[36m$2\e[0m"
            shift 2
            ;; # 青色
        -w)
            echo -ne "\e[37m$2\e[0m"
            shift 2
            ;; # 白色
        -n)
            echo -ne "\e[96m$2\e[0m"
            shift 2
            ;; # 霓虹色
        *)
            echo -ne "$1"
            shift
            ;;
        esac
    done
    echo ""
}

# 获取脚本目录并导入全局函数
scrDir=$(dirname "$(realpath "$0")")
# shellcheck disable=SC1091
# if [ $? -ne 0 ]; then
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

verbose="${4}"  # 详细模式标志
set +e          # 禁用错误退出

# 显示帮助信息的函数
ask_help() {
    cat <<HELP
Usage:
    $(print_prompt "$0 " -y "Theme-Name " -c "/Path/to/Configs")
    $(print_prompt "$0 " -y "Theme-Name " -c "https://github.com/User/Repository")
    $(print_prompt "$0 " -y "Theme-Name " -c "https://github.com/User/Repository/tree/branch")

Options:
    'export FULL_THEME_UPDATE=true'       Overwrites the archived files (useful for updates and changes in archives)

Supported Archive Format:
    | File prfx          | Hyprland variable | Target dir                      |
    | ---------------    | ----------------- | --------------------------------|
    | Gtk_               | \$GTK_THEME        | \$HOME/.local/share/themes     |
    | Icon_              | \$ICON_THEME       | \$HOME/.local/share/icons      |
    | Cursor_            | \$CURSOR_THEME     | \$HOME/.local/share/icons      |
    | Sddm_              | \$SDDM_THEME       | /usr/share/sddm/themes         |
    | Font_              | \$FONT             | \$HOME/.local/share/fonts      |
    | Document-Font_     | \$DOCUMENT_FONT    | \$HOME/.local/share/fonts      |
    | Monospace-Font_    | \$MONOSPACE_FONT   | \$HOME/.local/share/fonts      |
    | Notification-Font_ | \$NOTIFICATION_FONT | \$HOME/.local/share/fonts  |
    | Bar-Font_          | \$BAR_FONT         | \$HOME/.local/share/fonts      |
    | Menu-Font_         | \$MENU_FONT        | \$HOME/.local/share/fonts      |

Note:
    Target directories without enough permissions will be skipped.
        run 'sudo chmod -R 777 <target directory>'
            example: 'sudo chmod -R 777 /usr/share/sddm/themes'
HELP
}

# 检查参数
if [[ -z $1 || -z $2 ]]; then
    ask_help
    exit 1
fi

# Wallbash目录列表
wallbashDirs=(
    "$HOME/.config/hyde/wallbash"
    "$HOME/.local/share/hyde/wallbash"
    "/usr/local/share/hyde/wallbash"
    "/usr/share/hyde/wallbash"
)

# 设置参数
Fav_Theme="$1"  # 主题名称

# 处理主题目录或Git仓库
if [ -d "$2" ]; then
    Theme_Dir="$2"  # 本地目录
else
    Git_Repo=${2%/}  # Git仓库URL
    if echo "$Git_Repo" | grep -q "/tree/"; then
        # 提取分支名
        branch=${Git_Repo#*tree/}
        Git_Repo=${Git_Repo%/tree/*}
    else
        # 获取可用分支列表
        branches=$(curl -s "https://api.github.com/repos/${Git_Repo#*://*/}/branches" | jq -r '.[].name')
        # shellcheck disable=SC2206
        branches=($branches)
        if [[ ${#branches[@]} -le 1 ]]; then
            branch=${branches[0]}
        else
            # 让用户选择分支
            echo "Select a Branch"
            select branch in "${branches[@]}"; do
                [[ -n $branch ]] && break || echo "Invalid selection. Please try again."
            done
        fi
    fi

    # 设置Git相关变量
    Git_Path=${Git_Repo#*://*/}
    Git_Owner=${Git_Path%/*}
    branch_dir=${branch//\//_}
    cacheDir=${cacheDir:-"$HOME/.cache/hyde"}
    Theme_Dir="${cacheDir}/themepatcher/${branch_dir}-${Git_Owner}"

    # 检查目录是否存在
    if [ -d "$Theme_Dir" ]; then
        print_prompt "Directory $Theme_Dir already exists. Using existing directory."
        if cd "$Theme_Dir"; then
            # 更新现有仓库
            git fetch --all &>/dev/null
            git reset --hard "@{upstream}" &>/dev/null
            cd - &>/dev/null || exit
        else
            print_prompt -y "Could not navigate to $Theme_Dir. Skipping git pull."
        fi
    else
        print_prompt "Directory $Theme_Dir does not exist. Cloning repository into new directory."
        # 克隆新仓库
        if ! git clone -b "$branch" --depth 1 "$Git_Repo" "$Theme_Dir" &>/dev/null; then
            print_prompt "Git clone failed"
            exit 1
        fi
    fi
fi

print_prompt "Patching" -g " --// ${Fav_Theme} //-- " "from " -b "${Theme_Dir}\n"

# 检查主题目录是否存在
Fav_Theme_Dir="${Theme_Dir}/Configs/.config/hyde/themes/${Fav_Theme}"
[ ! -d "${Fav_Theme_Dir}" ] && print_prompt -r "[ERROR] " "'${Fav_Theme_Dir}'" -y " Do not Exist" && exit 1

# 查找配置文件
config=$(find "${wallbashDirs[@]}" -type f -path "*/theme*" -name "*.dcol" 2>/dev/null | awk '!seen[substr($0, match($0, /[^/]+$/))]++' | awk -v favTheme="${Fav_Theme}" -F 'theme/' '{gsub(/\.dcol$/, ".theme"); print ".config/hyde/themes/" favTheme "/" $2}')
restore_list=""

# 检查配置文件是否存在
while IFS= read -r fileCheck; do
    if [[ -e "${Theme_Dir}/Configs/${fileCheck}" ]]; then
        print_prompt -g "[found] " "${fileCheck}"
        fileBase=$(basename "${fileCheck}")
        fileDir=$(dirname "${fileCheck}")
        restore_list+="Y|Y|\${HOME}/${fileDir}|${fileBase}|hyprland\n"
    else
        print_prompt -y "[warn] " "${fileCheck} --> do not exist in ${Theme_Dir}/Configs/"
    fi
done <<<"$config"

# 检查主题颜色文件
if [ -f "${Fav_Theme_Dir}/theme.dcol" ]; then
    print_prompt -n "[note] " "found theme.dcol to override wallpaper dominant colors"
    restore_list+="Y|Y|\${HOME}/.config/hyde/themes/${Fav_Theme}|theme.dcol|hyprland\n"
fi
readonly restore_list

# 获取壁纸文件
wallpapers=$(
    find "${Fav_Theme_Dir}" -type f \( -iname "*.gif" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) ! -path "*/logo/*"
)
wpCount="$(wc -l <<<"${wallpapers}")"
{ [ -z "${wallpapers}" ] && print_prompt -r "[ERROR] " "No wallpapers found" && exit_flag=true; } || { readonly wallpapers && print_prompt -g "\n[OK] " "wallpapers :: [count] ${wpCount} (.gif+.jpg+.jpeg+.png)"; }

# 获取Logo文件
if [ -d "${Fav_Theme_Dir}/logo" ]; then
    logos=$(find "${Fav_Theme_Dir}/logo" -type f \( -iname "*.gif" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \))
    logosCount="$(wc -l <<<"${logos}")"
    { [ -z "${logos}" ] && print_prompt -y "[warn] " "No logos found"; } || { readonly logos && print_prompt -g "[OK] " "logos :: [count] ${logosCount}\n"; }
fi

# 解析压缩包函数
check_tars() {
    local trVal
    local inVal="${1}"
    local gsLow
    local gsVal
    gsLow=$(echo "${inVal}" | tr '[:upper:]' '[:lower:]')
    # Use hyprland variables that are set in the hypr.theme file
    # Using case we can have a predictable output
    gsVal="$(
        case "${gsLow}" in
        sddm)
            grep "^[[:space:]]*\$SDDM[-_]THEME\s*=" "${Fav_Theme_Dir}/hypr.theme" | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
            ;;
        gtk)
            grep "^[[:space:]]*\$GTK[-_]THEME\s*=" "${Fav_Theme_Dir}/hypr.theme" | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
            ;;
        icon)
            grep "^[[:space:]]*\$ICON[-_]THEME\s*=" "${Fav_Theme_Dir}/hypr.theme" | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
            ;;
        cursor)
            grep "^[[:space:]]*\$CURSOR[-_]THEME\s*=" "${Fav_Theme_Dir}/hypr.theme" | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
            ;;
        font)
            grep "^[[:space:]]*\$FONT\s*=" "${Fav_Theme_Dir}/hypr.theme" | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
            ;;
        document-font)
            grep "^[[:space:]]*\$DOCUMENT[-_]FONT\s*=" "${Fav_Theme_Dir}/hypr.theme" | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
            ;;
        monospace-font)
            grep "^[[:space:]]*\$MONOSPACE[-_]FONT\s*=" "${Fav_Theme_Dir}/hypr.theme" | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
            ;;
        bar-font)
            grep "^[[:space:]]*\$BAR[-_]FONT\s*=" "${Fav_Theme_Dir}/hypr.theme" | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
            ;;
        menu-font)
            grep "^[[:space:]]*\$MENU[-_]FONT\s*=" "${Fav_Theme_Dir}/hypr.theme" | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
            ;;
        notification-font)
            grep "^[[:space:]]*\$NOTIFICATION[-_]FONT\s*=" "${Fav_Theme_Dir}/hypr.theme" | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
            ;;

        *) # fallback to older method
            awk -F"[\"']" '/^[[:space:]]*exec[[:space:]]*=[[:space:]]*gsettings[[:space:]]*set[[:space:]]*org.gnome.desktop.interface[[:space:]]*'"${gsLow}"'-theme[[:space:]]*/ {last=$2} END {print last}' "${Fav_Theme_Dir}/hypr.theme"
            ;;
        esac
    )"

    # fallback to older method
    gsVal=${gsVal:-$(awk -F"[\"']" '/^[[:space:]]*exec[[:space:]]*=[[:space:]]*gsettings[[:space:]]*set[[:space:]]*org.gnome.desktop.interface[[:space:]]*'"${gsLow}"'-theme[[:space:]]*/ {last=$2} END {print last}' "${Fav_Theme_Dir}/hypr.theme")}

    if [ -n "${gsVal}" ]; then

        if [[ "${gsVal}" =~ ^\$\{?[A-Za-z_][A-Za-z0-9_]*\}?$ ]]; then # check is a variable is set into a variable eg $FONT=$DOCUMENT_FONT
            print_prompt -y "[warn] " "Variable ${gsVal} detected,be sure ${gsVal} is set in hypr.theme, skipping check"
        else
            print_prompt -g "[OK] " "hypr.theme :: [${gsLow}]" -b " ${gsVal}"
            trArc="$(find "${Theme_Dir}" -type f -name "${inVal}_*.tar.*")"
            [ -f "${trArc}" ] && [ "$(echo "${trArc}" | wc -l)" -eq 1 ] && trVal="$(basename "$(tar -tf "${trArc}" | cut -d '/' -f1 | sort -u)")" && trVal="$(echo "${trVal}" | grep -w "${gsVal}")"
            print_prompt -g "[OK] " "../*.tar.* :: [${gsLow}]" -b " ${trVal}"
            [ "${trVal}" != "${gsVal}" ] && print_prompt -r "[ERROR] " "${gsLow} set in hypr.theme does not exist in ${inVal}_*.tar.*" && exit_flag=true
        fi
    else
        [ "${2}" == "--mandatory" ] && print_prompt -r "[ERROR] " "hypr.theme :: [${gsLow}] Not Found" && exit_flag=true && return 0
        print_prompt -y "[warn] " "hypr.theme :: [${gsLow}] Not Found, don't worry if it's not needed"
    fi
}

check_tars Gtk --mandatory
check_tars Icon
check_tars Cursor
check_tars Sddm
check_tars Font
check_tars Document-Font
check_tars Monospace-Font
check_tars Bar-Font
check_tars Menu-Font
check_tars Notification-Font
print_prompt "" && [[ "${exit_flag}" = true ]] && exit 1

# extract arcs
declare -A archive_map=(
    ["Gtk"]="${HOME}/.local/share/themes"
    ["Icon"]="${HOME}/.local/share/icons"
    ["Cursor"]="${HOME}/.local/share/icons"
    ["Sddm"]="/usr/share/sddm/themes"
    ["Font"]="${HOME}/.local/share/fonts"
    ["Document-Font"]="${HOME}/.local/share/fonts"
    ["Monospace-Font"]="${HOME}/.local/share/fonts"
    ["Bar-Font"]="${HOME}/.local/share/fonts"
    ["Menu-Font"]="${HOME}/.local/share/fonts"
    ["Notification-Font"]="${HOME}/.local/share/fonts"
)

for prefix in "${!archive_map[@]}"; do
    tarFile="$(find "${Theme_Dir}" -type f -name "${prefix}_*.tar.*")"
    [ -f "${tarFile}" ] || continue
    tgtDir="${archive_map[$prefix]}"

    if [[ "${tgtDir}" =~ /(usr|usr\/local)\/share/ && -d /run/current-system/sw/share/ ]]; then
        print_prompt -y "Detected NixOS system, changing target to /run/current-system/sw/share/..."
        tgtDir="/run/current-system/sw/share/"
    fi

    if [ ! -d "${tgtDir}" ]; then
        if ! mkdir -p "${tgtDir}"; then
            print_prompt -y "Creating directory as root instead..."
            sudo mkdir -p "${tgtDir}"
        fi
    fi

    tgtChk="$(basename "$(tar -tf "${tarFile}" | cut -d '/' -f1 | sort -u)")"
    [[ "${FULL_THEME_UPDATE}" = true ]] || { [ -d "${tgtDir}/${tgtChk}" ] && print_prompt -y "[skip] " "\"${tgtDir}/${tgtChk}\" already exists" && continue; }
    print_prompt -g "[extracting] " "${tarFile} --> ${tgtDir}"

    if [ -w "${tgtDir}" ]; then
        tar -xf "${tarFile}" -C "${tgtDir}"
    else
        print_prompt -y "Not writable. Extracting as root: ${tgtDir}"
        if ! sudo tar -xf "${tarFile}" -C "${tgtDir}" 2>/dev/null; then
            print_prompt -r "Extraction by root FAILED. Giving up..."
            print_prompt "The above error can be ignored if the '${tgtDir}' is not writable..."
        fi
    fi

done

confDir=${XDG_CONFIG_HOME:-"$HOME/.config"}

# populate wallpaper
Fav_Theme_Walls="${confDir}/hyde/themes/${Fav_Theme}/wallpapers"
[ ! -d "${Fav_Theme_Walls}" ] && mkdir -p "${Fav_Theme_Walls}"
while IFS= read -r walls; do
    cp -f "${walls}" "${Fav_Theme_Walls}"
done <<<"${wallpapers}"

# populate logos
Fav_Theme_Logos="${confDir}/hyde/themes/${Fav_Theme}/logo"
if [ -n "${logos}" ]; then
    [ ! -d "${Fav_Theme_Logos}" ] && mkdir -p "${Fav_Theme_Logos}"
    while IFS= read -r logo; do
        if [ -f "${logo}" ]; then
            cp -f "${logo}" "${Fav_Theme_Logos}"
        else
            print_prompt -y "[warn] " "${logo} --> do not exist"
        fi
    done <<<"${logos}"
fi

# restore configs with theme override
echo -en "${restore_list}" >"${Theme_Dir}/restore_cfg.lst"
print_prompt -g "\n[exec] " "restore_cfg.sh \"${Theme_Dir}/restore_cfg.lst\" \"${Theme_Dir}/Configs\" \"${Fav_Theme}\"\n"
"${scrDir}/restore_cfg.sh" "${Theme_Dir}/restore_cfg.lst" "${Theme_Dir}/Configs" "${Fav_Theme}" &>/dev/null
if [ "${3}" != "--skipcaching" ]; then
    "$HOME/.local/lib/hyde/swwwallcache.sh" -t "${Fav_Theme}"
    "$HOME/.local/lib/hyde/theme.switch.sh"
fi

print_prompt -y "\nNote: Warnings are not errors. Review the output to check if it concerns you."

exit 0
