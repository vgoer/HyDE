#!/usr/bin/env bash
#|---/ /+-------------------------+---/ /|#
#|--/ /-| Service restore script  |--/ /-|#
#|-/ /--| Prasanth Rangan         |-/ /--|#
#|/ /---+-------------------------+/ /---|#
# 服务恢复脚本 - 恢复和启用系统服务

# 获取脚本所在目录的绝对路径
scrDir="$(dirname "$(realpath "$0")")"
# shellcheck disable=SC1091
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

# 设置测试运行标志
flg_DryRun=${flg_DryRun:-0}

# 处理旧格式服务的函数（向后兼容）
# 参数: $1 - 服务名称
handle_legacy_service() {
    local serviceChk="$1"
    
    # 使用原始逻辑进行向后兼容
    # 检查服务是否已激活
    if [[ $(systemctl list-units --all -t service --full --no-legend "${serviceChk}.service" | sed 's/^\s*//g' | cut -f1 -d' ') == "${serviceChk}.service" ]]; then
        print_log -y "[skip] " -b "active " "Service ${serviceChk}"  # 服务已激活，跳过
    else
        print_log -y "enable " "Service ${serviceChk}"  # 启用服务
        if [ "$flg_DryRun" -ne 1 ]; then
            sudo systemctl enable "${serviceChk}.service"
        fi
    fi
}

# 主要处理逻辑
print_log -sec "services" -stat "restore" "system services..."

# 读取服务列表文件
while IFS='|' read -r service context command || [ -n "$service" ]; do
    # 跳过空行和注释行
    [[ -z "$service" || "$service" =~ ^[[:space:]]*# ]] && continue
    
    # 去除空白字符
    service=$(echo "$service" | xargs)
    context=$(echo "$context" | xargs)
    command=$(echo "$command" | xargs)
    
    # 检查是新格式（管道分隔）还是旧格式
    if [[ -z "$context" ]]; then
        # 旧格式：只有服务名称
        handle_legacy_service "$service"
    else
        # 新格式：服务|上下文|命令
        # 将命令解析为数组以正确处理空格
        read -ra cmd_array <<< "$command"
        
        print_log -y "[exec] " "Service ${service} (${context}): $command"
        
        if [ "$flg_DryRun" -ne 1 ]; then
            # 实际执行模式
            if [ "$context" = "user" ]; then
                # 用户级服务
                systemctl --user "${cmd_array[@]}" "${service}.service"
            else
                # 系统级服务
                sudo systemctl "${cmd_array[@]}" "${service}.service"
            fi
        else
            # 测试运行模式：只显示命令
            if [ "$context" = "user" ]; then
                print_log -c "[dry-run] " "systemctl --user ${cmd_array[*]} ${service}.service"
            else
                print_log -c "[dry-run] " "sudo systemctl ${cmd_array[*]} ${service}.service"
            fi
        fi
    fi
    
done < "${scrDir}/restore_svc.lst"

print_log -sec "services" -stat "completed" "service updates"
