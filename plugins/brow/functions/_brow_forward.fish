function _brow_forward_start --argument-names pod_id local_port k8s_context
    # 开始端口转发
    # 用法: _brow_forward_start <pod-id> [local_port] <k8s_context>

    # 检查上下文参数
    if test -z "$k8s_context"
        # 如果没有指定上下文，尝试从$argv中获取
        if test (count $argv) -ge 3
            set k8s_context $argv[3]
        end
    end

    # 如果没有指定上下文，返回错误
    if test -z "$k8s_context"
        echo "错误: 未指定Kubernetes上下文"
        echo "请使用 'brow forward start <pod-id> <local_port> <k8s_context>' 命令指定上下文"
        return 1
    end

    echo "使用Kubernetes上下文: $k8s_context"

    # 检查Pod是否存在
    set -l pod_check_output (kubectl --context=$k8s_context get pod $pod_id 2>&1)
    set -l pod_check_status $status

    if test $pod_check_status -ne 0
        echo "错误: 在上下文 '$k8s_context' 中找不到Pod '$pod_id'"
        echo "kubectl输出: $pod_check_output"

        # 尝试列出所有可用的上下文
        echo "可用的Kubernetes上下文:"
        kubectl config get-contexts --output=name

        # 尝试在所有上下文中查找Pod
        echo "尝试在所有上下文中查找Pod '$pod_id'..."
        for ctx in (kubectl config get-contexts --output=name)
            echo -n "检查上下文 '$ctx'... "
            if kubectl --context=$ctx get pod $pod_id >/dev/null 2>&1
                echo "找到了!"
                echo "建议使用以下命令:"
                echo "brow forward start $pod_id $local_port $ctx"
            else
                echo 未找到
            end
        end

        return 1
    end

    # 获取Pod信息
    set -l pod_json (kubectl --context=$k8s_context get pod $pod_id -o json)
    set -l config_name (echo $pod_json | jq -r '.metadata.annotations."brow.config" // "未知"')
    set -l remote_port (echo $pod_json | jq -r '.spec.containers[0].ports[0].containerPort // "5432"')

    # 如果未指定本地端口，尝试从配置获取
    if test -z "$local_port"
        if test "$config_name" != 未知
            set -l config_data (_brow_config_get $config_name)
            if test $status -eq 0
                set local_port (echo $config_data | jq -r '.local_port')
            else
                # 默认使用与远程端口相同的本地端口
                set local_port $remote_port
            end
        else
            # 默认使用与远程端口相同的本地端口
            set local_port $remote_port
        end
    end

    # 我们已经在函数开始时设置了k8s_context，不需要再次设置

    # 生成唯一的转发ID
    set -l forward_id (date +%s%N | shasum | head -c 8)

    # 创建活跃转发记录目录
    set -l active_dir ~/.config/brow/active
    if not test -d $active_dir
        mkdir -p $active_dir
    end

    # 转发记录文件
    set -l forward_file "$active_dir/forward-$pod_id-$forward_id.json"

    echo "开始端口转发: localhost:$local_port -> $pod_id:$remote_port"

    # 启动端口转发进程
    kubectl --context=$k8s_context port-forward pod/$pod_id $local_port:$remote_port >/dev/null 2>&1 &

    # 获取进程ID
    set -l pid $last_pid

    # 等待一会儿，确保端口转发已启动
    sleep 1

    # 检查进程是否仍在运行
    if not kill -0 $pid 2>/dev/null
        echo "错误: 端口转发启动失败"
        return 1
    end

    # 保存转发信息
    set -l forward_data (jo pod_id=$pod_id local_port=$local_port remote_port=$remote_port pid=$pid config=$config_name)
    echo $forward_data >$forward_file

    echo 端口转发已启动
    echo "  ID: $forward_id"
    echo "  本地端口: $local_port"
    echo "  远程端口: $remote_port"
    echo "  PID: $pid"
    echo
    echo "连接信息："
    echo "  主机: localhost"
    echo "  端口: $local_port"
    echo
    echo "使用 'brow forward stop $forward_id' 停止转发"

    # 返回转发ID
    echo $forward_id
end

function _brow_forward_list
    # 列出所有端口转发，包括活跃和非活跃的

    set -l active_dir ~/.config/brow/active
    if not test -d $active_dir
        mkdir -p $active_dir
    end

    # 查找所有转发记录文件
    set -l forward_files (find $active_dir -name "forward-*.json" 2>/dev/null)

    if test -z "$forward_files"
        echo 没有端口转发记录
        return 0
    end

    echo 端口转发列表:
    echo

    # 打印表头
    printf "%-10s %-30s %-15s %-15s %-10s %-15s %-10s\n" ID Pod 本地端口 远程端口 PID 配置 状态
    printf "%-10s %-30s %-15s %-15s %-10s %-15s %-10s\n" ---------- ------------------------------ --------------- --------------- ---------- --------------- ----------

    # 处理每个转发记录
    for file in $forward_files
        set -l filename (basename $file)
        set -l parts (string split "-" $filename)
        set -l forward_id (string replace ".json" "" $parts[-1])

        # 读取转发数据
        set -l forward_data (cat $file)
        set -l pod_id (echo $forward_data | jq -r '.pod_id // "unknown"')
        set -l local_port (echo $forward_data | jq -r '.local_port')
        set -l remote_port (echo $forward_data | jq -r '.remote_port')
        set -l pid (echo $forward_data | jq -r '.pid')
        set -l config (echo $forward_data | jq -r '.config // "unknown"')

        # 检查进程是否仍在运行
        set -l forward_status 已停止
        set -l status_color red
        if kill -0 $pid 2>/dev/null
            set forward_status 活跃
            set status_color green
        end

        # 使用颜色输出状态
        printf "%-10s %-30s %-15s %-15s %-10s %-15s " $forward_id $pod_id $local_port $remote_port $pid $config
        set_color $status_color
        echo $forward_status
        set_color normal
    end
end

function _brow_forward_stop --argument-names forward_id
    # 停止特定的转发

    set -l active_dir ~/.config/brow/active
    if not test -d $active_dir
        mkdir -p $active_dir
    end

    # 查找匹配的转发记录文件
    set -l forward_files (find $active_dir -name "*-$forward_id.json" 2>/dev/null)

    if test -z "$forward_files"
        echo "错误: 未找到ID为 $forward_id 的端口转发"
        return 1
    end

    for file in $forward_files
        # 读取转发数据
        set -l forward_data (cat $file)
        set -l pod_id (echo $forward_data | jq -r '.pod_id')
        set -l local_port (echo $forward_data | jq -r '.local_port')
        set -l remote_port (echo $forward_data | jq -r '.remote_port')
        set -l pid (echo $forward_data | jq -r '.pid')

        echo "停止端口转发: localhost:$local_port -> $pod_id:$remote_port (PID: $pid)"

        # 终止进程
        kill $pid 2>/dev/null

        # 删除记录文件
        rm $file

        echo 端口转发已停止
    end
end
