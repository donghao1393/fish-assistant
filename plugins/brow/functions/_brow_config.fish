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
        echo "用法: brow config add <名称> <上下文> <IP> [本地端口=5433] [远程端口=5432] [服务名称=service] [TTL=30m]"
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
        echo "错误: 配置 '$config_name' 已存在"
        echo "请使用 'brow config edit $config_name' 编辑现有配置"
        return 1
    end

    # 使用jo创建JSON对象
    set -l config_json (jo k8s_context=$k8s_context ip=$ip local_port=$local_port remote_port=$remote_port service_name=$service_name ttl=$ttl)

    # 将新配置添加到配置文件
    set -l temp_file (mktemp)
    jq ".[\"$config_name\"] = $config_json" $config_file >$temp_file
    mv $temp_file $config_file

    echo "配置 '$config_name' 已添加:"
    echo "  Kubernetes上下文: $k8s_context"
    echo "  IP: $ip"
    echo "  本地端口: $local_port"
    echo "  远程端口: $remote_port"
    echo "  服务名称: $service_name"
    echo "  TTL: $ttl"
end

function _brow_config_list
    # 列出所有配置
    set -l config_file ~/.config/brow/config.json

    echo "可用的连接配置:"
    echo

    # 检查是否有配置
    set -l config_count (jq -r 'keys | length' $config_file)

    if test $config_count -eq 0
        echo "没有找到配置。使用 'brow config add' 添加新配置。"
        return 0
    end

    # 获取所有配置名称
    set -l config_names (jq -r 'keys[]' $config_file)

    # 打印表头
    printf "%-20s %-30s %-15s %-10s %-10s %-15s %-10s\n" 名称 Kubernetes上下文 IP 本地端口 远程端口 服务名称 TTL
    printf "%-20s %-30s %-15s %-10s %-10s %-15s %-10s\n" -------------------- ------------------------------ --------------- ---------- ---------- --------------- ----------

    # 打印每个配置
    for name in $config_names
        set -l k8s_context (jq -r ".[\"$name\"].k8s_context" $config_file)
        set -l ip (jq -r ".[\"$name\"].ip" $config_file)
        set -l local_port (jq -r ".[\"$name\"].local_port" $config_file)
        set -l remote_port (jq -r ".[\"$name\"].remote_port" $config_file)
        set -l service_name (jq -r ".[\"$name\"].service_name" $config_file)
        set -l ttl (jq -r ".[\"$name\"].ttl" $config_file)

        printf "%-20s %-30s %-15s %-10s %-10s %-15s %-10s\n" $name $k8s_context $ip $local_port $remote_port $service_name $ttl
    end
end

function _brow_config_show --argument-names config_name
    # 显示特定配置详情

    if not _brow_config_exists $config_name
        echo "错误: 配置 '$config_name' 不存在"
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

    echo "配置: $config_name"
    echo "  Kubernetes上下文: $k8s_context"
    echo "  IP: $ip"
    echo "  本地端口: $local_port"
    echo "  远程端口: $remote_port"
    echo "  服务名称: $service_name"
    echo "  TTL: $ttl"

    # 检查是否有活跃的Pod
    # 获取配置中的上下文
    set -l k8s_context (echo $config_data | jq -r '.k8s_context')
    set -l active_pods (kubectl --context=$k8s_context get pods --selector=app=brow-$config_name -o json 2>/dev/null | jq -r '.items[].metadata.name')

    if test -n "$active_pods"
        echo
        echo "活跃的Pod:"
        for pod in $active_pods
            echo "  $pod"
        end
    end
end

function _brow_config_edit --argument-names config_name
    # 编辑配置

    if not _brow_config_exists $config_name
        echo "错误: 配置 '$config_name' 不存在"
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
    echo "编辑配置: $config_name"
    echo "按Enter保留当前值，或输入新值"

    # Kubernetes上下文
    read -l -P "Kubernetes上下文 [$current_k8s_context]: " new_k8s_context
    if test -z "$new_k8s_context"
        set new_k8s_context $current_k8s_context
    end

    # IP
    read -l -P "IP [$current_ip]: " new_ip
    if test -z "$new_ip"
        set new_ip $current_ip
    end

    # 本地端口
    read -l -P "本地端口 [$current_local_port]: " new_local_port
    if test -z "$new_local_port"
        set new_local_port $current_local_port
    end

    # 远程端口
    read -l -P "远程端口 [$current_remote_port]: " new_remote_port
    if test -z "$new_remote_port"
        set new_remote_port $current_remote_port
    end

    # 服务名称
    read -l -P "服务名称 [$current_service_name]: " new_service_name
    if test -z "$new_service_name"
        set new_service_name $current_service_name
    end

    # TTL
    read -l -P "TTL [$current_ttl]: " new_ttl
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

        echo "配置 '$config_name' 已更新"
    else
        echo 配置未变化
    end
end

function _brow_config_remove --argument-names config_name
    # 删除配置

    if not _brow_config_exists $config_name
        echo "错误: 配置 '$config_name' 不存在"
        return 1
    end

    # 检查是否有活跃的Pod
    # 获取配置中的上下文
    set -l config_data (_brow_config_get $config_name)
    set -l k8s_context (echo $config_data | jq -r '.k8s_context')
    set -l active_pods (kubectl --context=$k8s_context get pods --selector=app=brow-$config_name -o json 2>/dev/null | jq -r '.items[].metadata.name')

    if test -n "$active_pods"
        echo "警告: 配置 '$config_name' 有活跃的Pod:"
        for pod in $active_pods
            echo "  $pod"
        end

        read -l -P "是否仍要删除配置? [y/N]: " confirm

        if test "$confirm" != y -a "$confirm" != Y
            echo 操作已取消
            return 1
        end
    end

    # 删除配置
    set -l config_file ~/.config/brow/config.json
    set -l temp_file (mktemp)

    jq "del(.[\"$config_name\"])" $config_file >$temp_file
    mv $temp_file $config_file

    echo "配置 '$config_name' 已删除"
end
