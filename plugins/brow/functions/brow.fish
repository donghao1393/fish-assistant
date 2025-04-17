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

function brow --description "Kubernetes 连接管理工具"
    set -l brow_version "0.1.0"

    # 检查依赖
    if not command -v kubectl >/dev/null
        echo "错误: 未找到 kubectl。请先安装它。"
        return 1
    end

    if not command -v jq >/dev/null
        echo "错误: 未找到 jq。请先安装它。"
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
                echo "错误: config 命令需要指定操作类型 (add/list/show/edit/remove)"
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
                        echo "用法: brow config show <配置名称>"
                        return 1
                    end
                    _brow_config_show $argv[1]
                case edit
                    if test (count $argv) -ne 1
                        echo "用法: brow config edit <配置名称>"
                        return 1
                    end
                    _brow_config_edit $argv[1]
                case remove
                    if test (count $argv) -ne 1
                        echo "用法: brow config remove <配置名称>"
                        return 1
                    end
                    _brow_config_remove $argv[1]
                case '*'
                    echo "未知的 config 子命令: $subcmd"
                    echo "可用的子命令: add, list, show, edit, remove"
                    return 1
            end

        case pod
            if test (count $argv) -lt 1
                echo "错误: pod 命令需要指定操作类型 (create/list/info/delete/cleanup)"
                return 1
            end

            set -l subcmd $argv[1]
            set -e argv[1]

            switch $subcmd
                case create
                    if test (count $argv) -ne 1
                        echo "用法: brow pod create <配置名称>"
                        return 1
                    end
                    _brow_pod_create $argv[1]
                case list
                    _brow_pod_list
                case info
                    if test (count $argv) -ne 1
                        echo "用法: brow pod info <pod-id|配置名称>"
                        return 1
                    end
                    _brow_pod_info $argv[1]
                case delete
                    if test (count $argv) -ne 1
                        echo "用法: brow pod delete <pod-id|配置名称>"
                        return 1
                    end
                    _brow_pod_delete $argv[1]
                case cleanup
                    _brow_pod_cleanup
                case '*'
                    echo "未知的 pod 子命令: $subcmd"
                    echo "可用的子命令: create, list, info, delete, cleanup"
                    return 1
            end

        case forward
            if test (count $argv) -lt 1
                echo "错误: forward 命令需要指定操作类型 (start/list/stop)"
                return 1
            end

            set -l subcmd $argv[1]
            set -e argv[1]

            switch $subcmd
                case start
                    if test (count $argv) -lt 1
                        echo "用法: brow forward start <配置名称> [local_port]"
                        return 1
                    end

                    set -l config_name $argv[1]
                    set -l local_port ""

                    if test (count $argv) -ge 2
                        set local_port $argv[2]
                    end

                    # 检查配置是否存在
                    if not _brow_config_exists $config_name
                        echo "错误: 配置 '$config_name' 不存在"
                        echo "请使用 'brow config list' 查看可用的配置"
                        return 1
                    end

                    # 直接调用_brow_forward_start函数，并将其输出传递给用户
                    # 返回值是转发ID
                    set -l forward_id (_brow_forward_start $config_name $local_port)

                    # 如果成功，显示转发ID
                    if test $status -eq 0
                        echo "转发ID: $forward_id"
                    end
                case list
                    _brow_forward_list
                case stop
                    if test (count $argv) -ne 1
                        echo "用法: brow forward stop <forward-id|配置名称>"
                        return 1
                    end
                    # 不自动删除Pod（第二个参数为false）
                    _brow_forward_stop $argv[1] false
                case '*'
                    echo "未知的 forward 子命令: $subcmd"
                    echo "可用的子命令: start, list, stop"
                    return 1
            end

        case list # 新增简化命令
            # 列出活跃的连接，直接调用forward list
            _brow_forward_list

        case stop
            # 停止连接，直接调用forward stop
            if test (count $argv) -ne 1
                echo "用法: brow stop <连接ID|配置名称>"
                return 1
            end
            # 自动删除Pod（第二个参数为true）
            _brow_forward_stop $argv[1] true

        case connect
            # 创建连接
            if test (count $argv) -lt 1
                echo "用法: brow connect <配置名称> [本地端口]"
                return 1
            end

            set -l config_name $argv[1]
            set -l local_port ""

            if test (count $argv) -ge 2
                set local_port $argv[2]
            end

            # 检查配置是否存在
            if not _brow_config_exists $config_name
                echo "错误: 配置 '$config_name' 不存在"
                echo "请使用 'brow config list' 查看可用的配置"
                return 1
            end

            # 直接调用_brow_connect函数
            _brow_connect $config_name $local_port

        case health-check
            # 检查和修复不一致的状态
            echo "正在进行健康检查..."

            # 检查转发记录
            echo "检查转发记录..."
            _brow_forward_list >/dev/null

            # 检查过期的Pod
            echo "检查过期的Pod..."
            _brow_pod_cleanup

            echo 健康检查完成

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
                        echo "Available languages: "(_brow_i18n_get_available_languages)
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
            echo "未知命令: $cmd"
            _brow_help
            return 1
    end
end

function _brow_help
    echo "brow - Kubernetes 连接管理工具"
    echo
    echo "主要命令:"
    echo "  brow connect <配置名称> [本地端口]     创建连接到指定配置"
    echo "  brow list                         列出活跃的连接"
    echo "  brow stop <连接ID|配置名称>        停止连接并删除Pod"
    echo
    echo "配置管理:"
    echo "  brow config add <名称> <Kubernetes上下文> <IP> [本地端口] [远程端口] [服务名称] [TTL]"
    echo "  brow config list                  列出所有配置"
    echo "  brow config show <名称>           显示特定配置详情"
    echo "  brow config edit <名称>           编辑配置"
    echo "  brow config remove <名称>         删除配置"
    echo
    echo "高级功能:"
    echo "  brow pod list                     列出当前所有 Pod"
    echo "  brow pod info <配置名称>         查看指定配置的 Pod 详情"
    echo "  brow pod delete <配置名称>       删除指定配置的 Pod"
    echo "  brow pod cleanup                  清理过期的 Pod"
    echo "  brow forward list                 列出活跃的转发 (同 brow list)"
    echo "  brow forward stop <ID|配置名称>    停止转发 (不删除Pod)"
    echo "  brow forward start <配置名称> [本地端口]  开始端口转发 (同 brow connect)"
    echo "  brow health-check                  检查和修复不一致的状态"
    echo "  brow language                     显示当前语言设置"
    echo "  brow language set <语言代码>      设置语言 (zh, en, ...)"
    echo "  brow version                      显示版本信息"
    echo "  brow help                         显示此帮助信息"
    echo
    echo "示例:"
    echo "  brow config add mysql-dev oasis-dev-aks-admin 10.0.0.1 3306 3306 mysql 30m"
    echo "  brow connect mysql-dev            # 创建连接"
    echo "  brow list                         # 查看连接"
    echo "  brow stop mysql-dev              # 停止连接"
end

function _brow_connect --argument-names config_name local_port
    # 一步完成创建 Pod 和转发

    # 先检查配置是否存在
    if not _brow_config_exists $config_name
        echo "错误: 配置 '$config_name' 不存在"
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
        echo "尝试使用备用端口..."
        # 尝试使用备用端口
        set -l backup_port (math $local_port + 1000)
        echo "尝试端口: $backup_port"
        set -l backup_id (_brow_forward_start $config_name $backup_port)
        set -l backup_status $status

        if test $backup_status -eq 0
            echo "转发ID: $backup_id"
        else
            echo "错误: 无法创建连接，请检查配置和网络状态"
            return 1
        end
    else
        echo "转发ID: $forward_id"
    end
end
