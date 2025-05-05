function _brow_forward_start --argument-names config_name local_port
    # 开始端口转发
    # 用法: _brow_forward_start <配置名称> [local_port]
    # 注意: 低序号端口(0-1023)会自动使用sudo

    # 处理可能的制表符和描述信息
    # 如果输入包含制表符，只取第一部分（实际的配置名称）
    set -l clean_config_name (string split "\t" $config_name)[1]

    # 检查配置是否存在
    if not _brow_config_exists $clean_config_name
        echo (_brow_i18n_format "error_config_not_found" $clean_config_name)
        echo (_brow_i18n_get "use_config_list")
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

            echo (_brow_i18n_format "config_has_active_forward" $clean_config_name $forward_id $existing_local_port)
            echo (_brow_i18n_format "please_stop_forward_first" $forward_id)
            return 1
        else
            # 如果进程不存在，删除记录文件
            rm $file 2>/dev/null
        end
    end

    # 获取或创建Pod
    echo (_brow_i18n_format "getting_pod_for_config" $clean_config_name) >&2

    # 直接调用_brow_pod_create函数并捕获其输出
    # 使用command substitution来执行函数并获取其输出
    set -l pod_id (_brow_pod_create $clean_config_name)
    set -l pod_status $status

    if test $pod_status -ne 0
        echo (_brow_i18n_get "error_getting_pod") >&2
        return 1
    end

    # 确保我们有一个有效的Pod ID
    if test -z "$pod_id"
        echo (_brow_i18n_get "error_empty_pod_id") >&2
        return 1
    end

    # 验证Pod是否存在
    if not kubectl --context=$k8s_context get pod $pod_id >/dev/null 2>&1
        echo (_brow_i18n_format "error_pod_not_exist" $pod_id) >&2
        return 1
    end

    echo (_brow_i18n_format "got_pod_name" $pod_id) >&2

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

    # 检查是否需要使用sudo（端口小于1024）
    set -l need_sudo false
    if test $local_port -lt 1024
        set need_sudo true
        echo (_brow_i18n_get "auto_using_sudo") >&2
    end

    if test "$need_sudo" = true
        # 使用sudo时，先执行一个简单的sudo命令，确保密码输入完成
        sudo true
        # 密码输入完成后，启动端口转发
        sudo kubectl --context=$k8s_context port-forward pod/$pod_id $local_port:$remote_port >$error_file 2>&1 &
        # 获取进程ID
        set pid (jobs -lp | tail -n 1)
    else
        kubectl --context=$k8s_context port-forward pod/$pod_id $local_port:$remote_port >$error_file 2>&1 &
        # 获取进程ID
        set pid $last_pid
    end

    # 等待一会儿，确保端口转发已启动
    sleep 1

    # 检查进程是否仍在运行
    if not kill -0 $pid 2>/dev/null
        echo (_brow_i18n_get "error_port_forward_failed") >&2

        # 显示错误详情
        if test -f $error_file
            echo (_brow_i18n_get "error_details") >&2
            cat $error_file >&2
            rm $error_file
        end

        # 检查端口是否被占用
        echo (_brow_i18n_format "checking_port_usage" $local_port) >&2
        if lsof -i :$local_port >/dev/null 2>&1
            echo (_brow_i18n_format "port_in_use" $local_port) >&2
        end

        return 1
    end

    # 删除临时文件
    rm $error_file 2>/dev/null

    # 保存转发信息 - 使用配置名称作为主要标识
    set -l forward_data (jo config=$clean_config_name pod_id=$pod_id local_port=$local_port remote_port=$remote_port pid=$pid)
    echo $forward_data >$forward_file

    echo (_brow_i18n_format "port_forward_started" $local_port $pod_id $remote_port $forward_id) >&2

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
        echo (_brow_i18n_get "no_forwards_found")
        return 0
    end

    echo (_brow_i18n_get "forward_list_title")
    echo

    # 定义列标题和宽度
    set -l headers (_brow_i18n_get "id") (_brow_i18n_get "config") (_brow_i18n_get "local_port") (_brow_i18n_get "remote_port") (_brow_i18n_get "pid") (_brow_i18n_get "status")
    set -l widths 10 15 15 15 10 15

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
    echo ""

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
        set -l forward_status (_brow_i18n_get "forward_status_stopped")
        set -l status_color red

        # 首先检查进程是否仍在运行
        if not kill -0 $pid 2>/dev/null
            # 如果进程不存在，删除记录文件
            echo (_brow_i18n_format "cleaning_invalid_forward" $forward_id $config_name) >&2
            rm $file 2>/dev/null
            continue
        end

        # 然后检查Pod是否仍然存在
        # 获取配置中的上下文
        set -l k8s_context ""
        if test "$config_name" != unknown
            set -l config_data (_brow_config_get $config_name 2>/dev/null)
            if test $status -eq 0
                set k8s_context (echo $config_data | jq -r '.k8s_context')
            end
        end

        # 如果没有上下文，使用当前上下文
        if test -z "$k8s_context"
            set k8s_context (kubectl config current-context)
        end

        # 检查Pod是否存在
        if test "$pod_id" != unknown -a "$pod_id" != ""
            if not kubectl --context=$k8s_context get pod $pod_id >/dev/null 2>&1
                # 如果Pod不存在，停止转发进程并删除记录文件
                echo (_brow_i18n_format "forward_pod_not_exist" $pod_id) >&2
                kill $pid 2>/dev/null
                rm $file 2>/dev/null
                continue
            end
        end

        # 如果进程和Pod都存在，标记为活跃
        set forward_status (_brow_i18n_get "forward_status_active")
        set status_color green

        # 准备显示数据
        set -l display_data $forward_id $config_name $local_port $remote_port $pid

        # 使用颜色输出状态
        echo -n ""
        _pad_to_width $forward_id $widths[1]
        echo -n " "
        _pad_to_width $config_name $widths[2]
        echo -n " "
        _pad_to_width $local_port $widths[3]
        echo -n " "
        _pad_to_width $remote_port $widths[4]
        echo -n " "
        _pad_to_width $pid $widths[5]
        echo -n " "
        set_color $status_color
        echo $forward_status
        set_color normal
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

function _brow_forward_stop --argument-names forward_id auto_delete_pod
    # 停止特定的转发
    # 参数:
    #   forward_id: 转发ID或配置名称
    #   auto_delete_pod: 是否自动删除Pod（默认为false）

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
                echo (_brow_i18n_format "error_config_no_forwards" $clean_id)
                return 1
            end
        else
            echo (_brow_i18n_format "error_forward_not_found" $clean_id)
            return 1
        end
    end

    # 记录需要删除的Pod
    set -l pods_to_delete
    set -l config_name ""

    for file in $forward_files
        # 读取转发数据
        set -l forward_data (cat $file)
        set config_name (echo $forward_data | jq -r '.config // "unknown"')
        set -l pod_id (echo $forward_data | jq -r '.pod_id // "unknown"')
        set -l local_port (echo $forward_data | jq -r '.local_port')
        set -l remote_port (echo $forward_data | jq -r '.remote_port')
        set -l pid (echo $forward_data | jq -r '.pid')

        # 检查进程是否仍在运行
        if kill -0 $pid 2>/dev/null
            echo (_brow_i18n_format "forward_stopping" $local_port $pod_id $remote_port $pid)
            # 终止进程
            kill $pid 2>/dev/null
            echo (_brow_i18n_get "forward_stopped")
        else
            echo (_brow_i18n_get "forward_process_not_exist")
        end

        # 删除记录文件
        rm $file

        # 如果需要自动删除Pod，将Pod ID添加到列表中
        if test "$auto_delete_pod" = true -a "$pod_id" != unknown -a "$pod_id" != ""
            if not contains $pod_id $pods_to_delete
                set -a pods_to_delete $pod_id
            end
        end
    end

    # 如果需要自动删除Pod并且有Pod需要删除
    if test "$auto_delete_pod" = true -a (count $pods_to_delete) -gt 0
        echo (_brow_i18n_get "cleaning_up")
        for pod_id in $pods_to_delete
            # 检查该Pod是否还有其他活跃的转发
            set -l other_forwards (find $active_dir -name "*-$pod_id-*.json" 2>/dev/null)
            if test -z "$other_forwards"
                # 如果没有其他转发，删除Pod
                echo (_brow_i18n_format "pod_deleting" $pod_id)

                # 获取Pod所在的上下文
                set -l k8s_context ""
                if test -n "$config_name" -a "$config_name" != unknown
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
                kubectl --context=$k8s_context delete pod $pod_id --grace-period=0 --force >/dev/null 2>&1
                if test $status -eq 0
                    echo (_brow_i18n_format "pod_deleted" $pod_id)
                else
                    echo (_brow_i18n_format "pod_delete_failed" $pod_id)
                end
            else
                echo (_brow_i18n_format "pod_has_other_forwards" $pod_id)
            end
        end
    end
end
