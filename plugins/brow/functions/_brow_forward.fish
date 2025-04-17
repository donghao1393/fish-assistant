function _brow_forward_start --argument-names pod_id local_port k8s_context
    # 开始端口转发
    # 用法: _brow_forward_start <pod-id> [local_port] <k8s_context>

    # 处理可能的制表符和描述信息
    # 如果输入包含制表符，只取第一部分（实际的Pod ID）
    set -l clean_pod_id (string split "\t" $pod_id)[1]

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

    # 检查Pod是否存在
    set -l pod_check_output (kubectl --context=$k8s_context get pod $clean_pod_id 2>&1)
    set -l pod_check_status $status

    if test $pod_check_status -ne 0
        echo "错误: 在上下文 '$k8s_context' 中找不到Pod '$clean_pod_id'"

        # 尝试在指定的上下文中查找匹配的Pod
        set -l matching_pods (kubectl --context=$k8s_context get pods --selector=app=brow -o name 2>/dev/null | string replace "pod/" "")

        if test -n "$matching_pods"
            echo "在上下文 '$k8s_context' 中找到以下相关Pod:"
            for pod in $matching_pods
                echo "  $pod"
            end
            echo "请使用以下命令连接其中一个:"
            echo "brow forward start <pod-id> $local_port $k8s_context"
        else
            echo "建议先创建Pod，然后再连接:"
            echo "brow pod create <配置名称>"
            echo "brow connect <配置名称>"
        end

        return 1
    end

    # 获取Pod信息
    set -l pod_json (kubectl --context=$k8s_context get pod $clean_pod_id -o json)
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
    set -l forward_file "$active_dir/forward-$clean_pod_id-$forward_id.json"

    # 启动端口转发进程
    # 将错误输出重定向到临时文件
    set -l error_file (mktemp)
    kubectl --context=$k8s_context port-forward pod/$clean_pod_id $local_port:$remote_port >$error_file 2>&1 &

    # 获取进程ID
    set -l pid $last_pid

    # 等待一会儿，确保端口转发已启动
    sleep 1

    # 检查进程是否仍在运行
    if not kill -0 $pid 2>/dev/null
        echo "错误: 端口转发启动失败"

        # 显示错误详情
        if test -f $error_file
            echo "错误详情:"
            cat $error_file
            rm $error_file
        end

        # 检查端口是否被占用
        echo "检查端口 $local_port 是否被占用..."
        if lsof -i :$local_port >/dev/null 2>&1
            echo "端口 $local_port 已被占用。请尝试其他端口。"
        end

        return 1
    end

    # 删除临时文件
    rm $error_file 2>/dev/null

    # 保存转发信息
    set -l forward_data (jo pod_id=$clean_pod_id local_port=$local_port remote_port=$remote_port pid=$pid config=$config_name)
    echo $forward_data >$forward_file

    echo "端口转发已启动: localhost:$local_port -> $clean_pod_id:$remote_port (ID: $forward_id)"

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

    # 处理每个转发记录
    for file in $forward_files
        # 从文件名中提取信息
        set -l filename (basename $file)

        # 文件名格式应该是 forward-<pod_id>-<forward_id>.json
        # 例如：forward-brow-proxy-a95c4f8e-0df206e8.json

        # 从文件名中提取信息
        # 文件名格式例如：forward-brow-proxy-a95c4f8e-0df206e8.json

        # 先移除.json后缀
        set -l name_without_ext (string replace ".json" "" $filename)

        # 分割成数组，例如 [forward, brow, proxy, a95c4f8e, 0df206e8]
        set -l parts (string split "-" $name_without_ext)

        # 获取最后一个元素作为forward_id
        set -l forward_id $parts[-1]

        # 移除第一个元素(forward)和最后一个元素(forward_id)
        set -l pod_parts $parts[2..-2]

        # 将剩下的元素用短横线连接起来作为pod_id
        set -l pod_id_from_filename (string join "-" $pod_parts)

        # 读取转发数据
        set -l forward_data (cat $file)
        set -l pod_id (echo $forward_data | jq -r '.pod_id // "unknown"')
        set -l local_port (echo $forward_data | jq -r '.local_port')
        set -l remote_port (echo $forward_data | jq -r '.remote_port')
        set -l pid (echo $forward_data | jq -r '.pid')
        set -l config (echo $forward_data | jq -r '.config // "unknown"')

        # 如果文件内容中的pod_id与文件名中的不一致，使用文件名中的
        if test "$pod_id" = unknown -o "$pod_id" = brow
            set pod_id $pod_id_from_filename
        end

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

    # 处理可能的制表符和描述信息
    # 如果输入包含制表符，只取第一部分（实际的ID）
    set -l clean_id (string split "\t" $forward_id)[1]

    set -l active_dir ~/.config/brow/active
    if not test -d $active_dir
        mkdir -p $active_dir
    end

    # 查找匹配的转发记录文件
    set -l forward_files (find $active_dir -name "*-$clean_id.json" 2>/dev/null)

    if test -z "$forward_files"
        echo "错误: 未找到ID为 $clean_id 的端口转发"
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
