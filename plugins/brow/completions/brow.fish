function __brow_needs_command
    set -l cmd (commandline -opc)
    if test (count $cmd) -eq 1
        return 0
    end
    return 1
end

function __brow_using_command
    set -l cmd (commandline -opc)
    if test (count $cmd) -gt 1
        if test $argv[1] = $cmd[2]
            return 0
        end
    end
    return 1
end

function __brow_using_subcommand
    set -l cmd (commandline -opc)
    if test (count $cmd) -gt 2
        if test $argv[1] = $cmd[2] -a $argv[2] = $cmd[3]
            return 0
        end
    end
    return 1
end

function __brow_config_names
    set -l config_file ~/.config/brow/config.json
    if test -f $config_file
        jq -r 'keys[]' $config_file
    end
end

function __brow_pod_ids
    kubectl get pods --selector=app --output=json 2>/dev/null | jq -r '.items[] | select(.metadata.name | startswith("brow-")) | .metadata.name'
end

function __brow_forward_ids
    set -l active_dir ~/.config/brow/active
    if test -d $active_dir
        for file in $active_dir/forward-*.json
            if test -f $file
                basename $file .json | string replace "forward-" "" | string split "-" | tail -n 1
            end
        end
    end
end

# 主命令补全
complete -c brow -f -n "__brow_needs_command" -a "config" -d "管理连接配置"
complete -c brow -f -n "__brow_needs_command" -a "pod" -d "管理Kubernetes Pod"
complete -c brow -f -n "__brow_needs_command" -a "forward" -d "管理端口转发"
complete -c brow -f -n "__brow_needs_command" -a "connect" -d "一步完成创建Pod和转发"
complete -c brow -f -n "__brow_needs_command" -a "version" -d "显示版本信息"
complete -c brow -f -n "__brow_needs_command" -a "help" -d "显示帮助信息"

# config 子命令补全
complete -c brow -f -n "__brow_using_command config" -a "add" -d "添加新配置"
complete -c brow -f -n "__brow_using_command config" -a "list" -d "列出所有配置"
complete -c brow -f -n "__brow_using_command config" -a "show" -d "显示特定配置详情"
complete -c brow -f -n "__brow_using_command config" -a "edit" -d "编辑配置"
complete -c brow -f -n "__brow_using_command config" -a "remove" -d "删除配置"

# pod 子命令补全
complete -c brow -f -n "__brow_using_command pod" -a "create" -d "根据配置创建Pod"
complete -c brow -f -n "__brow_using_command pod" -a "list" -d "列出当前所有Pod"
complete -c brow -f -n "__brow_using_command pod" -a "info" -d "查看Pod详细信息"
complete -c brow -f -n "__brow_using_command pod" -a "delete" -d "手动删除Pod"
complete -c brow -f -n "__brow_using_command pod" -a "cleanup" -d "清理过期的Pod"

# forward 子命令补全
complete -c brow -f -n "__brow_using_command forward" -a "start" -d "开始端口转发"
complete -c brow -f -n "__brow_using_command forward" -a "list" -d "列出活跃的转发"
complete -c brow -f -n "__brow_using_command forward" -a "stop" -d "停止特定的转发"

# 配置名称补全
complete -c brow -f -n "__brow_using_subcommand config show" -a "(__brow_config_names)"
complete -c brow -f -n "__brow_using_subcommand config edit" -a "(__brow_config_names)"
complete -c brow -f -n "__brow_using_subcommand config remove" -a "(__brow_config_names)"
complete -c brow -f -n "__brow_using_subcommand pod create" -a "(__brow_config_names)"
complete -c brow -f -n "__brow_using_command connect" -a "(__brow_config_names)"

# Pod ID补全
complete -c brow -f -n "__brow_using_subcommand pod info" -a "(__brow_pod_ids)"
complete -c brow -f -n "__brow_using_subcommand pod delete" -a "(__brow_pod_ids)"
complete -c brow -f -n "__brow_using_subcommand forward start" -a "(__brow_pod_ids)"

# 转发ID补全
complete -c brow -f -n "__brow_using_subcommand forward stop" -a "(__brow_forward_ids)"
