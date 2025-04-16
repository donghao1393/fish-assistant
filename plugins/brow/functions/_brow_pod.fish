function _brow_pod_create --argument-names config_name
    # 根据配置创建Pod

    if not _brow_config_exists $config_name
        echo "错误: 配置 '$config_name' 不存在"
        return 1
    end

    # 获取配置数据
    set -l config_data (_brow_config_get $config_name)
    set -l k8s_context (echo $config_data | jq -r '.k8s_context')
    set -l ip (echo $config_data | jq -r '.ip')
    set -l remote_port (echo $config_data | jq -r '.remote_port')
    set -l service_name (echo $config_data | jq -r '.service_name')
    set -l ttl (echo $config_data | jq -r '.ttl')

    # 生成随机字符串作为Pod名称的一部分
    set -l rand_str (date +%s%N | shasum | head -c 8)
    set -l pod_name "brow-$service_name-$rand_str"

    # 将TTL转换为秒数
    set -l ttl_seconds (_brow_parse_duration $ttl)

    echo "创建代理Pod..."

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
    app: brow-$config_name
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
    kubectl --context=$k8s_context apply -f $tmp_yaml >/dev/null

    # 删除临时YAML文件
    rm $tmp_yaml

    # 等待Pod就绪
    echo "等待代理Pod就绪..."
    kubectl --context=$k8s_context wait --for=condition=Ready pod/$pod_name --timeout=60s >/dev/null

    if test $status -ne 0
        echo "错误: Pod未能在规定时间内就绪"
        kubectl --context=$k8s_context delete pod $pod_name >/dev/null 2>&1
        return 1
    end

    echo "Pod '$pod_name' 已创建并就绪"
    echo "配置: $config_name"
    echo "Kubernetes上下文: $k8s_context"
    echo "IP: $ip"
    echo "远程端口: $remote_port"
    echo "TTL: $ttl"

    # 返回Pod名称
    echo $pod_name
    return 0
end

function _brow_pod_list
    # 列出当前所有Pod

    # 检查是否有brow Pod
    set -l pod_count (kubectl get pods 2>/dev/null | grep "brow-" | wc -l)
    set -l pod_count (string trim $pod_count)

    if test "$pod_count" = "0"
        echo "没有找到活跃的brow Pod"
        return 0
    end

    echo "活跃的brow Pod:"
    echo

    # 打印表头
    printf "%-30s %-15s %-15s %-15s %-15s %-15s\n" "Pod名称" "配置" "服务" "创建时间" "TTL" "状态"
    printf "%-30s %-15s %-15s %-15s %-15s %-15s\n" "------------------------------" "---------------" "---------------" "---------------" "---------------" "---------------"

    # 获取所有Pod的JSON数据
    set -l pods_json (kubectl get pods --output=json)

    # 使用jq提取所有brow Pod的信息
    set -l pod_names (echo $pods_json | jq -r '.items[].metadata.name' | grep "^brow-")

    # 处理每个Pod
    for pod_name in $pod_names
        # 获取单个Pod的详细信息
        set -l pod_json (kubectl get pod $pod_name -o json)

        # 提取Pod信息
        set -l config_name (echo $pod_json | jq -r '.metadata.annotations."brow.config" // "未知"')
        set -l service_name (echo $pod_json | jq -r '.metadata.labels."brow-service" // "未知"')
        set -l created_at (echo $pod_json | jq -r '.metadata.annotations."brow.created-at" // "未知"')
        set -l ttl (echo $pod_json | jq -r '.metadata.annotations."brow.ttl" // "未知"')
        set -l pod_status (echo $pod_json | jq -r '.status.phase')

        # 格式化创建时间
        if test "$created_at" != "未知"
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

        printf "%-30s %-15s %-15s %-15s %-15s %-15s\n" $pod_name $config_name $service_name $created_at $ttl $pod_status
    end
end

function _brow_pod_info --argument-names pod_id
    # 查看Pod详细信息

    # 检查Pod是否存在
    if not kubectl get pod $pod_id >/dev/null 2>&1
        echo "错误: Pod '$pod_id' 不存在"
        return 1
    end

    # 获取Pod详细信息
    set -l pod_json (kubectl get pod $pod_id -o json)

    # 提取信息
    set -l config_name (echo $pod_json | jq -r '.metadata.annotations."brow.config" // "未知"')
    set -l service_name (echo $pod_json | jq -r '.metadata.labels."brow-service" // "未知"')
    set -l created_at (echo $pod_json | jq -r '.metadata.annotations."brow.created-at" // "未知"')
    set -l ttl (echo $pod_json | jq -r '.metadata.annotations."brow.ttl" // "未知"')
    set -l status (echo $pod_json | jq -r '.status.phase')
    set -l node (echo $pod_json | jq -r '.spec.nodeName // "未知"')
    set -l ip (echo $pod_json | jq -r '.status.podIP // "未知"')
    set -l container_status (echo $pod_json | jq -r '.status.containerStatuses[0].ready')
    set -l restart_count (echo $pod_json | jq -r '.status.containerStatuses[0].restartCount')

    # 计算剩余时间
    set -l remaining_time "未知"
    if test "$created_at" != "未知" -a "$ttl" != "未知"
        set -l now (date +%s)
        set -l created_time (_brow_parse_time "$created_at")
        set -l ttl_seconds (_brow_parse_duration $ttl)

        if test $created_time -gt 0 -a $ttl_seconds -gt 0
            set -l expiry_time (math $created_time + $ttl_seconds)
            set -l remaining (math $expiry_time - $now)

            if test $remaining -lt 0
                set remaining_time "已过期"
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
    echo "  状态: $status"
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

function _brow_pod_delete --argument-names pod_id
    # 手动删除Pod

    # 检查Pod是否存在
    if not kubectl get pod $pod_id >/dev/null 2>&1
        echo "错误: Pod '$pod_id' 不存在"
        return 1
    end

    # 获取Pod信息
    set -l pod_json (kubectl get pod $pod_id -o json)
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

        echo -n "是否停止所有端口转发并删除Pod? [y/N]: "
        read -l confirm

        if test "$confirm" != "y" -a "$confirm" != "Y"
            echo "操作已取消"
            return 1
        end

        # 停止所有端口转发
        for file in $forward_files
            set -l forward_id (basename $file .json | string replace "forward-$pod_id-" "")
            _brow_forward_stop $forward_id
        end
    end

    # 获取Pod所在的上下文
    set -l k8s_context "" # 默认为空
    if test "$config_name" != "未知"
        set -l config_data (_brow_config_get $config_name)
        if test $status -eq 0
            set k8s_context (echo $config_data | jq -r '.k8s_context')
        end
    end

    # 如果没有上下文，使用当前上下文
    if test -z "$k8s_context"
        set k8s_context (kubectl config current-context)
    end

    # 删除Pod
    echo "正在删除Pod '$pod_id'..."
    kubectl --context=$k8s_context delete pod $pod_id >/dev/null

    if test $status -eq 0
        echo "Pod '$pod_id' 已删除"
    else
        echo "错误: 删除Pod '$pod_id' 失败"
        return 1
    end
end

function _brow_pod_cleanup
    # 清理过期的Pod

    echo "正在检查过期的Pod..."

    # 获取所有brow Pod的名称
    set -l pods_json (kubectl get pods --output=json)
    set -l pod_names (echo $pods_json | jq -r '.items[].metadata.name' | grep "^brow-")

    if test -z "$pod_names"
        echo "没有找到brow Pod"
        return 0
    end

    set -l now (date +%s)
    set -l expired_pods 0

    # 处理每个Pod
    for pod_name in $pod_names
        # 获取单个Pod的详细信息
        set -l pod_json (kubectl get pod $pod_name -o json)

        # 提取Pod信息
        set -l created_at (echo $pod_json | jq -r '.metadata.annotations."brow.created-at" // ""')
        set -l ttl (echo $pod_json | jq -r '.metadata.annotations."brow.ttl" // ""')
        set -l config_name (echo $pod_json | jq -r '.metadata.annotations."brow.config" // "未知"')
        set -l pod_status (echo $pod_json | jq -r '.status.phase')

        # 检查Pod是否应该被清理
        set -l should_cleanup false

        # 情况1: Pod处于错误或失败状态
        if test "$pod_status" = "Failed" -o "$pod_status" = "Error"
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
        if test "$should_cleanup" = "true"
            # 获取上下文
            set -l k8s_context "" # 默认为空
            if test "$config_name" != "未知"
                set -l config_data (_brow_config_get $config_name 2>/dev/null)
                if test $status -eq 0
                    set k8s_context (echo $config_data | jq -r '.k8s_context')
                end
            end

            # 如果没有上下文，使用当前上下文
            if test -z "$k8s_context"
                set k8s_context (kubectl config current-context)
            end

            echo "删除Pod: $pod_name"
            kubectl --context=$k8s_context delete pod $pod_name >/dev/null 2>&1
            set expired_pods (math $expired_pods + 1)
        end
    end

    if test $expired_pods -eq 0
        echo "没有找到需要清理的Pod"
    else
        echo "已删除 $expired_pods 个Pod"
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
