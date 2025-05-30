# 显式加载相关函数
if status is-interactive
    # 获取当前脚本所在目录
    set -l current_file (status filename)
    set -l script_dir (dirname $current_file)

    # 加载相关函数文件
    source $script_dir/_brow_config.fish
    source $script_dir/_brow_pod.fish
    source $script_dir/_brow_forward.fish
    source $script_dir/_brow_parse_time.fish
    source $script_dir/_brow_i18n.fish
end

function brow --description "Kubernetes Connection Manager"
    set -l brow_version "0.1.0"

    # 检查依赖
    if not command -v kubectl >/dev/null
        echo (_brow_i18n_get "error_kubectl_not_found")
        return 1
    end

    if not command -v jq >/dev/null
        echo (_brow_i18n_get "error_jq_not_found")
        return 1
    end

    # 初始化配置目录
    set -l config_dir ~/.config/brow
    if not test -d $config_dir
        mkdir -p $config_dir/active
    end

    # 配置文件路径
    set -l config_file $config_dir/config.json

    # 如果配置文件不存在，创建一个空的JSON对象
    if not test -f $config_file
        echo "{}" >$config_file
    end

    # 子命令解析
    if test (count $argv) -eq 0
        _brow_help
        return 0
    end

    set -l cmd $argv[1]
    set -e argv[1]

    switch $cmd
        case config
            if test (count $argv) -lt 1
                echo (_brow_i18n_get "error_config_cmd")
                return 1
            end

            set -l subcmd $argv[1]
            set -e argv[1]

            switch $subcmd
                case add
                    _brow_config_add $argv
                case list
                    _brow_config_list
                case show
                    if test (count $argv) -ne 1
                        echo (_brow_i18n_get "usage_config_show")
                        return 1
                    end
                    _brow_config_show $argv[1]
                case edit
                    if test (count $argv) -ne 1
                        echo (_brow_i18n_get "usage_config_edit")
                        return 1
                    end
                    _brow_config_edit $argv[1]
                case remove
                    if test (count $argv) -ne 1
                        echo (_brow_i18n_get "usage_config_remove")
                        return 1
                    end
                    _brow_config_remove $argv[1]
                case '*'
                    echo (_brow_i18n_format "unknown_config_subcmd" $subcmd)
                    echo (_brow_i18n_get "available_config_subcmds")
                    return 1
            end

        case pod
            if test (count $argv) -lt 1
                echo (_brow_i18n_get "error_pod_cmd")
                return 1
            end

            set -l subcmd $argv[1]
            set -e argv[1]

            switch $subcmd
                case create
                    if test (count $argv) -ne 1
                        echo (_brow_i18n_get "usage_pod_create")
                        return 1
                    end
                    _brow_pod_create $argv[1]
                case list
                    _brow_pod_list
                case info
                    if test (count $argv) -ne 1
                        echo (_brow_i18n_get "usage_pod_info")
                        return 1
                    end
                    _brow_pod_info $argv[1]
                case delete
                    if test (count $argv) -ne 1
                        echo (_brow_i18n_get "usage_pod_delete")
                        return 1
                    end
                    _brow_pod_delete $argv[1]
                case cleanup
                    _brow_pod_cleanup
                case '*'
                    echo (_brow_i18n_format "unknown_pod_subcmd" $subcmd)
                    echo (_brow_i18n_get "available_pod_subcmds")
                    return 1
            end

        case forward
            if test (count $argv) -lt 1
                echo (_brow_i18n_get "error_forward_cmd")
                return 1
            end

            set -l subcmd $argv[1]
            set -e argv[1]

            switch $subcmd
                case start
                    # 检查是否有足够的参数
                    set -l args_count (count $argv)
                    if test $args_count -lt 1
                        echo (_brow_i18n_get "usage_forward_start")
                        return 1
                    end

                    set -l config_name $argv[1]
                    set -l local_port ""

                    if test $args_count -ge 2
                        set local_port $argv[2]
                    end

                    # 检查配置是否存在
                    if not _brow_config_exists $config_name
                        echo (_brow_i18n_format "error_config_not_found" $config_name)
                        echo (_brow_i18n_get "use_config_list")
                        return 1
                    end

                    # 直接调用_brow_forward_start函数，并将其输出传递给用户
                    # 返回值是转发ID
                    set -l forward_id (_brow_forward_start $config_name $local_port)

                    # 如果成功，显示转发ID
                    if test $status -eq 0
                        echo (_brow_i18n_format "forward_id" $forward_id)
                    end
                case list
                    _brow_forward_list
                case stop
                    if test (count $argv) -ne 1
                        echo (_brow_i18n_get "usage_forward_stop")
                        return 1
                    end
                    # 不自动删除Pod（第二个参数为false）
                    _brow_forward_stop $argv[1] false
                case '*'
                    echo (_brow_i18n_format "unknown_forward_subcmd" $subcmd)
                    echo (_brow_i18n_get "available_forward_subcmds")
                    return 1
            end

        case list # 新增简化命令
            # 列出活跃的连接，直接调用forward list
            _brow_forward_list

        case stop
            # 停止连接，直接调用forward stop
            if test (count $argv) -ne 1
                echo (_brow_i18n_get "usage_stop")
                return 1
            end
            # 自动删除Pod（第二个参数为true）
            _brow_forward_stop $argv[1] true

        case start
            # 创建连接
            # 检查是否有足够的参数
            set -l args_count (count $argv)
            if test $args_count -lt 1
                echo (_brow_i18n_get "usage_start")
                return 1
            end

            set -l config_name $argv[1]
            set -l local_port ""

            if test $args_count -ge 2
                set local_port $argv[2]
            end

            # 检查配置是否存在
            if not _brow_config_exists $config_name
                echo (_brow_i18n_format "error_config_not_found" $config_name)
                echo (_brow_i18n_get "use_config_list")
                return 1
            end

            # 直接调用_brow_connect函数
            _brow_connect $config_name $local_port

        case health-check
            # 检查和修复不一致的状态
            echo (_brow_i18n_get "health_check_start")

            # 检查转发记录
            echo (_brow_i18n_get "checking_forwards")
            _brow_forward_list >/dev/null

            # 检查过期的Pod
            echo (_brow_i18n_get "checking_expired_pods")
            _brow_pod_cleanup

            echo (_brow_i18n_get "health_check_complete")

        case language
            if test (count $argv) -lt 1
                # 显示当前语言
                _brow_i18n_init
                echo (_brow_i18n_format "language_current" $_brow_i18n_current_lang)
                echo (_brow_i18n_format "available_languages" (_brow_i18n_get_available_languages))
                return 0
            end

            set -l subcmd $argv[1]
            set -e argv[1]

            switch $subcmd
                case set
                    if test (count $argv) -ne 1
                        echo "Usage: brow language set <language-code>"
                        set -l available_langs (_brow_i18n_get_available_languages)
                        echo "Available languages: $available_langs"
                        return 1
                    end

                    set -l lang $argv[1]
                    if _brow_i18n_set_language $lang
                        echo (_brow_i18n_format "language_set" $lang)
                    else
                        echo (_brow_i18n_format "language_not_supported" $lang)
                        return 1
                    end
                case '*'
                    echo "Unknown language subcommand: $subcmd"
                    echo "Available subcommands: set"
                    return 1
            end

        case version
            echo "brow v$brow_version"

        case help
            _brow_help

        case '*'
            echo (_brow_i18n_format "unknown_command" $cmd)
            _brow_help
            return 1
    end
end

function _brow_help
    echo (_brow_i18n_get "help_title")
    echo
    echo (_brow_i18n_get "help_main_commands")
    echo (_brow_i18n_get "help_cmd_start")
    echo (_brow_i18n_get "help_cmd_list")
    echo (_brow_i18n_get "help_cmd_stop")
    echo
    echo (_brow_i18n_get "help_config_management")
    echo (_brow_i18n_get "help_cmd_config_add")
    echo (_brow_i18n_get "help_cmd_config_list")
    echo (_brow_i18n_get "help_cmd_config_show")
    echo (_brow_i18n_get "help_cmd_config_edit")
    echo (_brow_i18n_get "help_cmd_config_remove")
    echo
    echo (_brow_i18n_get "help_advanced_features")
    echo (_brow_i18n_get "help_cmd_pod_list")
    echo (_brow_i18n_get "help_cmd_pod_info")
    echo (_brow_i18n_get "help_cmd_pod_delete")
    echo (_brow_i18n_get "help_cmd_pod_cleanup")
    echo (_brow_i18n_get "help_cmd_forward_list")
    echo (_brow_i18n_get "help_cmd_forward_stop")
    echo (_brow_i18n_get "help_cmd_forward_start")
    echo (_brow_i18n_get "help_cmd_health_check")
    echo (_brow_i18n_get "help_cmd_language")
    echo (_brow_i18n_get "help_cmd_language_set")
    echo (_brow_i18n_get "help_cmd_version")
    echo (_brow_i18n_get "help_cmd_help")
    echo
    echo (_brow_i18n_get "help_examples")
    echo (_brow_i18n_get "help_example_config_add")
    echo (_brow_i18n_get "help_example_start")
    echo (_brow_i18n_get "help_example_list")
    echo (_brow_i18n_get "help_example_stop")
end

function _brow_connect --argument-names config_name local_port
    # 一步完成创建 Pod 和转发
    # 注意: 低序号端口(0-1023)会自动使用sudo

    # 先检查配置是否存在
    if not _brow_config_exists $config_name
        echo (_brow_i18n_format "error_config_not_found" $config_name)
        return 1
    end

    # 如果没有指定本地端口，使用配置中的端口
    if test -z "$local_port"
        set -l config_data (_brow_config_get $config_name)
        set local_port (echo $config_data | jq -r '.local_port')
    end

    # 直接调用_brow_forward_start函数，它会处理Pod的创建和端口转发
    set -l forward_id (_brow_forward_start $config_name $local_port)
    set -l forward_status $status

    if test $forward_status -ne 0
        echo (_brow_i18n_get "trying_backup_port")
        # 尝试使用备用端口
        set -l backup_port (math $local_port + 1000)
        echo (_brow_i18n_format "trying_port" $backup_port)
        # 备用端口通常大于1024，不需要sudo
        set -l backup_id (_brow_forward_start $config_name $backup_port)
        set -l backup_status $status

        if test $backup_status -eq 0
            echo (_brow_i18n_format "forward_id" $backup_id)
        else
            echo (_brow_i18n_get "error_connection_failed")
            return 1
        end
    else
        echo (_brow_i18n_format "forward_id" $forward_id)
    end
end
