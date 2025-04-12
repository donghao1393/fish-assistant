function token_count --description 'Count tokens in text files for LLM interaction'
    # 参数处理
    set -l options 'h/human-readable'
    argparse $options -- $argv
    
    if test (count $argv) -eq 0
        echo "Usage: token_count [-h|--human-readable] <file_path> [file_path...]" >&2
        return 1
    end

    set -l script_dir $SCRIPTS_DIR/fish/plugins/token_count
    set -l counter_script $script_dir/token_counter.py
    set -l venv_dir $script_dir/.venv
    set -l files $argv
    set -l is_multiple 0

    # 检查是否有多个文件
    if test (count $files) -gt 1
        set is_multiple 1
    end

    # 检查虚拟环境是否存在
    if not test -d $venv_dir
        echo "虚拟环境不存在，正在初始化..." >&2
        pushd $script_dir
        fish install.fish
        popd

        if test $status -ne 0
            echo "Error: 初始化虚拟环境失败" >&2
            return 1
        end
    end

    # 检查系统依赖
    if test (uname) = Darwin; and not command -q brew
        echo "Error: 需要安装 Homebrew 以便安装 libmagic" >&2
        return 1
    end

    if not test -f /usr/local/lib/libmagic.dylib; and not test -f /opt/homebrew/lib/libmagic.dylib
        echo "注意: 安装 libmagic 系统依赖..." >&2
        brew install libmagic
    end

    # 初始化结果记录
    set -l results 
    set -l total_chars 0
    set -l total_words 0
    set -l total_tokens 0
    set -l total_size 0
    set -l file_count 0

    # 处理每个文件
    for file in $files
        set -l file_path (realpath $file)

        if not test -f "$file_path"
            echo "Warning: 文件不存在或不是常规文件: $file_path" >&2
            continue
        end

        # 使用 uv 运行 Python 脚本并解析结果
        pushd $script_dir
        set -l result (uv run $counter_script "$file_path")
        set -l status_code $status
        popd

        if test $status_code -ne 0
            echo "Error: 处理文件失败: $file_path" >&2
            continue
        end

        # 解析JSON结果
        set -l json $result
        set -l type (echo $json | string match -r '"type":\s*"([^"]*)"' | tail -n 1)
        set -l encoding (echo $json | string match -r '"encoding":\s*"([^"]*)"' | tail -n 1)
        set -l chars (echo $json | string match -r '"chars":\s*(\d+)' | tail -n 1)
        set -l words (echo $json | string match -r '"words":\s*(\d+)' | tail -n 1)
        set -l tokens (echo $json | string match -r '"tokens":\s*(\d+)' | tail -n 1)
        set -l size (echo $json | string match -r '"size":\s*(\d+)' | tail -n 1)

        # 增加总计
        set total_chars (math $total_chars + $chars)
        set total_words (math $total_words + $words)
        set total_tokens (math $total_tokens + $tokens)
        set total_size (math $total_size + $size)
        set file_count (math $file_count + 1)

        # 记录结果
        set -a results "$file\t$type\t$encoding\t$chars\t$words\t$tokens\t$size"
    end

    # 没有有效文件
    if test $file_count -eq 0
        echo "Error: 没有找到有效的文件进行处理" >&2
        return 1
    end

    # 单文件模式
    if test $file_count -eq 1; and test $is_multiple -eq 0
        set -l display_chars $chars
        set -l display_words $words
        set -l display_tokens $tokens
        set -l display_size $size
        
        # 人类可读格式
        if set -q _flag_human_readable
            set display_chars (_human_readable_number $chars)
            set display_words (_human_readable_number $words)
            set display_tokens (_human_readable_number $tokens)
            set display_size (_human_readable_size $size)
        end
        
        echo "文件分析结果："
        echo "文件: $files[1]"
        echo "文件类型: $type"
        echo "编码: $encoding"
        echo "字符数: $display_chars"
        echo "单词数: $display_words"
        echo "Token数: $display_tokens"
        echo "文件大小: $display_size"
        return 0
    end

    # 多文件模式：编译人类可读的结果
    set -l display_results
    set -l display_total_chars $total_chars
    set -l display_total_words $total_words
    set -l display_total_tokens $total_tokens
    set -l display_total_size $total_size
    
    # 处理文件名以避免过长
    for i in (seq (count $results))
        set -l parts (string split \t $results[$i])
        set -l file_name $parts[1]
        set -l short_name (basename $file_name)
        
        # 如果需要人类可读的数字
        if set -q _flag_human_readable
            set parts[4] (_human_readable_number $parts[4]) # 字符数
            set parts[5] (_human_readable_number $parts[5]) # 单词数
            set parts[6] (_human_readable_number $parts[6]) # token数
            set parts[7] (_human_readable_size $parts[7]) # 大小
        else
            set parts[7] "$parts[7] bytes"
        end
        
        set -l new_result "$short_name\t$parts[2]\t$parts[3]\t$parts[4]\t$parts[5]\t$parts[6]\t$parts[7]"
        set -a display_results $new_result
    end
    
    # 总计行人类可读格式
    if set -q _flag_human_readable
        set display_total_chars (_human_readable_number $total_chars)
        set display_total_words (_human_readable_number $total_words)
        set display_total_tokens (_human_readable_number $total_tokens)
        set display_total_size (_human_readable_size $total_size)
    else
        set display_total_size "$total_size bytes"
    end
    
    # 输出表格
    echo "文件统计表格："
    # 表头
    printf "%-30s\t%-12s\t%-8s\t%-10s\t%-10s\t%-10s\t%-15s\n" "文件" "类型" "编码" "字符数" "单词数" "Token数" "大小"
    printf "%-30s\t%-12s\t%-8s\t%-10s\t%-10s\t%-10s\t%-15s\n" "------------------------------" "------------" "--------" "----------" "----------" "----------" "---------------"
    
    # 打印每个文件的结果
    for result in $display_results
        set -l parts (string split \t $result)
        printf "%-30s\t%-12s\t%-8s\t%-10s\t%-10s\t%-10s\t%-15s\n" $parts
    end
    
    # 打印总计
    printf "%-30s\t%-12s\t%-8s\t%-10s\t%-10s\t%-10s\t%-15s\n" "------------------------------" "------------" "--------" "----------" "----------" "----------" "---------------"
    printf "%-30s\t%-12s\t%-8s\t%-10s\t%-10s\t%-10s\t%-15s\n" "总计($file_count文件)" "" "" "$display_total_chars" "$display_total_words" "$display_total_tokens" "$display_total_size"
end

# 辅助函数：转换人类可读的数字
 function _human_readable_number --argument-names number
    if test $number -lt 1000
        echo $number
    else if test $number -lt 1000000
        printf "%.1fK" (math "$number / 1000")
    else if test $number -lt 1000000000
        printf "%.1fM" (math "$number / 1000000")
    else
        printf "%.1fG" (math "$number / 1000000000")
    end
end

# 辅助函数：转换人类可读的文件大小
function _human_readable_size --argument-names bytes
    if test $bytes -lt 1024
        echo "$bytes bytes"
    else if test $bytes -lt 1048576
        printf "%.1f KB" (math "$bytes / 1024")
    else if test $bytes -lt 1073741824
        printf "%.1f MB" (math "$bytes / 1048576")
    else
        printf "%.1f GB" (math "$bytes / 1073741824")
    end
end