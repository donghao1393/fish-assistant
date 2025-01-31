function inspect -a output_file
    # 检查参数数量
    if test (count $argv) -lt 1
        echo "用法: inspect <输出文件>"
        echo "示例: inspect inspected_files.txt"
        return 1
    end

    # 定义需要过滤掉的文件类型
    set binary_extensions .jpg .jpeg .png .gif .bmp .webp .svg .ico .tiff .json .yaml \
                         .mp3 .mp4 .wav .avi .mov .mkv .flv .zip .tar .gz .rar \
                         .pdf .doc .docx .xls .xlsx .ppt .pptx .bin .exe .dll .so \
                         .class .pyc .pyo .o .a .lib .hex .bin

    # 定义文件大小限制（5MB）
    set size_limit 5242880

    # 获取项目信息
    set project_name (basename (pwd))
    set current_date (date "+%Y-%m-%d %H:%M:%S")
    set total_files (git ls-files | wc -l | string trim)
    set project_description (test -f package.json && jq -r '.description // empty' package.json)
    or set project_description ""

    # 初始化输出文件
    echo -n >$output_file

    # 写入项目信息
    echo "# 项目概览" >>$output_file
    echo "项目名称: $project_name" >>$output_file
    echo "生成时间: $current_date" >>$output_file
    if test -n "$project_description"
        echo "项目描述: $project_description" >>$output_file
    end
    echo "文件总数: $total_files" >>$output_file
    echo "" >>$output_file
    echo "这是一个供AI大模型阅览的项目代码集合文件。以下内容包含了项目的相关代码、依赖关系分析和文件结构。" >>$output_file
    echo "" >>$output_file

    # 生成依赖关系图
    echo "# 文件依赖关系" >>$output_file
    echo '```mermaid' >>$output_file
    echo 'graph TD' >>$output_file

    # 分析文件依赖关系
    for file in (git ls-files)
        set extension (string lower (path extension $file))
        if contains $extension $binary_extensions
            continue
        end

        # 检查文件大小
        set file_size (gstat -c%s $file)
        if test $file_size -gt $size_limit
            continue
        end

        # 根据文件类型分析依赖
        switch $extension
            case .js .ts .jsx .tsx
                # JavaScript/TypeScript 依赖分析
                grep -E "^import .+ from ['\"]\..*['\"]|^require\(['\"]\..*['\"]\)" $file | while read -l line
                    set source_file (basename $file)
                    set target_file (echo $line | grep -o "'.*'" | tr -d "'")
                    echo "    $source_file --> $target_file" >>$output_file
                end
            case .py
                # Python 依赖分析
                grep -E "^from \..* import|^import \." $file | while read -l line
                    set source_file (basename $file)
                    set target_file (echo $line | awk '{print $2}' | tr -d '.')
                    echo "    $source_file --> $target_file" >>$output_file
                end
        end
    end
    echo '```' >>$output_file
    echo "" >>$output_file

    # 写入文件目录
    echo "# 文件目录" >>$output_file
    for file in (git ls-files)
        set extension (string lower (path extension $file))
        if not contains $extension $binary_extensions
            echo "- $file" >>$output_file
        end
    end
    echo "" >>$output_file

    # 写入文件内容
    echo "# 文件内容" >>$output_file
    for file in (git ls-files)
        set extension (string lower (path extension $file))
        if contains $extension $binary_extensions
            continue
        end

        # 检查文件大小
        set file_size (gstat -c%s $file)
        if test $file_size -gt $size_limit
            echo "注意: $file 超过大小限制 (5MB)，已跳过" >>$output_file
            continue
        end

        # 获取文件信息
        set file_lines (wc -l <$file | string trim)
        set file_created (gstat -c%w $file)
        set file_modified (gstat -c%y $file)

        echo "" >>$output_file
        echo "## $file" >>$output_file
        echo "- 行数: $file_lines" >>$output_file
        echo "- 创建时间: $file_created" >>$output_file
        echo "- 修改时间: $file_modified" >>$output_file
        echo "" >>$output_file

        # 根据文件类型添加语言标识
        switch $extension
            case .js .jsx
                echo '```javascript' >>$output_file
            case .ts .tsx
                echo '```typescript' >>$output_file
            case .py
                echo '```python' >>$output_file
            case .rb
                echo '```ruby' >>$output_file
            case .go
                echo '```go' >>$output_file
            case .rs
                echo '```rust' >>$output_file
            case .java
                echo '```java' >>$output_file
            case .cpp .cc .h .hpp
                echo '```cpp' >>$output_file
            case .c
                echo '```c' >>$output_file
            case .sh .fish .bash
                echo '```bash' >>$output_file
            case '*'
                echo '```' >>$output_file
        end

        # 写入文件内容
        cat $file >>$output_file
        echo '```' >>$output_file
        echo "" >>$output_file
    end

    echo "文件整合完成，已写入到 $output_file"
    # 统计收录的文件数量
    set processed_files (git ls-files | grep -vE "$(string join '|' $binary_extensions)\$" | wc -l | string trim)
    echo "共处理了 $processed_files 个文件"
end
