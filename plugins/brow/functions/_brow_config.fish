function _brow_config_exists --argument-names config_name
    # 检查配置是否存在
    set -l config_file ~/.config/brow/config.json
    set -l exists (jq -r "has(\"$config_name\")" $config_file)

    if test "$exists" = true
        return 0
    else
        return 1
    end
end

function _brow_config_get --argument-names config_name
    # 获取配置数据
    set -l config_file ~/.config/brow/config.json

    if _brow_config_exists $config_name
        jq -r ".[\"$config_name\"]" $config_file
        return 0
    else
        return 1
    end
end

function _brow_config_add
    # 添加新配置
    # 用法: _brow_config_add <名称> <上下文> <IP> [本地端口] [远程端口] [服务名称] [TTL]

    if test (count $argv) -lt 3
        echo (_brow_i18n_get "usage_config_add")
        return 1
    end

    set -l config_name $argv[1]
    set -l k8s_context $argv[2]
    set -l ip $argv[3]
    set -l local_port 5433 # 默认本地端口
    set -l remote_port 5432 # 默认远程端口
    set -l service_name service # 默认服务名称
    set -l ttl 30m # 默认TTL

    # 如果提供了第四个参数，设置为本地端口
    if test (count $argv) -ge 4
        set local_port $argv[4]
    end

    # 如果提供了第五个参数，设置为远程端口
    if test (count $argv) -ge 5
        set remote_port $argv[5]
    end

    # 如果提供了第六个参数，设置为服务名称
    if test (count $argv) -ge 6
        set service_name $argv[6]
    end

    # 如果提供了第七个参数，设置为TTL
    if test (count $argv) -ge 7
        set ttl $argv[7]
    end

    # 检查配置是否已存在
    set -l config_file ~/.config/brow/config.json

    if _brow_config_exists $config_name
        echo (_brow_i18n_format "error_config_exists" $config_name)
        echo (_brow_i18n_format "use_config_edit" $config_name)
        return 1
    end

    # 使用jo创建JSON对象
    set -l config_json (jo k8s_context=$k8s_context ip=$ip local_port=$local_port remote_port=$remote_port service_name=$service_name ttl=$ttl)

    # 将新配置添加到配置文件
    set -l temp_file (mktemp)
    jq ".[\"$config_name\"] = $config_json" $config_file >$temp_file
    mv $temp_file $config_file

    echo (_brow_i18n_format "config_created" $config_name)
    echo (_brow_i18n_format "pod_context" $k8s_context)
    echo (_brow_i18n_format "pod_ip" $ip)
    echo (_brow_i18n_format "config_local_port" $local_port)
    echo (_brow_i18n_format "config_remote_port" $remote_port)
    echo (_brow_i18n_format "service_name" $service_name)
    echo "  TTL: $ttl"
end

function _brow_config_list
    # 列出所有配置
    set -l config_file ~/.config/brow/config.json

    echo (_brow_i18n_get "config_list_title")
    echo

    # 检查是否有配置
    set -l config_count (jq -r 'keys | map(select(. != "settings")) | length' $config_file)

    if test $config_count -eq 0
        echo (_brow_i18n_get "no_configs_found")
        return 0
    end

    # 获取所有配置名称，但排除settings
    set -l config_names (jq -r 'keys[] | select(. != "settings")' $config_file)

    # 准备表头
    set -l headers
    set -a headers (_brow_i18n_get "config_name")
    set -a headers (_brow_i18n_get "k8s_context")
    set -a headers IP
    set -a headers (_brow_i18n_get "local_port")
    set -a headers (_brow_i18n_get "remote_port")
    set -a headers (_brow_i18n_get "service")
    set -a headers TTL

    # 计算列宽
    set -l widths
    set -a widths 20 # 配置名称
    set -a widths 30 # Kubernetes上下文
    set -a widths 15 # IP
    set -a widths 10 # 本地端口
    set -a widths 10 # 远程端口
    set -a widths 15 # 服务
    set -a widths 10 # TTL

    # 更新列宽以适应表头
    for i in (seq (count $headers))
        set -l header_width (string length --visible -- $headers[$i])
        if test $header_width -gt $widths[$i]
            set widths[$i] $header_width
        end
    end

    # 更新列宽以适应数据
    for name in $config_names
        set -l k8s_context (jq -r ".[\"$name\"].k8s_context" $config_file)
        set -l ip (jq -r ".[\"$name\"].ip" $config_file)
        set -l local_port (jq -r ".[\"$name\"].local_port" $config_file)
        set -l remote_port (jq -r ".[\"$name\"].remote_port" $config_file)
        set -l service_name (jq -r ".[\"$name\"].service_name" $config_file)
        set -l ttl (jq -r ".[\"$name\"].ttl" $config_file)

        # 更新列宽
        set -l name_width (string length --visible -- $name)
        if test $name_width -gt $widths[1]
            set widths[1] $name_width
        end

        set -l ctx_width (string length --visible -- $k8s_context)
        if test $ctx_width -gt $widths[2]
            set widths[2] $ctx_width
        end

        set -l ip_width (string length --visible -- $ip)
        if test $ip_width -gt $widths[3]
            set widths[3] $ip_width
        end

        set -l local_port_width (string length --visible -- $local_port)
        if test $local_port_width -gt $widths[4]
            set widths[4] $local_port_width
        end

        set -l remote_port_width (string length --visible -- $remote_port)
        if test $remote_port_width -gt $widths[5]
            set widths[5] $remote_port_width
        end

        set -l service_width (string length --visible -- $service_name)
        if test $service_width -gt $widths[6]
            set widths[6] $service_width
        end

        set -l ttl_width (string length --visible -- $ttl)
        if test $ttl_width -gt $widths[7]
            set widths[7] $ttl_width
        end
    end

    # 打印表头
    echo -n ""
    _pad_to_width $headers[1] $widths[1]
    echo -n " "
    _pad_to_width $headers[2] $widths[2]
    echo -n " "
    _pad_to_width $headers[3] $widths[3]
    echo -n " "
    _pad_to_width $headers[4] $widths[4]
    echo -n " "
    _pad_to_width $headers[5] $widths[5]
    echo -n " "
    _pad_to_width $headers[6] $widths[6]
    echo -n " "
    _pad_to_width $headers[7] $widths[7]
    echo ""

    # 打印分隔线
    echo -n ""
    _pad_to_width (string repeat -n $widths[1] "-") $widths[1]
    echo -n " "
    _pad_to_width (string repeat -n $widths[2] "-") $widths[2]
    echo -n " "
    _pad_to_width (string repeat -n $widths[3] "-") $widths[3]
    echo -n " "
    _pad_to_width (string repeat -n $widths[4] "-") $widths[4]
    echo -n " "
    _pad_to_width (string repeat -n $widths[5] "-") $widths[5]
    echo -n " "
    _pad_to_width (string repeat -n $widths[6] "-") $widths[6]
    echo -n " "
    _pad_to_width (string repeat -n $widths[7] "-") $widths[7]
    echo ""

    # 打印每个配置
    for name in $config_names
        set -l k8s_context (jq -r ".[\"$name\"].k8s_context" $config_file)
        set -l ip (jq -r ".[\"$name\"].ip" $config_file)
        set -l local_port (jq -r ".[\"$name\"].local_port" $config_file)
        set -l remote_port (jq -r ".[\"$name\"].remote_port" $config_file)
        set -l service_name (jq -r ".[\"$name\"].service_name" $config_file)
        set -l ttl (jq -r ".[\"$name\"].ttl" $config_file)

        # 打印行
        echo -n ""
        _pad_to_width $name $widths[1]
        echo -n " "
        _pad_to_width $k8s_context $widths[2]
        echo -n " "
        _pad_to_width $ip $widths[3]
        echo -n " "
        _pad_to_width $local_port $widths[4]
        echo -n " "
        _pad_to_width $remote_port $widths[5]
        echo -n " "
        _pad_to_width $service_name $widths[6]
        echo -n " "
        _pad_to_width $ttl $widths[7]
        echo ""
    end
end

function _brow_config_show --argument-names config_name
    # 显示特定配置详情

    if not _brow_config_exists $config_name
        echo (_brow_i18n_format "error_config_not_found" $config_name)
        return 1
    end

    set -l config_file ~/.config/brow/config.json
    set -l config_data (jq -r ".[\"$config_name\"]" $config_file)

    set -l k8s_context (echo $config_data | jq -r '.k8s_context')
    set -l ip (echo $config_data | jq -r '.ip')
    set -l local_port (echo $config_data | jq -r '.local_port')
    set -l remote_port (echo $config_data | jq -r '.remote_port')
    set -l service_name (echo $config_data | jq -r '.service_name')
    set -l ttl (echo $config_data | jq -r '.ttl')

    echo (_brow_i18n_format "pod_config" $config_name)
    echo (_brow_i18n_format "pod_context" $k8s_context)
    echo (_brow_i18n_format "pod_ip" $ip)
    echo (_brow_i18n_format "config_local_port" $local_port)
    echo (_brow_i18n_format "config_remote_port" $remote_port)
    echo (_brow_i18n_format "service_name" $service_name)
    echo "  TTL: $ttl"

    # 检查是否有活跃的Pod
    # 获取配置中的上下文
    set -l k8s_context (echo $config_data | jq -r '.k8s_context')
    set -l active_pods (kubectl --context=$k8s_context get pods --selector=app=brow-$config_name -o json 2>/dev/null | jq -r '.items[].metadata.name')

    if test -n "$active_pods"
        echo
        echo (_brow_i18n_get "active_pods")
        for pod in $active_pods
            echo "  $pod"
        end
    end
end

function _brow_config_edit --argument-names config_name
    # 编辑配置

    if not _brow_config_exists $config_name
        echo (_brow_i18n_format "error_config_not_found" $config_name)
        return 1
    end

    set -l config_file ~/.config/brow/config.json

    # 获取当前配置
    set -l current_k8s_context (jq -r ".[\"$config_name\"].k8s_context" $config_file)
    set -l current_ip (jq -r ".[\"$config_name\"].ip" $config_file)
    set -l current_local_port (jq -r ".[\"$config_name\"].local_port" $config_file)
    set -l current_remote_port (jq -r ".[\"$config_name\"].remote_port" $config_file)
    set -l current_service_name (jq -r ".[\"$config_name\"].service_name" $config_file)
    set -l current_ttl (jq -r ".[\"$config_name\"].ttl" $config_file)

    # 显示当前配置
    echo (_brow_i18n_format "editing_config" $config_name)
    echo (_brow_i18n_get "enter_to_keep")

    # Kubernetes上下文
    read -l -P (_brow_i18n_format "edit_k8s_context" $current_k8s_context) new_k8s_context
    if test -z "$new_k8s_context"
        set new_k8s_context $current_k8s_context
    end

    # IP
    read -l -P "IP [$current_ip]: " new_ip
    if test -z "$new_ip"
        set new_ip $current_ip
    end

    # 本地端口
    read -l -P (_brow_i18n_format "edit_local_port" $current_local_port) new_local_port
    if test -z "$new_local_port"
        set new_local_port $current_local_port
    end

    # 远程端口
    read -l -P (_brow_i18n_format "edit_remote_port" $current_remote_port) new_remote_port
    if test -z "$new_remote_port"
        set new_remote_port $current_remote_port
    end

    # 服务名称
    read -l -P (_brow_i18n_format "edit_service_name" $current_service_name) new_service_name
    if test -z "$new_service_name"
        set new_service_name $current_service_name
    end

    # TTL
    read -l -P (_brow_i18n_format "edit_ttl" $current_ttl) new_ttl
    if test -z "$new_ttl"
        set new_ttl $current_ttl
    end

    # 使用jo创建JSON对象
    set -l config_json (jo k8s_context=$new_k8s_context ip=$new_ip local_port=$new_local_port remote_port=$new_remote_port service_name=$new_service_name ttl=$new_ttl)

    # 检查是否有变化
    set -l current_json (jq -c ".[\"$config_name\"]" $config_file)

    if test "$current_json" != "$config_json"
        # 更新配置文件
        set -l temp_file (mktemp)
        jq ".[\"$config_name\"] = $config_json" $config_file >$temp_file
        mv $temp_file $config_file

        echo (_brow_i18n_format "config_updated" $config_name)
    else
        echo (_brow_i18n_get "config_unchanged")
    end
end

function _brow_config_remove --argument-names config_name
    # 删除配置

    if not _brow_config_exists $config_name
        echo (_brow_i18n_format "error_config_not_found" $config_name)
        return 1
    end

    # 检查是否有活跃的Pod
    # 获取配置中的上下文
    set -l config_data (_brow_config_get $config_name)
    set -l k8s_context (echo $config_data | jq -r '.k8s_context')
    set -l active_pods (kubectl --context=$k8s_context get pods --selector=app=brow-$config_name -o json 2>/dev/null | jq -r '.items[].metadata.name')

    if test -n "$active_pods"
        echo (_brow_i18n_format "warning_config_has_pods" $config_name)
        for pod in $active_pods
            echo "  $pod"
        end

        read -l -P (_brow_i18n_get "confirm_delete_config") confirm

        if test "$confirm" != y -a "$confirm" != Y
            echo (_brow_i18n_get "operation_cancelled")
            return 1
        end
    end

    # 删除配置
    set -l config_file ~/.config/brow/config.json
    set -l temp_file (mktemp)

    jq "del(.[\"$config_name\"])" $config_file >$temp_file
    mv $temp_file $config_file

    echo (_brow_i18n_format "config_deleted" $config_name)
end
