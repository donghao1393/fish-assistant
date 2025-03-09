complete -c token_count -f

function __token_count_list_supported_files
    # 获取当前目录下的所有文件
    for file in *.*
        # 使用 file 命令检查文件类型
        set -l file_type (command file -b --mime-type "$file")
        # 如果是支持的文件类型，就添加到建议列表中
        if string match -q "text/*" -- "$file_type" || \
           string match -q "application/json" -- "$file_type" || \
           string match -q "application/x-*script" -- "$file_type" || \
           string match -q "application/xml" -- "$file_type" || \
           string match -q "application/pdf" -- "$file_type" || \
           string match -q "application/msword" -- "$file_type" || \
           string match -q "application/vnd.openxmlformats-officedocument.*" -- "$file_type"
            echo $file
        end
    end
end

# 为 token_count 命令添加补全规则
complete -c token_count -f -a "(__token_count_list_supported_files)"
