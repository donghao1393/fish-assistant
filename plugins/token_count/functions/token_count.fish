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
    set -l file_results
    set -l total_chars 0
    set -l total_words 0
    set -l total_tokens 0
    set -l total_size 0
    set -l file_count 0
    
    # 保存最后一个文件的详细信息(用于单文件显示)
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

        # 解析JSON结果
        set -l type (echo $result | string match -r '"type":\s*"([^"]*)"' | tail -n 1)
        set -l encoding (echo $result | string match -r '"encoding":\s*"([^"]*)"' | tail -n 1)
        set -l chars (echo $result | string match -r '"chars":\s*(\d+)' | tail -n 1)
        set -l words (echo $result | string match -r '"words":\s*(\d+)' | tail -n 1)
        set -l tokens (echo $result | string match -r '"tokens":\s*(\d+)' | tail -n 1)
        set -l size (echo $result | string match -r '"size":\s*(\d+)' | tail -n 1)
        
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
        
        # 使用数组存储数据而不是制表符分隔
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

    # 多文件模式：使用 awk 输出表格
    set -l awk_script '
    BEGIN {
        # 设置列标题
        titles[1] = "文件"; 
        titles[2] = "类型"; 
        titles[3] = "编码"; 
        titles[4] = "字符数"; 
        titles[5] = "单词数"; 
        titles[6] = "Token数"; 
        titles[7] = "大小";
        
        # 初始化列宽度
        widths[1] = length(titles[1]);
        widths[2] = length(titles[2]);
        widths[3] = length(titles[3]);
        widths[4] = length(titles[4]);
        widths[5] = length(titles[5]);
        widths[6] = length(titles[6]);
        widths[7] = length(titles[7]);
        
        # 设置列数
        num_cols = 7;
        
        # 设置总计行
        total_label = "总计(" file_count "文件)";
        if (length(total_label) > widths[1]) widths[1] = length(total_label);
    }
    
    # 处理每一行数据
    {
        # 存储数据
        data[NR, 1] = $1;
        data[NR, 2] = $2;
        data[NR, 3] = $3;
        data[NR, 4] = $4;
        data[NR, 5] = $5;
        data[NR, 6] = $6;
        data[NR, 7] = $7;
        
        # 更新列宽度
        for (i = 1; i <= num_cols; i++) {
            if (length($i) > widths[i]) widths[i] = length($i);
        }
    }
    
    END {
        # 打印表格标题
        printf "文件统计表格：\n";
        
        # 打印列标题
        for (i = 1; i <= num_cols; i++) {
            printf "%-" widths[i] "s  ", titles[i];
        }
        printf "\n";
        
        # 打印分隔线
        for (i = 1; i <= num_cols; i++) {
            for (j = 1; j <= widths[i]; j++) printf "-";
            printf "  ";
        }
        printf "\n";
        
        # 打印数据行
        for (i = 1; i <= NR; i++) {
            for (j = 1; j <= num_cols; j++) {
                printf "%-" widths[j] "s  ", data[i, j];
            }
            printf "\n";
        }
        
        # 打印分隔线
        for (i = 1; i <= num_cols; i++) {
            for (j = 1; j <= widths[i]; j++) printf "-";
            printf "  ";
        }
        printf "\n";
        
        # 打印总计行
        printf "%-" widths[1] "s  ", total_label;
        printf "%-" widths[2] "s  ", "";
        printf "%-" widths[3] "s  ", "";
        printf "%-" widths[4] "s  ", total_chars;
        printf "%-" widths[5] "s  ", total_words;
        printf "%-" widths[6] "s  ", total_tokens;
        printf "%-" widths[7] "s  ", total_size;
        printf "\n";
    }
    '
    
    # 准备表格数据
    set -l table_data
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
        
        # 添加到表格数据
        set -a table_data "$filename\t$filetype\t$fileencoding\t$display_chars\t$display_words\t$display_tokens\t$display_size"
    end
    
    # 准备总计行
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
    
    # 用awk处理表格输出
    # 将数据写入临时文件 - 每行一个文件记录
    set -l temp_file (mktemp)
    for line in $table_data
        echo $line >> $temp_file
    end

    # 用awk处理数据
    awk -v file_count=$file_count \
        -v total_chars=$display_total_chars \
        -v total_words=$display_total_words \
        -v total_tokens=$display_total_tokens \
        -v total_size="$display_total_size" \
        -F "\t" $awk_script $temp_file
        
    # 清理临时文件
    rm $temp_file
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