function _brow_forward_start --argument-names config_name local_port
    # 开始端口转发
    # 用法: _brow_forward_start <配置名称> [local_port]

    # 处理可能的制表符和描述信息
    # 如果输入包含制表符，只取第一部分（实际的配置名称）
    set -l clean_config_name (string split "\t" $config_name)[1]

    # 检查配置是否存在
    if not _brow_config_exists $clean_config_name
        echo "错误: 配置 '$clean_config_name' 不存在"
        echo "请使用 'brow config list' 查看可用的配置"
        return 1
    end

    # 获取配置数据
    set -l config_data (_brow_config_get $clean_config_name)
    set -l k8s_context (echo $config_data | jq -r '.k8s_context')
    set -l remote_port (echo $config_data | jq -r '.remote_port')

    # 如果未指定本地端口，使用配置中的端口
    if test -z "$local_port"
        set local_port (echo $config_data | jq -r '.local_port')
    end

    # 检查是否已有该配置的转发
    set -l active_dir ~/.config/brow/active
    if not test -d $active_dir
        mkdir -p $active_dir
    end

    # 查找该配置的转发记录
    set -l existing_forwards (find $active_dir -name "forward-$clean_config_name-*.json" 2>/dev/null)

    # 如果已经有转发，检查是否仍然有效
    for file in $existing_forwards
        set -l forward_data (cat $file)
        set -l pid (echo $forward_data | jq -r '.pid')

        # 检查进程是否仍在运行
        if kill -0 $pid 2>/dev/null
            # 提取转发ID
            set -l forward_id (basename $file | string replace -r "forward-$clean_config_name-" "" | string replace ".json" "")
            set -l existing_local_port (echo $forward_data | jq -r '.local_port')

            echo "配置 '$clean_config_name' 已有活跃的转发 (ID: $forward_id, 端口: $existing_local_port)"
            echo "请先使用 'brow forward stop $forward_id' 停止现有转发"
            return 1
        else
            # 如果进程不存在，删除记录文件
            rm $file 2>/dev/null
        end
    end

    # 获取或创建Pod
    echo "获取配置 '$clean_config_name' 的Pod..." >&2

    # 使用临时文件来捕获_brow_pod_create函数的输出
    set -l pod_output_file (mktemp)
    _brow_pod_create $clean_config_name >$pod_output_file 2>&1
    set -l pod_status $status

    if test $pod_status -ne 0
        echo "错误: 无法获取或创建Pod" >&2
        cat $pod_output_file >&2
        rm $pod_output_file
        return 1
    end

    # 从文件中读取Pod名称
    set -l pod_id (cat $pod_output_file)
    rm $pod_output_file
    echo "获取到Pod名称: $pod_id" >&2

    # 生成唯一的转发ID
    set -l forward_id (date +%s%N | shasum | head -c 8)

    # 创建活跃转发记录目录
    set -l active_dir ~/.config/brow/active
    if not test -d $active_dir
        mkdir -p $active_dir
    end

    # 转发记录文件 - 使用配置名称而非Pod ID
    set -l forward_file "$active_dir/forward-$clean_config_name-$forward_id.json"

    # 启动端口转发进程
    # 将错误输出重定向到临时文件
    set -l error_file (mktemp)
    kubectl --context=$k8s_context port-forward pod/$pod_id $local_port:$remote_port >$error_file 2>&1 &

    # 获取进程ID
    set -l pid $last_pid

    # 等待一会儿，确保端口转发已启动
    sleep 1

    # 检查进程是否仍在运行
    if not kill -0 $pid 2>/dev/null
        echo "错误: 端口转发启动失败" >&2

        # 显示错误详情
        if test -f $error_file
            echo "错误详情:" >&2
            cat $error_file >&2
            rm $error_file
        end

        # 检查端口是否被占用
        echo "检查端口 $local_port 是否被占用..." >&2
        if lsof -i :$local_port >/dev/null 2>&1
            echo "端口 $local_port 已被占用。请尝试其他端口。" >&2
        end

        return 1
    end

    # 删除临时文件
    rm $error_file 2>/dev/null

    # 保存转发信息 - 使用配置名称作为主要标识
    set -l forward_data (jo config=$clean_config_name pod_id=$pod_id local_port=$local_port remote_port=$remote_port pid=$pid)
    echo $forward_data >$forward_file

    echo "端口转发已启动: localhost:$local_port -> $pod_id:$remote_port (ID: $forward_id)" >&2

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
    printf "%-10s %-15s %-15s %-15s %-10s %-15s\n" ID 配置 本地端口 远程端口 PID 状态

    # 处理每个转发记录
    for file in $forward_files
        # 从文件名中提取信息
        set -l filename (basename $file)

        # 文件名格式现在是 forward-<config_name>-<forward_id>.json
        # 例如：forward-legacy-prod-0df206e8.json

        # 先移除.json后缀
        set -l name_without_ext (string replace ".json" "" $filename)

        # 分割成数组，例如 [forward, legacy, prod, 0df206e8]
        set -l parts (string split "-" $name_without_ext)

        # 获取最后一个元素作为forward_id
        set -l forward_id $parts[-1]

        # 移除第一个元素(forward)和最后一个元素(forward_id)
        set -l config_parts $parts[2..-2]

        # 将剩下的元素用短横线连接起来作为config_name
        set -l config_from_filename (string join "-" $config_parts)

        # 读取转发数据
        set -l forward_data (cat $file)
        set -l config_name (echo $forward_data | jq -r '.config // "unknown"')
        set -l pod_id (echo $forward_data | jq -r '.pod_id // "unknown"')
        set -l local_port (echo $forward_data | jq -r '.local_port')
        set -l remote_port (echo $forward_data | jq -r '.remote_port')
        set -l pid (echo $forward_data | jq -r '.pid')

        # 如果文件内容中的config_name与文件名中的不一致，使用文件名中的
        if test "$config_name" = unknown
            set config_name $config_from_filename
        end

        # 检查进程是否仍在运行
        set -l forward_status 已停止
        set -l status_color red
        if kill -0 $pid 2>/dev/null
            set forward_status 活跃
            set status_color green
        else
            # 如果进程不存在，删除记录文件
            rm $file 2>/dev/null
            continue
        end

        # 使用颜色输出状态
        printf "%-10s %-15s %-15s %-15s %-10s " $forward_id $config_name $local_port $remote_port $pid
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
        # 如果没有找到转发ID，尝试将输入解释为配置名称
        if _brow_config_exists $clean_id
            # 如果是配置名称，查找该配置的所有转发
            set forward_files (find $active_dir -name "forward-$clean_id-*.json" 2>/dev/null)

            if test -z "$forward_files"
                echo "错误: 配置 '$clean_id' 没有活跃的端口转发"
                return 1
            end
        else
            echo "错误: 未找到ID为 '$clean_id' 的端口转发"
            return 1
        end
    end

    for file in $forward_files
        # 读取转发数据
        set -l forward_data (cat $file)
        set -l config_name (echo $forward_data | jq -r '.config // "unknown"')
        set -l pod_id (echo $forward_data | jq -r '.pod_id // "unknown"')
        set -l local_port (echo $forward_data | jq -r '.local_port')
        set -l remote_port (echo $forward_data | jq -r '.remote_port')
        set -l pid (echo $forward_data | jq -r '.pid')

        # 检查进程是否仍在运行
        if kill -0 $pid 2>/dev/null
            echo "停止端口转发: localhost:$local_port -> $pod_id:$remote_port (PID: $pid)"
            # 终止进程
            kill $pid 2>/dev/null
            echo 端口转发已停止
        else
            echo "转发进程已经不存在，清理记录"
        end

        # 删除记录文件
        rm $file
    end
end
