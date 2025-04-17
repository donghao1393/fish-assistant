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
    # 获取所有上下文
    set -l contexts (kubectl config get-contexts --output=name 2>/dev/null)

    # 遍历所有上下文
    for ctx in $contexts
        # 获取当前上下文中的所有Pod
        set -l pods_json (kubectl --context=$ctx get pods --output=json 2>/dev/null)
        if test $status -ne 0
            continue
        end

        # 使用jq提取所有brow Pod的信息
        set -l pod_names (echo $pods_json | jq -r '.items[] | select(.metadata.name | startswith("brow-")) | .metadata.name' 2>/dev/null)

        # 处理每个Pod
        for pod_name in $pod_names
            # 获取单个Pod的详细信息
            set -l pod_json (kubectl --context=$ctx get pod $pod_name -o json 2>/dev/null)

            # 提取Pod信息
            set -l config_name (echo $pod_json | jq -r '.metadata.annotations."brow.config" // "未知"')
            set -l pod_status (echo $pod_json | jq -r '.status.phase')

            # 显示简化的上下文名称
            set -l short_ctx (echo $ctx | string replace -r '.*/' '')

            # 输出格式：Pod名称\t配置 (上下文) [状态]
            set -l description "$config_name ($short_ctx) [$pod_status]"
            echo $pod_name\t$description
        end
    end
end

function __brow_forward_ids
    set -l active_dir ~/.config/brow/active
    if test -d $active_dir
        for file in $active_dir/forward-*.json
            if test -f $file
                # 提取转发ID
                set -l forward_id (basename $file .json | string replace "forward-" "" | string split "-" | tail -n 1)

                # 读取转发数据
                set -l forward_data (cat $file)
                set -l pod_id (echo $forward_data | jq -r '.pod_id')
                set -l local_port (echo $forward_data | jq -r '.local_port')
                set -l config (echo $forward_data | jq -r '.config')
                set -l pid (echo $forward_data | jq -r '.pid')

                # 检查进程是否仍在运行
                set -l forward_status 已停止
                if kill -0 $pid 2>/dev/null
                    set forward_status 活跃
                end

                # 输出格式：ID（带描述）
                set -l description "$config (端口:$local_port) -> $pod_id [$forward_status]"
                echo $forward_id\t$description
            end
        end
    end
end

function __brow_k8s_contexts
    # 获取所有Kubernetes上下文
    kubectl config get-contexts --output=name 2>/dev/null
end

# 主命令补全
complete -c brow -f -n __brow_needs_command -a config -d 管理连接配置
complete -c brow -f -n __brow_needs_command -a pod -d "管理Kubernetes Pod"
complete -c brow -f -n __brow_needs_command -a forward -d 管理端口转发
complete -c brow -f -n __brow_needs_command -a connect -d 一步完成创建Pod和转发
complete -c brow -f -n __brow_needs_command -a version -d 显示版本信息
complete -c brow -f -n __brow_needs_command -a help -d 显示帮助信息

# config 子命令补全
complete -c brow -f -n "__brow_using_command config" -a add -d 添加新配置
complete -c brow -f -n "__brow_using_command config" -a list -d 列出所有配置
complete -c brow -f -n "__brow_using_command config" -a show -d 显示特定配置详情
complete -c brow -f -n "__brow_using_command config" -a edit -d 编辑配置
complete -c brow -f -n "__brow_using_command config" -a remove -d 删除配置

# pod 子命令补全
complete -c brow -f -n "__brow_using_command pod" -a create -d 根据配置创建Pod
complete -c brow -f -n "__brow_using_command pod" -a list -d 列出当前所有Pod
complete -c brow -f -n "__brow_using_command pod" -a info -d 查看Pod详细信息
complete -c brow -f -n "__brow_using_command pod" -a delete -d 手动删除Pod
complete -c brow -f -n "__brow_using_command pod" -a cleanup -d 清理过期的Pod

# forward 子命令补全
complete -c brow -f -n "__brow_using_command forward" -a start -d 开始端口转发
complete -c brow -f -n "__brow_using_command forward" -a list -d 列出活跃的转发
complete -c brow -f -n "__brow_using_command forward" -a stop -d 停止特定的转发

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

# Kubernetes上下文补全
complete -c brow -f -n "__brow_using_subcommand config add" -a "(__brow_k8s_contexts)"
