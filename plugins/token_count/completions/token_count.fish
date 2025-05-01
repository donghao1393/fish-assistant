complete -c token_count -f

function __token_count_list_supported_files
    # 获取当前目录下的文件和目录
    # 使用文件扩展名进行初步过滤，以提高性能

    # 常见支持的文本文件扩展名
    set -l text_extensions txt md markdown rst py js ts html css xml json yaml yml toml ini conf sh bash zsh fish php rb pl sql c cpp h hpp java go cs scala kt swift rs d jsx tsx vue svelte scss sass less csv tsv log

    # 文档类文件扩展名
    set -l doc_extensions pdf doc docx ppt pptx xls xlsx

    # 所有支持的文件扩展名
    set -l all_extensions $text_extensions $doc_extensions

    # 获取当前目录下所有文件和目录
    set -l matched_items

    # 使用ls而不是循环，加快速度
    set -l all_items (command ls -a 2>/dev/null)

    # 先添加目录
    for item in $all_items
        if test -d $item; and not string match -q ".*" $item # 排除隐藏目录
            set -a matched_items $item/
        end
    end

    # 按照优先级从text_extensions开始匹配文件
    for ext in $text_extensions
        for file in $all_items
            # 如果文件名以这个扩展名结尾且之前未匹配
            if string match -q "*.$ext" $file && not contains $file $matched_items && test -f $file
                set -a matched_items $file
            end
        end
    end

    # 然后匹配doc_extensions
    for ext in $doc_extensions
        for file in $all_items
            if string match -q "*.$ext" $file && not contains $file $matched_items && test -f $file
                set -a matched_items $file
            end
        end
    end

    # 返回匹配的文件和目录列表
    for item in $matched_items
        echo $item
    end
end

# 为 token_count 命令添加补全规则
complete -c token_count -f -a "(__token_count_list_supported_files)"

# 添加选项补全
complete -c token_count -s h -l human-readable -d "使用人类可读格式显示数字（如K/M/G等）"
complete -c token_count -s v -l verbose -d "显示详细处理信息和警告"
complete -c token_count -s r -l recursive -d "递归处理目录中的文件"
complete -c token_count -s e -l exclude -d "排除匹配指定模式的文件" -x
complete -c token_count -l max-files -d "限制处理的最大文件数（默认1000）" -x
complete -c token_count -l help -d "显示帮助信息"
