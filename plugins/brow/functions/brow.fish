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
        echo "{}" > $config_file
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
                        echo "用法: brow pod info <pod-id>"
                        return 1
                    end
                    _brow_pod_info $argv[1]
                case delete
                    if test (count $argv) -ne 1
                        echo "用法: brow pod delete <pod-id>"
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
                        echo "用法: brow forward start <pod-id> [local_port]"
                        return 1
                    end

                    set -l pod_id $argv[1]
                    set -l local_port ""

                    if test (count $argv) -ge 2
                        set local_port $argv[2]
                    end

                    _brow_forward_start $pod_id $local_port
                case list
                    _brow_forward_list
                case stop
                    if test (count $argv) -ne 1
                        echo "用法: brow forward stop <forward-id>"
                        return 1
                    end
                    _brow_forward_stop $argv[1]
                case '*'
                    echo "未知的 forward 子命令: $subcmd"
                    echo "可用的子命令: start, list, stop"
                    return 1
            end

        case connect
            if test (count $argv) -ne 1
                echo "用法: brow connect <配置名称>"
                return 1
            end
            _brow_connect $argv[1]

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
    echo "用法:"
    echo "  brow config add <名称> <Kubernetes上下文> <IP> [本地端口] [远程端口] [服务名称] [TTL]"
    echo "  brow config list                  列出所有配置"
    echo "  brow config show <名称>           显示特定配置详情"
    echo "  brow config edit <名称>           编辑配置"
    echo "  brow config remove <名称>         删除配置"
    echo
    echo "  brow pod create <配置名称>        根据配置创建 Pod"
    echo "  brow pod list                     列出当前所有 Pod"
    echo "  brow pod info <pod-id>           查看 Pod 详细信息"
    echo "  brow pod delete <pod-id>         手动删除 Pod"
    echo "  brow pod cleanup                  清理过期的 Pod"
    echo
    echo "  brow forward start <pod-id> [本地端口]  开始端口转发"
    echo "  brow forward list                 列出活跃的转发"
    echo "  brow forward stop <forward-id>    停止特定的转发"
    echo
    echo "  brow connect <配置名称>           一步完成创建 Pod 和转发"
    echo "  brow version                      显示版本信息"
    echo "  brow help                         显示此帮助信息"
    echo
    echo "示例:"
    echo "  brow config add mysql-dev oasis-dev-aks-admin 10.0.0.1 3306 3306 mysql 30m"
    echo "  brow connect mysql-dev"
end

function _brow_connect --argument-names config_name
    # 一步完成创建 Pod 和转发

    # 先检查配置是否存在
    if not _brow_config_exists $config_name
        echo "错误: 配置 '$config_name' 不存在"
        return 1
    end

    # 创建 Pod
    set -l pod_id (_brow_pod_create $config_name)
    if test $status -ne 0
        echo "错误: 创建 Pod 失败"
        return 1
    end

    # 获取配置中的本地端口
    set -l config_data (_brow_config_get $config_name)
    set -l local_port (echo $config_data | jq -r '.local_port')

    # 开始端口转发
    _brow_forward_start $pod_id $local_port
end