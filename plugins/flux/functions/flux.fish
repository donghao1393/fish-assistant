function flux -d "Generate images using Flux AI with common aspect ratios"
    # 检查依赖
    if not set -q SCRIPTS_DIR
        echo "Error: SCRIPTS_DIR environment variable is not set"
        return 1
    end

    # 检查必要的命令
    for cmd in md5sum jq python3 curl uv
        if not command -v $cmd >/dev/null
            echo "Error: $cmd is not installed. Please install it first."
            return 1
        end
    end

    # 定义虚拟环境路径
    set -l venv_path "$SCRIPTS_DIR/fish/plugins/flux/.venv"

    # 检查 flux 虚拟环境是否存在
    if not test -d $venv_path
        echo "Error: flux虚拟环境不存在
请创建它并安装所需的包：
  mkdir -p $SCRIPTS_DIR/fish/plugins/flux
  cd $SCRIPTS_DIR/fish/plugins/flux
  uv pip install -e ."
        return 1
    end

    # 激活 flux 环境
    set -l old_path $PATH
    set -l old_python_path $PYTHONPATH
    # 添加虚拟环境的 bin 目录到 PATH
    set -gx PATH $venv_path/bin $PATH

    # 确认是否使用了虚拟环境的 Python
    set -l python_path (which python)
    if not string match -q "*$venv_path*" $python_path
        echo "Error: 无法激活虚拟环境"
        return 1
    end

    # 预设的宽高比选项
    set -l aspect_ratios
    set -a aspect_ratios "16:9  (电脑屏幕常见，横屏视频)"
    set -a aspect_ratios "4:3   (传统屏幕)"
    set -a aspect_ratios "21:9  (超宽屏幕，电影常见)"
    set -a aspect_ratios "9:16  (手机屏幕，竖屏视频)"
    set -a aspect_ratios "3:2   (相机常见)"
    set -a aspect_ratios "1:1   (方形，社交媒体)"
    set -a aspect_ratios "自定义 (输入任意宽高比)"
    set -l aspect_ratio_values "16:9" "4:3" "21:9" "9:16" "3:2" "1:1" custom

    # 创建保存目录
    set -l save_dir ~/Pictures/flux
    mkdir -p $save_dir

    # 参数解析
    argparse h/help 'f/file=' 'p/prompt=' 's/seed=' -- $argv
    or begin
        # 如果参数解析失败，恢复PATH
        set -gx PATH $old_path
        set -gx PYTHONPATH $old_python_path
        return 1
    end

    if set -q _flag_help
        echo "Usage: flux [-h/--help] [-f/--file PROMPT_FILE] [-p/--prompt PROMPT_TEXT] [-s/--seed SEED]"
        echo
        echo "Options:"
        echo "  -h, --help            显示帮助信息"
        echo "  -f, --file FILE       从文件读取提示词"
        echo "  -p, --prompt PROMPT   直接提供提示词"
        echo "  -s, --seed SEED       设置随机种子"
        echo
        echo "支持的宽高比:"
        for ratio in $aspect_ratios
            echo "  $ratio"
        end
        # 在显示帮助后恢复PATH
        set -gx PATH $old_path
        set -gx PYTHONPATH $old_python_path
        return 0
    end

    # 处理提示词输入
    set -l prompt_arg
    set -l prompt_source
    set -l prompt_content

    if set -q _flag_file
        if not test -f $_flag_file
            echo "Error: Prompt file does not exist: $_flag_file"
            # 错误时恢复PATH
            set -gx PATH $old_path
            set -gx PYTHONPATH $old_python_path
            return 1
        end
        # 读取文件内容并确保正确处理
        set prompt_content (cat $_flag_file | string collect)
        if test -z "$prompt_content"
            echo "Error: Prompt file is empty"
            # 错误时恢复PATH
            set -gx PATH $old_path
            set -gx PYTHONPATH $old_python_path
            return 1
        end
        set prompt_arg --prompt-file $_flag_file
        set prompt_source "file: $_flag_file"
    else if set -q _flag_prompt
        set prompt_content $_flag_prompt
        set prompt_arg --prompt $_flag_prompt
        set prompt_source "text: $_flag_prompt"
    else
        # 交互式输入提示词
        echo "请输入图像生成提示词 (Ctrl+D 结束输入):"
        set prompt_content (read -z | string collect)
        if test -z "$prompt_content"
            echo "Error: No prompt provided"
            # 错误时恢复PATH
            set -gx PATH $old_path
            set -gx PYTHONPATH $old_python_path
            return 1
        end

        # 创建临时文件保存提示词，退出时自动删除
        set -l temp_file (mktemp)
        trap "rm -f $temp_file" EXIT
        printf "%s\n" $prompt_content >$temp_file
        set prompt_arg --prompt-file $temp_file
        set prompt_source "interactive input"
    end

    # 计算提示词的MD5哈希
    set -l prompt_hash (echo -n $prompt_content | md5sum | cut -d' ' -f1)

    # 选择宽高比
    echo "请选择宽高比 (默认 16:9):"
    for i in (seq (count $aspect_ratios))
        echo "[$i] $aspect_ratios[$i]"
    end

    read -P "选择序号 (直接回车使用默认): " choice

    set -l aspect_ratio
    if test -z "$choice"
        set aspect_ratio "16:9"
    else if test "$choice" -ge 1 -a "$choice" -le (count $aspect_ratio_values)
        if test "$aspect_ratio_values[$choice]" = custom
            # 处理自定义宽高比
            while true
                read -P "请输入宽度 (正整数): " width
                if string match -qr '^[1-9][0-9]*$' -- $width
                    break
                end
                echo "无效的宽度，请重新输入"
            end

            while true
                read -P "请输入高度 (正整数): " height
                if string match -qr '^[1-9][0-9]*$' -- $height
                    break
                end
                echo "无效的高度，请重新输入"
            end

            set aspect_ratio "$width:$height"
        else
            set aspect_ratio $aspect_ratio_values[$choice]
        end
    else
        echo "Error: Invalid choice"
        # 错误时恢复PATH
        set -gx PATH $old_path
        set -gx PYTHONPATH $old_python_path
        return 1
    end

    # 构建命令参数
    set -l cmd_args
    set -a cmd_args $prompt_arg
    set -a cmd_args --model flux-pro-1.1-ultra
    set -a cmd_args --aspect-ratio $aspect_ratio

    if set -q _flag_seed
        set -a cmd_args --seed $_flag_seed
    end

    # 创建一个临时管道
    function mkfifo_temp
        set -l pipe_path (mktemp -u)
        mkfifo $pipe_path
        echo $pipe_path # 返回管道路径供调用者使用
    end

    # 创建临时文件
    set -l output_file (mkfifo_temp)

    # 执行生成命令
    echo "正在生成图片..."
    echo "提示词来源: $prompt_source"
    echo "使用宽高比: $aspect_ratio"

    # 直接执行命令并同时将输出发送到终端和文件
    python -u $SCRIPTS_DIR/fish/plugins/flux/generate_flux_image.py $cmd_args 2>&1 | tee $output_file &

    # 检查命令是否成功执行
    if test $status -ne 0
        echo "Error: Generation failed"
        cat $output_file
        rm -f $output_file
        # 错误时恢复PATH
        set -gx PATH $old_path
        set -gx PYTHONPATH $old_python_path
        return 1
    end

    # 从输出中提取最后一个Result块
    set -l lines (cat $output_file)
    set -l start_line -1
    set -l end_line -1
    set -l current_line 1

    # 遍历所有行，找到最后一个"Result:"和对应的JSON块
    for line in $lines
        # 标记Result开始位置
        if string match -q "Result: {" -- $line
            set start_line $current_line
        else if test $start_line -gt 0; and string match -q "}" -- $line
            # 找到闭合的大括号
            set end_line $current_line
        end
        set current_line (math $current_line + 1)
    end

    if test $start_line -gt 0 -a $end_line -gt 0
        # 提取JSON内容
        set -l result_content
        set -l line_num 1
        for line in $lines
            if test $line_num -ge $start_line -a $line_num -le $end_line
                # 第一行需要去掉"Result: "前缀
                if test $line_num -eq $start_line
                    set -a result_content (string replace "Result: " "" -- $line)
                else
                    set -a result_content $line
                end
            end
            set line_num (math $line_num + 1)
        end

        # 将多行内容合并成单个字符串
        set -l json_result (string join \n $result_content)

        # 从JSON结果中提取URL和seed
        set -l download_url (echo $json_result | jq -r '.sample')
        set -l seed (echo $json_result | jq -r '.seed')

        # 构建输出文件名
        set -l base_filename $save_dir/$prompt_hash

        # 先保存提示词文本
        set -l prompt_file $base_filename.txt
        # 如果文件不存在或为空文件
        if test ! -s $prompt_file
            printf "%s" "$prompt_content" >$prompt_file
            echo "提示词已保存到: $prompt_file"
        else
            echo "提示词文件已存在: $prompt_file"
        end

        # 添加文件名后缀
        # 如果seed不为空，使用seed作为后缀，否则使用当前时间戳
        if test "$seed" != null # for the usage of jq
            set base_filename $base_filename.s$seed
        else
            set unix_timestamp (date +%s.%N)
            set base_filename $base_filename.t$unix_timestamp
        end

        # 保存图片
        set -l image_file $base_filename.jpeg
        echo "正在下载图片到: $image_file"

        # 下载图片（使用-f强制覆盖，-L跟随重定向，关闭进度显示）
        if test -n "$download_url"
            curl -s -f -L "$download_url" -o "$image_file"
            set -l download_status $status
            if test $download_status -eq 0; and test -f $image_file
                echo "下载完成！"
            else
                echo "下载失败 (状态码: $download_status)"
                rm -f $image_file
                rm -f $output_file
                # 错误时恢复PATH
                set -gx PATH $old_path
                set -gx PYTHONPATH $old_python_path
                return 1
            end
        else
            echo "Error: Could not extract download URL from result"
            cat $output_file
            rm -f $output_file
            # 错误时恢复PATH
            set -gx PATH $old_path
            set -gx PYTHONPATH $old_python_path
            return 1
        end
    else
        echo "Error: Could not find complete Result section in output"
        rm -f $output_file
        # 错误时恢复PATH
        set -gx PATH $old_path
        set -gx PYTHONPATH $old_python_path
        return 1
    end

    rm -f $output_file

    # 成功完成后，恢复PATH
    set -gx PATH $old_path
    set -gx PYTHONPATH $old_python_path
end
