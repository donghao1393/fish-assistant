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
    # 现在只返回配置名称，而不是Pod ID
    __brow_config_names
end

function __brow_forward_ids
    # 这个函数现在只返回配置名称，而不返回转发ID
    # 这更符合我们的抽象层设计，用户只需要知道配置名称
    set -l active_dir ~/.config/brow/active
    if test -d $active_dir
        # 记录已经处理过的配置
        set -l processed_configs ""

        for file in $active_dir/forward-*.json
            if test -f $file
                # 从文件名中提取信息
                set -l filename (basename $file)

                # 先移除.json后缀
                set -l name_without_ext (string replace ".json" "" $filename)

                # 分割成数组，例如 [forward, legacy, prod, 0df206e8]
                set -l parts (string split "-" $name_without_ext)

                # 移除第一个元素(forward)和最后一个元素(forward_id)
                set -l config_parts $parts[2..-2]

                # 将剩下的元素用短横线连接起来作为config_name
                set -l config_from_filename (string join "-" $config_parts)

                # 读取转发数据
                set -l forward_data (cat $file)
                set -l config_name (echo $forward_data | jq -r '.config // "unknown"')
                set -l local_port (echo $forward_data | jq -r '.local_port')
                set -l pid (echo $forward_data | jq -r '.pid')

                # 如果文件内容中的config_name与文件名中的不一致，使用文件名中的
                if test "$config_name" = unknown
                    set config_name $config_from_filename
                end

                # 检查进程是否仍在运行
                if kill -0 $pid 2>/dev/null
                    # 如果这个配置还没有被处理过，输出配置名称作为选项
                    if not contains $config_name $processed_configs
                        set -a processed_configs $config_name
                        set -l config_description "$config_name (端口:$local_port) [活跃连接]"
                        echo $config_name\t$config_description
                    end
                end
            end
        end
    end

    # 添加所有配置名称作为选项，但只添加那些还没有被处理过的
    for config_name in (__brow_config_names)
        if not contains $config_name $processed_configs
            echo $config_name\t"$config_name [配置名称]"
        end
    end
end

function __brow_k8s_contexts
    # 获取所有Kubernetes上下文
    kubectl config get-contexts --output=name 2>/dev/null
end

# 主命令补全
complete -c brow -f -n __brow_needs_command -a connect -d 创建连接到指定配置
complete -c brow -f -n __brow_needs_command -a list -d 列出活跃的连接
complete -c brow -f -n __brow_needs_command -a stop -d 停止连接
complete -c brow -f -n __brow_needs_command -a config -d 管理连接配置
complete -c brow -f -n __brow_needs_command -a pod -d "管理Kubernetes Pod"
complete -c brow -f -n __brow_needs_command -a forward -d "管理端口转发 (高级功能)"
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
complete -c brow -f -n "__brow_using_command stop" -a "(__brow_forward_ids)"

# Kubernetes上下文补全
complete -c brow -f -n "__brow_using_subcommand config add" -a "(__brow_k8s_contexts)"
