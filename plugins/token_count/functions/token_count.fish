function token_count --description 'Count tokens in text files for LLM interaction'
    # 参数处理
    set -l options 'h/human-readable'
    argparse $options -- $argv
    
    if test (count $argv) -eq 0
        echo "Usage: token_count [-h|--human-readable] <file_path> [file_path...]" >&2
        return 1
    end

    # 检查并设置脚本目录
    set -l script_dir
    if set -q SCRIPTS_DIR
        set script_dir $SCRIPTS_DIR/fish/plugins/token_count
    else
        # 如果SCRIPTS_DIR未设置，尝试从当前脚本位置推断
        set -l current_script (status filename)
        set script_dir (dirname (dirname (dirname $current_script)))
    end
    set -l counter_script $script_dir/token_counter.py
    set -l venv_dir $script_dir/.venv
    set -l files $argv
    set -l is_multiple 0

    # 检查是否有多个文件
    if test (count $files) -gt 1
        set is_multiple 1
    end
    
    # 过滤掉不应处理的二进制文件
    set -l filtered_files
    
    # 先根据扩展名进行初步过滤，提高性能
    set -l text_extensions txt md markdown rst py js ts html css xml json yaml yml toml ini conf sh bash zsh fish php rb pl sql c cpp h hpp java go cs scala kt swift rs d jsx tsx vue svelte scss sass less csv tsv log
    set -l doc_extensions pdf doc docx ppt pptx xls xlsx
    
    for file in $files
        # 先检查是否目录
        if test -d "$file"
            # 目录直接跳过，不显示错误
            continue
        end
        
        if test -f "$file"
            # 检查扩展名
            set -l ext (string split -r -m1 '.' "$file" | tail -n 1)
            if contains $ext $text_extensions || contains $ext $doc_extensions
                set -a filtered_files $file
            else
                # 如果没有匹配到扩展名，则使用file命令检查
                set -l file_type (command file -b --mime-type "$file" 2>/dev/null)
                # 如果是支持的文件类型，就添加到处理列表中
                if string match -q "text/*" -- "$file_type" || \
                   string match -q "application/json" -- "$file_type" || \
                   string match -q "application/x-*script" -- "$file_type" || \
                   string match -q "application/xml" -- "$file_type" || \
                   string match -q "application/pdf" -- "$file_type" || \
                   string match -q "application/msword" -- "$file_type" || \
                   string match -q "application/vnd.openxmlformats-officedocument.*" -- "$file_type"
                    set -a filtered_files $file
                else
                    echo "跳过不支持的文件类型: $file ($file_type)" >&2
                end
            end
        else
            echo "跳过：$file (不存在)" >&2
        end
    end
    
    # 更新文件列表为过滤后的列表
    set files $filtered_files

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
    set -l file_results
    set -l total_chars 0
    set -l total_words 0
    set -l total_tokens 0
    set -l total_size 0
    set -l file_count 0
    
    # 用于单文件显示的变量
    set -l last_file ""
    set -l last_type ""
    set -l last_encoding ""
    set -l last_chars 0
    set -l last_words 0
    set -l last_tokens 0
    set -l last_size 0

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
        
        # 从JSON结果中提取数据
        set -l type ""
        set -l encoding ""
        set -l chars 0
        set -l words 0
        set -l tokens 0
        set -l size 0
        set -l parsed 0
        
        # 优先使用jq，再使用jnv，最后使用正则表达式
        if command -q jq
            set type (echo $result | jq -r '.type' 2>/dev/null)
            if test $status -eq 0
                set parsed 1
                set encoding (echo $result | jq -r '.encoding' 2>/dev/null)
                set chars (echo $result | jq -r '.chars' 2>/dev/null)
                set words (echo $result | jq -r '.words' 2>/dev/null)
                set tokens (echo $result | jq -r '.tokens' 2>/dev/null)
                set size (echo $result | jq -r '.size' 2>/dev/null)
            end
        end
        
        if test $parsed -eq 0; and command -q jnv
            set type (echo $result | jnv -r '.type' 2>/dev/null)
            if test $status -eq 0
                set parsed 1
                set encoding (echo $result | jnv -r '.encoding' 2>/dev/null)
                set chars (echo $result | jnv -r '.chars' 2>/dev/null)
                set words (echo $result | jnv -r '.words' 2>/dev/null)
                set tokens (echo $result | jnv -r '.tokens' 2>/dev/null)
                set size (echo $result | jnv -r '.size' 2>/dev/null)
            end
        end
        
        # 如果jq和jnv都不可用或解析失败，使用正则表达式解析
        if test $parsed -eq 0
            set type (echo $result | string match -r '"type":\s*"([^"]*)"' | tail -n 1)
            set encoding (echo $result | string match -r '"encoding":\s*"([^"]*)"' | tail -n 1)
            set chars (echo $result | string match -r '"chars":\s*(\d+)' | tail -n 1)
            set words (echo $result | string match -r '"words":\s*(\d+)' | tail -n 1)
            set tokens (echo $result | string match -r '"tokens":\s*(\d+)' | tail -n 1)
            set size (echo $result | string match -r '"size":\s*(\d+)' | tail -n 1)
        end
        
        # 如果数据解析失败，跳过该文件
        if test -z "$type" -o -z "$encoding" -o -z "$chars" -o -z "$words" -o -z "$tokens" -o -z "$size"
            echo "Error: 无法解析文件处理结果: $file_path" >&2
            continue
        end
        
        # 保存最后一个处理的文件信息(用于单文件模式)
        set last_file $file
        set last_type $type
        set last_encoding $encoding
        set last_chars $chars
        set last_words $words
        set last_tokens $tokens
        set last_size $size

        # 增加总计
        set total_chars (math $total_chars + $chars)
        set total_words (math $total_words + $words)
        set total_tokens (math $total_tokens + $tokens)
        set total_size (math $total_size + $size)
        set file_count (math $file_count + 1)
        
        # 存储结果
        set -a file_results $file
        set -a file_results $type
        set -a file_results $encoding
        set -a file_results $chars
        set -a file_results $words
        set -a file_results $tokens
        set -a file_results $size
    end

    # 没有有效文件
    if test $file_count -eq 0
        echo "Error: 没有找到有效的文件进行处理" >&2
        return 1
    end

    # 单文件模式
    if test $file_count -eq 1; and test $is_multiple -eq 0
        set -l display_chars $last_chars
        set -l display_words $last_words
        set -l display_tokens $last_tokens
        set -l display_size "$last_size bytes"
        
        # 人类可读格式
        if set -q _flag_human_readable
            set display_chars (_human_readable_number $last_chars)
            set display_words (_human_readable_number $last_words)
            set display_tokens (_human_readable_number $last_tokens)
            set display_size (_human_readable_size $last_size)
        end
        
        echo "文件分析结果："
        echo "文件: $last_file"
        echo "文件类型: $last_type"
        echo "编码: $last_encoding"
        echo "字符数: $display_chars"
        echo "单词数: $display_words"
        echo "Token数: $display_tokens"
        echo "文件大小: $display_size"
        return 0
    end

    # 多文件模式: 直接用 Fish 处理表格

    # 初始化最小列宽
    set -l filename_width 20  # 文件名列的最小宽度
    set -l type_width 15      # 类型列的最小宽度
    set -l encoding_width 8   # 编码列的最小宽度
    set -l chars_width 10     # 字符数列的最小宽度
    set -l words_width 10     # 单词数列的最小宽度
    set -l tokens_width 10    # Token数列的最小宽度
    set -l size_width 15      # 大小列的最小宽度

    # 根据标题计算最小列宽
    set -l headers "文件名" "类型" "编码" "字符数" "单词数" "Token数" "大小"
    set -l header_widths (string length --visible -- $headers[1]) (string length --visible -- $headers[2]) (string length --visible -- $headers[3]) (string length --visible -- $headers[4]) (string length --visible -- $headers[5]) (string length --visible -- $headers[6]) (string length --visible -- $headers[7])
    
    if test $header_widths[1] -gt $filename_width
        set filename_width $header_widths[1]
    end
    if test $header_widths[2] -gt $type_width
        set type_width $header_widths[2]
    end
    if test $header_widths[3] -gt $encoding_width
        set encoding_width $header_widths[3]
    end
    if test $header_widths[4] -gt $chars_width
        set chars_width $header_widths[4]
    end
    if test $header_widths[5] -gt $words_width
        set words_width $header_widths[5]
    end
    if test $header_widths[6] -gt $tokens_width
        set tokens_width $header_widths[6]
    end
    if test $header_widths[7] -gt $size_width
        set size_width $header_widths[7]
    end

    # 计算总计行的文本宽度
    set -l total_str "总计($file_count文件)"
    set -l total_visible_width (string length --visible -- "$total_str")
    if test $total_visible_width -gt $filename_width
        set filename_width $total_visible_width
    end

    # 检查每行数据的宽度，更新列宽
    for i in (seq 1 $file_count)
        set -l idx (math "($i - 1) * 7 + 1")
        
        # 文件名列
        set -l filename (basename $file_results[$idx])
        set -l name_visible_width (string length --visible -- "$filename")
        if test $name_visible_width -gt $filename_width
            set filename_width $name_visible_width
        end
        
        # 文件类型列
        set -l filetype $file_results[(math $idx + 1)]
        set -l type_visible_width (string length --visible -- "$filetype")
        if test $type_visible_width -gt $type_width
            set type_width $type_visible_width
        end
        
        # 编码列
        set -l fileencoding $file_results[(math $idx + 2)]
        set -l encoding_visible_width (string length --visible -- "$fileencoding")
        if test $encoding_visible_width -gt $encoding_width
            set encoding_width $encoding_visible_width
        end
        
        # 准备显示数据
        set -l chars $file_results[(math $idx + 3)]
        set -l words $file_results[(math $idx + 4)]
        set -l tokens $file_results[(math $idx + 5)]
        set -l size $file_results[(math $idx + 6)]
        
        set -l display_chars $chars
        set -l display_words $words
        set -l display_tokens $tokens
        set -l display_size "$size bytes"
        
        # 人类可读格式(用于计算列宽)
        if set -q _flag_human_readable
            set display_chars (_human_readable_number $chars)
            set display_words (_human_readable_number $words)
            set display_tokens (_human_readable_number $tokens)
            set display_size (_human_readable_size $size)
        end
        
        # 检查其他列的宽度
        set -l chars_visible_width (string length --visible -- "$display_chars")
        if test $chars_visible_width -gt $chars_width
            set chars_width $chars_visible_width
        end
        
        set -l words_visible_width (string length --visible -- "$display_words")
        if test $words_visible_width -gt $words_width
            set words_width $words_visible_width
        end
        
        set -l tokens_visible_width (string length --visible -- "$display_tokens")
        if test $tokens_visible_width -gt $tokens_width
            set tokens_width $tokens_visible_width
        end
        
        set -l size_visible_width (string length --visible -- "$display_size")
        if test $size_visible_width -gt $size_width
            set size_width $size_visible_width
        end
    end

    # 打印表格标题
    echo "文件统计表格："
    
    # 打印表头
    echo -n "| "
    _pad_to_width "文件名" $filename_width
    echo -n " | "
    _pad_to_width "类型" $type_width
    echo -n " | "
    _pad_to_width "编码" $encoding_width
    echo -n " | "
    _pad_to_width "字符数" $chars_width
    echo -n " | "
    _pad_to_width "单词数" $words_width
    echo -n " | "
    _pad_to_width "Token数" $tokens_width
    echo -n " | "
    _pad_to_width "大小" $size_width
    echo " |"

    # 打印分隔线
    echo -n "| "
    _pad_to_width (string repeat -n $filename_width "-") $filename_width
    echo -n " | "
    _pad_to_width (string repeat -n $type_width "-") $type_width
    echo -n " | "
    _pad_to_width (string repeat -n $encoding_width "-") $encoding_width
    echo -n " | "
    _pad_to_width (string repeat -n $chars_width "-") $chars_width
    echo -n " | "
    _pad_to_width (string repeat -n $words_width "-") $words_width
    echo -n " | "
    _pad_to_width (string repeat -n $tokens_width "-") $tokens_width
    echo -n " | "
    _pad_to_width (string repeat -n $size_width "-") $size_width
    echo " |"

    # 打印每个文件的数据行
    for i in (seq 1 $file_count)
        set -l idx (math "($i - 1) * 7 + 1")
        set -l filename (basename $file_results[$idx])
        set -l filetype $file_results[(math $idx + 1)]
        set -l fileencoding $file_results[(math $idx + 2)]
        set -l chars $file_results[(math $idx + 3)]
        set -l words $file_results[(math $idx + 4)]
        set -l tokens $file_results[(math $idx + 5)]
        set -l size $file_results[(math $idx + 6)]
        
        # 准备显示数据
        set -l display_chars $chars
        set -l display_words $words
        set -l display_tokens $tokens
        set -l display_size "$size bytes"
        
        # 人类可读格式
        if set -q _flag_human_readable
            set display_chars (_human_readable_number $chars)
            set display_words (_human_readable_number $words)
            set display_tokens (_human_readable_number $tokens)
            set display_size (_human_readable_size $size)
        end
        
        # 打印行
        echo -n "| "
        _pad_to_width "$filename" $filename_width
        echo -n " | "
        _pad_to_width "$filetype" $type_width
        echo -n " | "
        _pad_to_width "$fileencoding" $encoding_width
        echo -n " | "
        _pad_to_width "$display_chars" $chars_width
        echo -n " | "
        _pad_to_width "$display_words" $words_width
        echo -n " | "
        _pad_to_width "$display_tokens" $tokens_width
        echo -n " | "
        _pad_to_width "$display_size" $size_width
        echo " |"
    end

    # 准备总计行数据
    set -l total_str (string join "" "总计(" $file_count "文件)")
    set -l display_total_chars $total_chars
    set -l display_total_words $total_words
    set -l display_total_tokens $total_tokens
    set -l display_total_size "$total_size bytes"
    
    # 人类可读格式的总计
    if set -q _flag_human_readable
        set display_total_chars (_human_readable_number $total_chars)
        set display_total_words (_human_readable_number $total_words)
        set display_total_tokens (_human_readable_number $total_tokens)
        set display_total_size (_human_readable_size $total_size)
    end

    # 打印分隔线
    echo -n "| "
    _pad_to_width (string repeat -n $filename_width "-") $filename_width
    echo -n " | "
    _pad_to_width (string repeat -n $type_width "-") $type_width
    echo -n " | "
    _pad_to_width (string repeat -n $encoding_width "-") $encoding_width
    echo -n " | "
    _pad_to_width (string repeat -n $chars_width "-") $chars_width
    echo -n " | "
    _pad_to_width (string repeat -n $words_width "-") $words_width
    echo -n " | "
    _pad_to_width (string repeat -n $tokens_width "-") $tokens_width
    echo -n " | "
    _pad_to_width (string repeat -n $size_width "-") $size_width
    echo " |"
    
    # 打印总计行
    echo -n "| "
    _pad_to_width "$total_str" $filename_width
    echo -n " | "
    _pad_to_width "" $type_width
    echo -n " | "
    _pad_to_width "" $encoding_width
    echo -n " | "
    _pad_to_width "$display_total_chars" $chars_width
    echo -n " | "
    _pad_to_width "$display_total_words" $words_width
    echo -n " | "
    _pad_to_width "$display_total_tokens" $tokens_width
    echo -n " | "
    _pad_to_width "$display_total_size" $size_width
    echo " |"
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