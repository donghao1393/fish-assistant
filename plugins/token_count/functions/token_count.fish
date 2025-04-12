function token_count --description 'Count tokens in text files for LLM interaction'
    if test (count $argv) -eq 0
        echo "Usage: token_count <file_path> [file_path...]" >&2
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

        # 解析结果
        set -l type (echo $result | string match -r '"type":\s*"([^"]*)"' | tail -n 1)
        set -l encoding (echo $result | string match -r '"encoding":\s*"([^"]*)"' | tail -n 1)
        set -l chars (echo $result | string match -r '"chars":\s*(\d+)' | tail -n 1)
        set -l words (echo $result | string match -r '"words":\s*(\d+)' | tail -n 1)
        set -l tokens (echo $result | string match -r '"tokens":\s*(\d+)' | tail -n 1)
        set -l size (echo $result | string match -r '"size":\s*(\d+)' | tail -n 1)

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
        echo "文件分析结果："
        echo "文件类型: $type"
        echo "编码: $encoding"
        echo "字符数: $chars"
        echo "单词数: $words"
        echo "Token数: $tokens"
        echo "文件大小: $size bytes"
        return 0
    end

    # 多文件模式：输出表格
    echo "文件统计表格："
    # 表头
    echo -e "文件\t类型\t编码\t字符数\t单词数\tToken数\t大小(bytes)"
    echo -e "----\t----\t----\t-------\t-------\t-------\t-----------"
    
    # 打印每个文件的结果
    for result in $results
        echo -e $result
    end
    
    # 打印总计
    echo -e "----\t----\t----\t-------\t-------\t-------\t-----------"
    echo -e "总计($file_count文件)\t\t\t$total_chars\t$total_words\t$total_tokens\t$total_size"
end