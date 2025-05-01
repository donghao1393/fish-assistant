function token_count --description 'Count tokens in text files for LLM interaction'
    # 参数处理
    set -l options 'h/human-readable' 'v/verbose' 'r/recursive' 'e/exclude=' 'max-files='
    argparse $options -- $argv

    if test (count $argv) -eq 0
        echo "Usage: token_count [-h|--human-readable] [-v|--verbose] [-r|--recursive] [--max-files=N] [-e|--exclude=PATTERN] <file_path|directory> [file_path|directory...]" >&2
        echo "Run 'token_count --help' for more information" >&2
        return 1
    end

    # 显示帮助信息
    if contains -- --help $argv
        _token_count_help
        return 0
    end

    # 检查FISH_ASSISTANT_HOME环境变量
    if not set -q FISH_ASSISTANT_HOME
        echo "错误: 未设置FISH_ASSISTANT_HOME环境变量"
        echo "请在~/.config/fish/config.fish中添加以下内容:"
        echo "    set -gx FISH_ASSISTANT_HOME /path/to/fish-assistant"
        return 1
    end

    # 设置脚本目录
    set -l script_dir $FISH_ASSISTANT_HOME/plugins/token_count
    set -l counter_script $script_dir/token_counter.py
    set -l venv_dir $script_dir/.venv
    set -l files $argv
    set -l is_multiple 0

    # 检查是否有多个文件
    if test (count $files) -gt 1
        set is_multiple 1
    end

    # 定义支持的文件类型
    set -l text_extensions txt md markdown rst py js ts html css xml json yaml yml toml ini conf sh bash zsh fish php rb pl sql c cpp h hpp java go cs scala kt swift rs d jsx tsx vue svelte scss sass less csv tsv log
    set -l doc_extensions pdf doc docx ppt pptx xls xlsx

    # 处理目录和文件路径
    set -l expanded_files
    set -l max_files 1000 # 默认最大文件数

    # 如果设置了最大文件数限制
    if set -q _flag_max_files
        set max_files $_flag_max_files
    end

    # 处理每个输入路径
    for path in $files
        # 检查是否目录
        if test -d "$path"
            set -l find_cmd

            # 优先使用fd工具，如果可用
            if command -q fd
                # 构建基本命令
                if set -q _flag_recursive
                    set find_cmd fd -t f
                else
                    set find_cmd fd -t f -d 1
                end

                # 添加文件类型过滤
                set -l ext_pattern
                for ext in $text_extensions $doc_extensions
                    set ext_pattern "$ext_pattern -e .$ext"
                end

                # 添加排除模式
                if set -q _flag_exclude
                    set find_cmd $find_cmd -E "$_flag_exclude"
                end

                # 执行命令
                # 对于包含特殊字符的路径，使用--full-path选项
                if string match -q "*,*" -- "$path"; or string match -q "*(*" -- "$path"; or string match -q "*)*" -- "$path"; or string match -q "*[*" -- "$path"; or string match -q "*]*" -- "$path"
                    # 使用--full-path选项处理特殊字符
                    set -l abs_path (realpath "$path")
                    set -l found_files (eval "cd \"$abs_path\" && $find_cmd $ext_pattern . -a" | head -n $max_files | sed "s|^|$abs_path/|")
                    set expanded_files $expanded_files $found_files
                else
                    # 正常处理
                    set -l found_files (eval "$find_cmd $ext_pattern \"$path\" -a" | head -n $max_files)
                    set expanded_files $expanded_files $found_files
                end

                # 显示处理信息
                if set -q _flag_verbose
                    echo "从目录 $path 中发现 "(count $found_files)" 个文件" >&2
                end

            # 如果没有fd，使用find
            else
                # 构建基本命令
                if set -q _flag_recursive
                    set find_cmd find "$path" -type f
                else
                    set find_cmd find "$path" -maxdepth 1 -type f
                end

                # 添加文件类型过滤
                set -l ext_pattern ""
                for ext in $text_extensions $doc_extensions
                    set ext_pattern "$ext_pattern -o -name '*.$ext'"
                end
                set ext_pattern (string sub -s 4 "$ext_pattern") # 移除第一个 -o

                # 添加排除模式
                if set -q _flag_exclude
                    set find_cmd $find_cmd -not -path "*$_flag_exclude*"
                end

                # 执行命令
                # 对于包含特殊字符的路径，使用特殊处理
                if string match -q "*,*" -- "$path"; or string match -q "*(*" -- "$path"; or string match -q "*)*" -- "$path"; or string match -q "*[*" -- "$path"; or string match -q "*]*" -- "$path"
                    # 使用cd进入目录然后查找
                    set -l abs_path (realpath "$path")
                    set -l found_files (eval "cd \"$abs_path\" && find . -type f \( $ext_pattern \)" | head -n $max_files | sed "s|^\\.|$abs_path|")
                    set expanded_files $expanded_files $found_files
                else
                    # 正常处理
                    set -l found_files (eval "$find_cmd \( $ext_pattern \)" | head -n $max_files)
                    set expanded_files $expanded_files $found_files
                end

                # 显示处理信息
                if set -q _flag_verbose
                    echo "从目录 $path 中发现 "(count $found_files)" 个文件" >&2
                end
            end

        # 如果是文件，直接添加
        else if test -f "$path"
            set -a expanded_files "$path"
        else
            echo "跳过：$path (不存在或不是文件/目录)" >&2
        end
    end

    # 过滤掉不应处理的二进制文件
    set -l filtered_files

    for file in $expanded_files
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
                    if set -q _flag_verbose
                        echo "跳过不支持的文件类型: $file ($file_type)" >&2
                    end
                end
            end
        else
            if set -q _flag_verbose
                echo "跳过：$file (不存在)" >&2
            end
        end
    end

    # 更新文件列表为过滤后的列表
    set files $filtered_files

    # 检查虚拟环境是否存在
    if not test -d $venv_dir
        echo "虚拟环境不存在，正在初始化..." >&2

        # 在子shell中执行安装脚本
        fish -c "cd $script_dir && fish install.fish"

        # 确保虚拟环境已正确创建
        if not test -d $venv_dir
            echo "Error: 虚拟环境创建失败" >&2
            return 1
        end

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

        # 在子shell中执行Python脚本，自动激活和退出虚拟环境
        set -l verbose_flag ""
        if set -q _flag_verbose
            set verbose_flag "--verbose"
        end

        # 使用fish -c在子shell中执行，自动激活和退出虚拟环境
        set result (fish -c "cd $script_dir && source $venv_dir/bin/activate.fish && uv run --active $counter_script \"$file_path\" $verbose_flag")
        set -l status_code $status

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

# 帮助信息函数
function _token_count_help
    echo "token_count - 计算文本文件和PDF文件中token数量的工具"
    echo
    echo "用法: token_count [选项] <文件路径|目录> [文件路径|目录...]"
    echo
    echo "选项:"
    echo "  -h, --human-readable    使用人类可读格式显示数字（如K/M/G等）"
    echo "  -v, --verbose           显示详细处理信息和警告"
    echo "  -r, --recursive         递归处理目录中的文件"
    echo "  -e, --exclude=PATTERN   排除匹配指定模式的文件"
    echo "  --max-files=N           限制处理的最大文件数（默认1000）"
    echo "  --help                  显示此帮助信息"
    echo
    echo "示例:"
    echo "  token_count document.txt                  # 处理单个文本文件"
    echo "  token_count document.pdf                  # 处理单个PDF文件"
    echo "  token_count *.md                          # 处理所有Markdown文件"
    echo "  token_count -h *.md                       # 使用人类可读格式显示所有Markdown文件的统计"
    echo "  token_count -v document.pdf               # 处理PDF文件并显示详细警告信息"
    echo "  token_count src/                          # 处理src目录下的所有文件（非递归）"
    echo "  token_count -r src/                       # 递归处理src目录及其子目录下的所有文件"
    echo "  token_count -r -e=".git" src/              # 递归处理src目录，但排除.git目录"
    echo "  token_count -r --max-files=100 src/       # 递归处理src目录，最多处理100个文件"
    echo "  token_count -r -h src/ docs/              # 递归处理多个目录并使用人类可读格式"
    echo
    echo "支持的文件类型:"
    echo "  - 文本文件: txt, md, py, js, html, css, json, yaml, 等"
    echo "  - 文档文件: pdf, doc, docx, ppt, pptx, xls, xlsx"
    echo
    echo "注意: 处理大型目录时，请使用--max-files选项限制文件数量以提高性能"
    echo
    echo "依赖:"
    echo "  - Python包: tiktoken, chardet, python-magic, pdfplumber"
    echo "  - 系统工具: file, find/fd"
    echo
    echo "如果遇到问题，请尝试使用-v选项查看详细输出"
end