function _brow_pod_create --argument-names config_name
    # 根据配置创建Pod
    # 返回值: Pod名称（如果成功）

    if not _brow_config_exists $config_name
        echo "错误: 配置 '$config_name' 不存在" >&2
        return 1
    end

    # 获取配置数据
    set -l config_data (_brow_config_get $config_name)
    set -l k8s_context (echo $config_data | jq -r '.k8s_context')
    set -l ip (echo $config_data | jq -r '.ip')
    set -l remote_port (echo $config_data | jq -r '.remote_port')
    set -l service_name (echo $config_data | jq -r '.service_name')
    set -l ttl (echo $config_data | jq -r '.ttl')

    # 检查是否已经有该配置的Pod在运行
    # 使用stderr输出状态信息，避免影响stdout的返回值
    echo "检查是否已有运行中的Pod..." >&2
    set -l existing_pods (kubectl --context=$k8s_context get pods -l app=brow,brow-config=$config_name -o json 2>/dev/null | jq -r '.items[] | select(.status.phase == "Running") | .metadata.name')

    # 如果已经有运行中的Pod，直接返回该Pod
    if test -n "$existing_pods"
        set -l pod_name $existing_pods[1]
        echo "发现配置 '$config_name' 的Pod已存在: $pod_name" >&2
        # 只返回纯净的Pod名称，不返回其他信息
        echo "$pod_name"
        return 0
    end

    # 清理该配置的所有非运行状态的Pod
    set -l old_pods (kubectl --context=$k8s_context get pods -l app=brow,brow-config=$config_name -o json 2>/dev/null | jq -r '.items[] | select(.status.phase != "Running") | .metadata.name')
    if test -n "$old_pods"
        echo "清理配置 '$config_name' 的旧Pod..." >&2
        for old_pod in $old_pods
            echo "  删除Pod: $old_pod" >&2
            kubectl --context=$k8s_context delete pod $old_pod --grace-period=0 --force >/dev/null 2>&1
        end
    end

    # 生成随机字符串作为Pod名称的一部分
    set -l rand_str (date +%s%N | shasum | head -c 8)

    # 确保服务名称不为空
    set -l pod_name ""
    if test -z "$service_name" -o "$service_name" = service
        set pod_name "brow-proxy-$rand_str"
    else
        set pod_name "brow-$service_name-$rand_str"
    end

    # 将TTL转换为秒数
    set -l ttl_seconds (_brow_parse_duration $ttl)

    echo "创建代理Pod..." >&2

    # 创建临时YAML文件
    set -l tmp_yaml (mktemp)

    # 获取当前时间作为创建时间
    set -l created_time (date -u +"%Y-%m-%dT%H:%M:%SZ")

    # 构建Pod YAML
    echo "apiVersion: v1
kind: Pod
metadata:
  name: $pod_name
  labels:
    app: brow
    brow-config: $config_name
    brow-service: $service_name
  annotations:
    brow.created-at: \"$created_time\"
    brow.ttl: \"$ttl\"
    brow.config: \"$config_name\"
spec:
  activeDeadlineSeconds: $ttl_seconds
  containers:
  - name: socat
    image: alpine:latest
    command:
    - sh
    - -c
    - |
      apk add --no-cache socat
      socat TCP-LISTEN:$remote_port,fork TCP:$ip:$remote_port &
      # 等待信号或超时
      trap \"exit 0\" TERM INT
      sleep infinity
    ports:
    - containerPort: $remote_port
  restartPolicy: Never" >$tmp_yaml

    # 使用配置中的k8s context

    # 应用YAML创建Pod
    set -l apply_output (kubectl --context=$k8s_context apply -f $tmp_yaml 2>&1)
    set -l apply_status $status

    if test $apply_status -ne 0
        echo "错误: 创建Pod失败" >&2
        echo "kubectl输出: $apply_output" >&2
        rm $tmp_yaml
        return 1
    end

    # 删除临时YAML文件
    rm $tmp_yaml

    # 等待Pod就绪
    echo "等待代理Pod就绪..." >&2
    set -l wait_output (kubectl --context=$k8s_context wait --for=condition=Ready pod/$pod_name --timeout=60s 2>&1)
    set -l wait_status $status

    if test $wait_status -ne 0
        echo "错误: Pod未能在规定时间内就绪" >&2
        echo "kubectl输出: $wait_output" >&2

        # 获取Pod状态以便调试
        echo "获取Pod状态..." >&2
        kubectl --context=$k8s_context describe pod $pod_name >&2

        # 尝试删除Pod，但不要因为删除失败而中断
        echo "清理Pod..." >&2
        kubectl --context=$k8s_context delete pod $pod_name --grace-period=0 --force >/dev/null 2>&1

        return 1
    end

    echo "Pod '$pod_name' 已创建并就绪" >&2
    echo "配置: $config_name" >&2
    echo "Kubernetes上下文: $k8s_context" >&2
    echo "IP: $ip" >&2
    echo "远程端口: $remote_port" >&2
    echo "TTL: $ttl" >&2

    # 返回Pod名称
    echo "$pod_name"
    return 0
end

function _brow_pod_list
    # 列出配置中指定的上下文中的Pod
    echo "正在查询brow Pod..."

    # 获取配置中的上下文
    set -l config_file ~/.config/brow/config.json
    set -l contexts (jq -r '.[] | .k8s_context' $config_file | sort -u)

    # 如果没有配置，使用当前上下文
    if test -z "$contexts"
        set contexts (kubectl config current-context)
    end

    # 初始化计数器
    set -l total_pods 0

    echo (_brow_i18n_get "pod_list_title")
    echo

    # 定义列标题和宽度
    set -l headers (_brow_i18n_get "pod_name") (_brow_i18n_get "config") (_brow_i18n_get "service") (_brow_i18n_get "created_at") (_brow_i18n_get "ttl") (_brow_i18n_get "status") (_brow_i18n_get "context")
    set -l widths 30 15 15 15 15 15 15

    # 计算标题的可见宽度
    for i in (seq (count $headers))
        set -l header_width (string length --visible -- $headers[$i])
        if test $header_width -gt $widths[$i]
            set widths[$i] $header_width
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

    # 遍历配置中的上下文
    for ctx in $contexts
        # 获取当前上下文中的brow Pod
        set -l pods_json (kubectl --context=$ctx get pods -l app=brow --output=json 2>/dev/null)
        if test $status -ne 0
            continue
        end

        # 使用jq提取Pod的信息
        set -l pod_names (echo $pods_json | jq -r '.items[].metadata.name' 2>/dev/null)
        if test -z "$pod_names"
            continue
        end

        # 处理每个Pod
        for pod_name in $pod_names
            # 增加计数器
            set total_pods (math $total_pods + 1)

            # 提取Pod信息，使用已经获取的pods_json数据
            set -l pod_json (echo $pods_json | jq -r ".items[] | select(.metadata.name == \"$pod_name\")")

            # 提取Pod信息
            set -l config_name (echo $pod_json | jq -r '.metadata.annotations."brow.config" // "未知"')
            set -l service_name (echo $pod_json | jq -r '.metadata.labels."brow-service" // "未知"')
            set -l created_at (echo $pod_json | jq -r '.metadata.annotations."brow.created-at" // "未知"')
            set -l ttl (echo $pod_json | jq -r '.metadata.annotations."brow.ttl" // "未知"')
            set -l pod_status (echo $pod_json | jq -r '.status.phase')

            # 格式化创建时间
            if test "$created_at" != 未知
                # 将ISO时间转换为相对时间
                set -l now (date +%s)
                set -l created_time (_brow_parse_time "$created_at")

                if test $created_time -gt 0
                    set -l elapsed (math $now - $created_time)

                    if test $elapsed -lt 60
                        set created_at "$elapsed 秒前"
                    else if test $elapsed -lt 3600
                        set -l minutes (math $elapsed / 60)
                        set created_at "$minutes 分钟前"
                    else if test $elapsed -lt 86400
                        set -l hours (math $elapsed / 3600)
                        set created_at "$hours 小时前"
                    else
                        set -l days (math $elapsed / 86400)
                        set created_at "$days 天前"
                    end
                end
            end

            # 显示简化的上下文名称
            set -l short_ctx (echo $ctx | string replace -r '.*/' '')

            # 准备显示数据
            set -l display_data $pod_name $config_name $service_name $created_at $ttl $pod_status $short_ctx

            # 打印行
            echo -n ""
            _pad_to_width $pod_name $widths[1]
            echo -n " "
            _pad_to_width $config_name $widths[2]
            echo -n " "
            _pad_to_width $service_name $widths[3]
            echo -n " "
            _pad_to_width $created_at $widths[4]
            echo -n " "
            _pad_to_width $ttl $widths[5]
            echo -n " "
            _pad_to_width $pod_status $widths[6]
            echo -n " "
            _pad_to_width $short_ctx $widths[7]
            echo ""
        end
    end

    # 如果没有找到Pod，显示提示信息
    if test $total_pods -eq 0
        echo (_brow_i18n_get "no_pods_found")
    end
end

function _brow_pod_info --argument-names pod_id_or_config
    # 查看Pod详细信息
    # 参数可以是Pod ID或配置名称

    # 先检查是否是配置名称
    if _brow_config_exists $pod_id_or_config
        # 如果是配置名称，查找对应的Pod
        set -l config_name $pod_id_or_config
        set -l config_data (_brow_config_get $config_name)
        set -l k8s_context (echo $config_data | jq -r '.k8s_context')

        # 查找该配置的Pod
        set -l pod_json (kubectl --context=$k8s_context get pods -l app=brow,brow-config=$config_name -o json 2>/dev/null)
        set -l pod_names (echo $pod_json | jq -r '.items[].metadata.name' 2>/dev/null)

        if test -z "$pod_names"
            echo (_brow_i18n_format "error_pod_not_found" $config_name)
            return 1
        end

        # 如果有多个Pod，列出并询问用户选择
        if test (count $pod_names) -gt 1
            echo "找到多个配置 '$config_name' 的Pod:"
            for i in (seq (count $pod_names))
                echo "$i: $pod_names[$i]"
            end

            read -l -P "请选择要查看的Pod编号 [1-"(count $pod_names)"]: " choice

            if test -z "$choice" -o "$choice" -lt 1 -o "$choice" -gt (count $pod_names)
                echo (_brow_i18n_get "operation_cancelled")
                return 1
            end

            set pod_id $pod_names[$choice]
        else
            # 只有一个Pod，直接使用
            set pod_id $pod_names[1]
        end
    else
        # 如果不是配置名称，当作是Pod ID
        set pod_id $pod_id_or_config

        # 检查Pod是否存在
        # 使用当前上下文
        set -l k8s_context (kubectl config current-context)
        if not kubectl --context=$k8s_context get pod $pod_id >/dev/null 2>&1
            echo (_brow_i18n_format "error_pod_not_found" $pod_id)
            return 1
        end
    end

    # 获取Pod详细信息
    # 获取Pod所在的上下文
    set -l k8s_context ""
    if _brow_config_exists $pod_id_or_config
        set -l config_data (_brow_config_get $pod_id_or_config)
        set k8s_context (echo $config_data | jq -r '.k8s_context')
    end

    # 如果没有上下文，使用当前上下文
    if test -z "$k8s_context"
        set k8s_context (kubectl config current-context)
    end

    set -l pod_json (kubectl --context=$k8s_context get pod $pod_id -o json)

    # 提取信息
    set -l config_name (echo $pod_json | jq -r '.metadata.annotations."brow.config" // "未知"')
    set -l service_name (echo $pod_json | jq -r '.metadata.labels."brow-service" // "未知"')
    set -l created_at (echo $pod_json | jq -r '.metadata.annotations."brow.created-at" // "未知"')
    set -l ttl (echo $pod_json | jq -r '.metadata.annotations."brow.ttl" // "未知"')
    set -l pod_status (echo $pod_json | jq -r '.status.phase')
    set -l node (echo $pod_json | jq -r '.spec.nodeName // "未知"')
    set -l ip (echo $pod_json | jq -r '.status.podIP // "未知"')
    set -l container_status (echo $pod_json | jq -r '.status.containerStatuses[0].ready')
    set -l restart_count (echo $pod_json | jq -r '.status.containerStatuses[0].restartCount')

    # 计算剩余时间
    set -l remaining_time 未知
    if test "$created_at" != 未知 -a "$ttl" != 未知
        set -l now (date +%s)
        set -l created_time (_brow_parse_time "$created_at")
        set -l ttl_seconds (_brow_parse_duration $ttl)

        if test $created_time -gt 0 -a $ttl_seconds -gt 0
            set -l expiry_time (math $created_time + $ttl_seconds)
            set -l remaining (math $expiry_time - $now)

            if test $remaining -lt 0
                set remaining_time 已过期
            else if test $remaining -lt 60
                set remaining_time "$remaining 秒"
            else if test $remaining -lt 3600
                set -l minutes (math $remaining / 60)
                set remaining_time "$minutes 分钟"
            else if test $remaining -lt 86400
                set -l hours (math $remaining / 3600)
                set remaining_time "$hours 小时"
            else
                set -l days (math $remaining / 86400)
                set remaining_time "$days 天"
            end
        end
    end

    # 显示信息
    echo "Pod: $pod_id"
    echo "  配置: $config_name"
    echo "  服务: $service_name"
    echo "  创建时间: $created_at"
    echo "  TTL: $ttl"
    echo "  剩余时间: $remaining_time"
    echo "  状态: $pod_status"
    echo "  节点: $node"
    echo "  Pod IP: $ip"
    echo "  容器就绪: $container_status"
    echo "  重启次数: $restart_count"

    # 检查是否有活跃的端口转发
    set -l active_dir ~/.config/brow/active
    set -l forward_files (find $active_dir -name "forward-$pod_id-*.json" 2>/dev/null)

    if test -n "$forward_files"
        echo
        echo "活跃的端口转发:"

        for file in $forward_files
            set -l forward_id (basename $file .json | string replace "forward-$pod_id-" "")
            set -l forward_data (cat $file)
            set -l local_port (echo $forward_data | jq -r '.local_port')
            set -l remote_port (echo $forward_data | jq -r '.remote_port')
            set -l pid (echo $forward_data | jq -r '.pid')

            # 检查进程是否仍在运行
            if kill -0 $pid 2>/dev/null
                echo "  ID: $forward_id"
                echo "  本地端口: $local_port"
                echo "  远程端口: $remote_port"
                echo "  PID: $pid"
                echo
            else
                # 如果进程不存在，删除记录文件
                rm $file 2>/dev/null
            end
        end
    end
end

function _brow_pod_delete --argument-names pod_id_or_config
    # 手动删除Pod
    # 参数可以是Pod ID或配置名称

    # 先检查是否是配置名称
    if _brow_config_exists $pod_id_or_config
        # 如果是配置名称，查找对应的Pod
        set -l config_name $pod_id_or_config
        set -l config_data (_brow_config_get $config_name)
        set -l k8s_context (echo $config_data | jq -r '.k8s_context')

        # 查找该配置的Pod
        set -l pod_json (kubectl --context=$k8s_context get pods -l app=brow,brow-config=$config_name -o json 2>/dev/null)
        set -l pod_names (echo $pod_json | jq -r '.items[].metadata.name' 2>/dev/null)

        if test -z "$pod_names"
            echo (_brow_i18n_format "error_pod_not_found" $config_name)
            return 1
        end

        # 如果有多个Pod，列出并询问用户选择
        if test (count $pod_names) -gt 1
            echo "找到多个配置 '$config_name' 的Pod:"
            for i in (seq (count $pod_names))
                echo "$i: $pod_names[$i]"
            end

            read -l -P "请选择要删除的Pod编号 [1-"(count $pod_names)"]: " choice

            if test -z "$choice" -o "$choice" -lt 1 -o "$choice" -gt (count $pod_names)
                echo (_brow_i18n_get "operation_cancelled")
                return 1
            end

            set pod_id $pod_names[$choice]
        else
            # 只有一个Pod，直接使用
            set pod_id $pod_names[1]
        end
    else
        # 如果不是配置名称，当作是Pod ID
        set pod_id $pod_id_or_config

        # 检查Pod是否存在
        # 使用当前上下文
        set -l k8s_context (kubectl config current-context)
        if not kubectl --context=$k8s_context get pod $pod_id >/dev/null 2>&1
            echo (_brow_i18n_format "error_pod_not_found" $pod_id)
            return 1
        end
    end

    # 获取Pod所在的上下文
    set -l k8s_context ""
    if _brow_config_exists $pod_id_or_config
        set -l config_data (_brow_config_get $pod_id_or_config)
        set k8s_context (echo $config_data | jq -r '.k8s_context')
    end

    # 如果没有上下文，使用当前上下文
    if test -z "$k8s_context"
        set k8s_context (kubectl config current-context)
    end

    # 获取Pod信息
    set -l pod_json (kubectl --context=$k8s_context get pod $pod_id -o json 2>/dev/null)
    if test $status -ne 0
        echo (_brow_i18n_format "error_pod_not_found" $pod_id)
        return 1
    end

    set -l config_name (echo $pod_json | jq -r '.metadata.annotations."brow.config" // "未知"')

    # 检查是否有活跃的端口转发
    set -l active_dir ~/.config/brow/active
    set -l forward_files (find $active_dir -name "forward-$pod_id-*.json" 2>/dev/null)

    if test -n "$forward_files"
        echo "警告: Pod '$pod_id' 有活跃的端口转发:"

        for file in $forward_files
            set -l forward_id (basename $file .json | string replace "forward-$pod_id-" "")
            set -l forward_data (cat $file)
            set -l local_port (echo $forward_data | jq -r '.local_port')
            set -l pid (echo $forward_data | jq -r '.pid')

            echo "  ID: $forward_id, 本地端口: $local_port, PID: $pid"
        end

        read -l -P "是否停止所有端口转发并删除Pod? [y/N]: " confirm

        if test "$confirm" != y -a "$confirm" != Y
            echo (_brow_i18n_get "operation_cancelled")
            return 1
        end

        # 停止所有端口转发
        for file in $forward_files
            set -l forward_id (basename $file .json | string replace "forward-$pod_id-" "")
            _brow_forward_stop $forward_id
        end
    end

    # 使用前面获取的上下文

    # 删除Pod
    echo (_brow_i18n_format "pod_deleting" $pod_id)
    kubectl --context=$k8s_context delete pod $pod_id --grace-period=0 --force >/dev/null

    if test $status -eq 0
        echo (_brow_i18n_format "pod_deleted" $pod_id)
    else
        echo (_brow_i18n_format "pod_delete_failed" $pod_id)
        return 1
    end
end

function _brow_pod_cleanup
    # 清理过期的Pod

    echo (_brow_i18n_get "cleaning_up")

    # 获取配置中的上下文
    set -l config_file ~/.config/brow/config.json
    set -l contexts (jq -r '.[] | .k8s_context' $config_file | sort -u)

    # 如果没有配置，使用当前上下文
    if test -z "$contexts"
        set contexts (kubectl config current-context)
    end

    set -l total_expired_pods 0
    set -l now (date +%s)

    # 遍历配置中的上下文
    for k8s_context in $contexts
        # 获取当前上下文中的brow Pod
        set -l pods_json (kubectl --context=$k8s_context get pods -l app=brow --output=json 2>/dev/null)
        if test $status -ne 0
            continue
        end

        # 使用jq提取Pod的信息
        set -l pod_names (echo $pods_json | jq -r '.items[].metadata.name' 2>/dev/null)
        if test -z "$pod_names"
            continue
        end

        set -l context_expired_pods 0

        # 处理每个Pod
        for pod_name in $pod_names
            # 提取Pod信息，使用已经获取的pods_json数据
            set -l pod_json (echo $pods_json | jq -r ".items[] | select(.metadata.name == \"$pod_name\")")

            # 提取Pod信息
            set -l created_at (echo $pod_json | jq -r '.metadata.annotations."brow.created-at" // ""')
            set -l ttl (echo $pod_json | jq -r '.metadata.annotations."brow.ttl" // ""')
            set -l config_name (echo $pod_json | jq -r '.metadata.annotations."brow.config" // "未知"')
            set -l pod_status (echo $pod_json | jq -r '.status.phase')

            # 检查Pod是否应该被清理
            set -l should_cleanup false

            # 情况1: Pod处于错误或失败状态
            if test "$pod_status" = Failed -o "$pod_status" = Error
                set should_cleanup true
            end

            # 情况2: Pod已过期
            if test -n "$created_at" -a -n "$ttl"
                set -l created_time (_brow_parse_time "$created_at")
                set -l ttl_seconds (_brow_parse_duration $ttl)

                if test $created_time -gt 0 -a $ttl_seconds -gt 0
                    set -l expiry_time (math $created_time + $ttl_seconds)

                    if test $now -gt $expiry_time
                        set should_cleanup true
                    end
                end
            end

            # 如果需要清理，删除Pod
            if test "$should_cleanup" = true
                echo (_brow_i18n_format "pod_deleting" $pod_name)
                kubectl --context=$k8s_context delete pod $pod_name --grace-period=0 --force >/dev/null 2>&1
                set context_expired_pods (math $context_expired_pods + 1)

                # 同时清理相关的转发记录
                set -l active_dir ~/.config/brow/active
                set -l forward_files (find $active_dir -name "forward-$pod_name-*.json" 2>/dev/null)

                for file in $forward_files
                    set -l filename (basename $file)
                    set -l parts (string split ".json" $filename)
                    set -l name_parts (string split "-" $parts[1])
                    set -l forward_id $name_parts[-1]
                    echo "  清理转发记录: $forward_id"
                    rm $file 2>/dev/null
                end
            end
        end

        set total_expired_pods (math $total_expired_pods + $context_expired_pods)
    end

    if test $total_expired_pods -eq 0
        echo 没有找到需要清理的Pod
    else
        echo "已删除 $total_expired_pods 个Pod"
    end
end

# 辅助函数：基于可见宽度的格式化
function _pad_to_width --argument-names str width fill
    # 默认填充字符为空格
    if test -z "$fill"
        set fill " "
    end

    # 计算显示宽度
    set -l str_width (string length --visible -- "$str")
    set -l padding (math "$width - $str_width")

    echo -n "$str"
    if test $padding -gt 0
        echo -n (string repeat -n $padding "$fill")
    end
end

function _brow_parse_duration --argument-names duration
    # 将持续时间字符串转换为秒数
    # 支持的格式: 30s, 5m, 2h, 1d

    # 默认为30分钟
    if test -z "$duration"
        echo 1800
        return 0
    end

    # 提取数字和单位
    set -l number (echo $duration | grep -o '[0-9]\+')
    set -l unit (echo $duration | grep -o '[smhd]$')

    # 如果没有提取到数字，返回默认值
    if test -z "$number"
        echo 1800
        return 0
    end

    # 根据单位转换为秒数
    switch $unit
        case s
            echo $number
        case m
            echo (math $number \* 60)
        case h
            echo (math $number \* 3600)
        case d
            echo (math $number \* 86400)
        case '*'
            # 如果没有单位或单位不识别，假设是秒
            echo $number
    end
end
