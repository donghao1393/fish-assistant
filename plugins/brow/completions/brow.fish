# 加载i18n函数
if not functions -q _brow_i18n_get
    # 尝试从相对路径加载
    set -l script_dir (dirname (status filename))
    set -l i18n_file $script_dir/../functions/_brow_i18n.fish
    if test -f $i18n_file
        source $i18n_file
    else
        # 尝试从绝对路径加载
        set -l i18n_file ~/.config/fish/functions/_brow_i18n.fish
        if test -f $i18n_file
            source $i18n_file
        end
    end
end

# 如果i18n函数仍然不可用，定义一个简单的替代函数
if not functions -q _brow_i18n_get
    function _brow_i18n_get
        # 定义一些基本的翻译
        switch $argv[1]
            case completion_option_sudo
                echo "Use sudo for low-numbered ports (0-1023)"
            case completion_cmd_connect
                echo "Create connection to specified config"
            case completion_cmd_list
                echo "List active connections"
            case completion_cmd_stop
                echo "Stop connection"
            case completion_cmd_config
                echo "Manage connection configurations"
            case completion_cmd_pod
                echo "Manage Kubernetes Pods"
            case completion_cmd_forward
                echo "Manage port forwarding (advanced)"
            case completion_cmd_health_check
                echo "Check and fix inconsistent states"
            case completion_cmd_version
                echo "Show version information"
            case completion_cmd_help
                echo "Show help information"
            case completion_cmd_language
                echo "Manage language settings"
            case completion_subcmd_config_add
                echo "Add new configuration"
            case completion_subcmd_config_list
                echo "List all configurations"
            case completion_subcmd_config_show
                echo "Show specific configuration details"
            case completion_subcmd_config_edit
                echo "Edit configuration"
            case completion_subcmd_config_remove
                echo "Delete configuration"
            case completion_subcmd_pod_create
                echo "Create Pod from configuration"
            case completion_subcmd_pod_list
                echo "List all current Pods"
            case completion_subcmd_pod_info
                echo "View Pod details"
            case completion_subcmd_pod_delete
                echo "Manually delete Pod"
            case completion_subcmd_pod_cleanup
                echo "Clean up expired Pods"
            case completion_subcmd_forward_start
                echo "Start port forwarding"
            case completion_subcmd_forward_list
                echo "List active forwards"
            case completion_subcmd_forward_stop
                echo "Stop specific forward"
            case completion_subcmd_language_set
                echo "Set language"
            case completion_config
                echo config
            case forward_status_active
                echo active
            case '*'
                echo $argv[1]
        end
    end
end

# 如果_brow_i18n_format函数不可用，定义一个简单的替代函数
if not functions -q _brow_i18n_format
    function _brow_i18n_format
        # 简单地返回第一个参数，忽略格式化
        _brow_i18n_get $argv[1]
    end
end

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
        # 获取所有键，但排除settings
        jq -r 'keys[] | select(. != "settings")' $config_file
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
                        set -l status_text (_brow_i18n_get forward_status_active)
                        set -l config_description "$config_name (port:$local_port) [$status_text]"
                        echo $config_name\t$config_description
                    end
                end
            end
        end
    end

    # 添加所有配置名称作为选项，但只添加那些还没有被处理过的
    for config_name in (__brow_config_names)
        if not contains $config_name $processed_configs
            set -l config_text (_brow_i18n_get completion_config)
            echo $config_name\t"$config_name [$config_text]"
        end
    end
end

function __brow_k8s_contexts
    # 获取所有Kubernetes上下文
    kubectl config get-contexts --output=name 2>/dev/null
end

# 主命令补全
complete -c brow -f -n __brow_needs_command -a start -d (_brow_i18n_get 'completion_cmd_start')
complete -c brow -f -n __brow_needs_command -a list -d (_brow_i18n_get 'completion_cmd_list')
complete -c brow -f -n __brow_needs_command -a stop -d (_brow_i18n_get 'completion_cmd_stop')

# 选项补全
# 低序号端口(0-1023)会自动使用sudo，不再需要--sudo选项
complete -c brow -f -n __brow_needs_command -a config -d (_brow_i18n_get 'completion_cmd_config')
complete -c brow -f -n __brow_needs_command -a pod -d (_brow_i18n_get 'completion_cmd_pod')
complete -c brow -f -n __brow_needs_command -a forward -d (_brow_i18n_get 'completion_cmd_forward')
complete -c brow -f -n __brow_needs_command -a health-check -d (_brow_i18n_get 'completion_cmd_health_check')
complete -c brow -f -n __brow_needs_command -a version -d (_brow_i18n_get 'completion_cmd_version')
complete -c brow -f -n __brow_needs_command -a help -d (_brow_i18n_get 'completion_cmd_help')
complete -c brow -f -n __brow_needs_command -a language -d (_brow_i18n_get 'completion_cmd_language')

# config 子命令补全
complete -c brow -f -n "__brow_using_command config" -a add -d (_brow_i18n_get 'completion_subcmd_config_add')
complete -c brow -f -n "__brow_using_command config" -a list -d (_brow_i18n_get 'completion_subcmd_config_list')
complete -c brow -f -n "__brow_using_command config" -a show -d (_brow_i18n_get 'completion_subcmd_config_show')
complete -c brow -f -n "__brow_using_command config" -a edit -d (_brow_i18n_get 'completion_subcmd_config_edit')
complete -c brow -f -n "__brow_using_command config" -a remove -d (_brow_i18n_get 'completion_subcmd_config_remove')

# pod 子命令补全
complete -c brow -f -n "__brow_using_command pod" -a create -d (_brow_i18n_get 'completion_subcmd_pod_create')
complete -c brow -f -n "__brow_using_command pod" -a list -d (_brow_i18n_get 'completion_subcmd_pod_list')
complete -c brow -f -n "__brow_using_command pod" -a info -d (_brow_i18n_get 'completion_subcmd_pod_info')
complete -c brow -f -n "__brow_using_command pod" -a delete -d (_brow_i18n_get 'completion_subcmd_pod_delete')
complete -c brow -f -n "__brow_using_command pod" -a cleanup -d (_brow_i18n_get 'completion_subcmd_pod_cleanup')

# forward 子命令补全
complete -c brow -f -n "__brow_using_command forward" -a start -d (_brow_i18n_get 'completion_subcmd_forward_start')
complete -c brow -f -n "__brow_using_command forward" -a list -d (_brow_i18n_get 'completion_subcmd_forward_list')
complete -c brow -f -n "__brow_using_command forward" -a stop -d (_brow_i18n_get 'completion_subcmd_forward_stop')

# 配置名称补全
complete -c brow -f -n "__brow_using_subcommand config show" -a "(__brow_config_names)"
complete -c brow -f -n "__brow_using_subcommand config edit" -a "(__brow_config_names)"
complete -c brow -f -n "__brow_using_subcommand config remove" -a "(__brow_config_names)"
complete -c brow -f -n "__brow_using_subcommand pod create" -a "(__brow_config_names)"
complete -c brow -f -n "__brow_using_command start" -a "(__brow_config_names)"

# Pod ID补全
complete -c brow -f -n "__brow_using_subcommand pod info" -a "(__brow_pod_ids)"
complete -c brow -f -n "__brow_using_subcommand pod delete" -a "(__brow_pod_ids)"
complete -c brow -f -n "__brow_using_subcommand forward start" -a "(__brow_pod_ids)"

# 转发ID补全
complete -c brow -f -n "__brow_using_subcommand forward stop" -a "(__brow_forward_ids)"
complete -c brow -f -n "__brow_using_command stop" -a "(__brow_forward_ids)"

# Kubernetes上下文补全
complete -c brow -f -n "__brow_using_subcommand config add" -a "(__brow_k8s_contexts)"

# language 子命令补全
complete -c brow -f -n "__brow_using_command language" -a set -d (_brow_i18n_get 'completion_subcmd_language_set')
complete -c brow -f -n "__brow_using_subcommand language set" -a "zh en ru"
