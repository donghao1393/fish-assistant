function codepack -d "Pack project code files for AI analysis"
    argparse 'o/output=' a/all -- $argv
    or return

    if set -q _flag_output
        set output_file $_flag_output
    else
        set output_file "codepack.md"
    end

    if not string match -q "*.md" -- $output_file
        set output_file "$output_file.md"
    end

    set binary_extensions .jpg .jpeg .png .gif .bmp .webp .svg .ico .tiff .json .yaml \
        .mp3 .mp4 .wav .avi .mov .mkv .flv .zip .tar .gz .rar \
        .pdf .doc .docx .xls .xlsx .ppt .pptx .bin .exe .dll .so \
        .class .pyc .pyo .o .a .lib .hex .bin \
        .node-cache .tree-sitter-cache

    # 设置文件大小限制（5MB）和函数分析超时（30s）
    set size_limit 5242880
    set timeout 30

    if git rev-parse --git-dir >/dev/null 2>&1
        set files (git ls-files)
        set repo_type "Git仓库"
    else if set -q _flag_all
        set files (find . -type f | string replace -r '^\./' '')
        set repo_type "普通目录（递归扫描）"
    else
        set files (ls)
        set repo_type "当前目录"
    end

    set project_name (basename (pwd))
    set current_date (date "+%Y-%m-%d %H:%M:%S")
    set total_files (count $files)
    set project_description ""
    if test -f package.json
        set project_description (jq -r '.description // empty' package.json)
    end

    echo -n >$output_file

    echo "# 项目概览" >>$output_file
    echo "项目名称: $project_name" >>$output_file
    echo "目录类型: $repo_type" >>$output_file
    echo "生成时间: $current_date" >>$output_file
    if test -n "$project_description"
        echo "项目描述: $project_description" >>$output_file
    end
    echo "文件总数: $total_files" >>$output_file
    echo "" >>$output_file

    # 文件依赖关系部分保持不变...
    echo "# 文件依赖关系" >>$output_file
    echo "```mermaid" >>$output_file
    echo "flowchart TD" >>$output_file
    echo "    %% 文件依赖关系图" >>$output_file

    for file in $files
        set extension (string lower (path extension $file))
        if contains $extension $binary_extensions; or test (basename $file) = ".gitignore"
            continue
        end

        if test -f $file
            set file_size (gstat -c%s $file)
            if test $file_size -gt $size_limit
                echo "跳过大文件: $file ($(math $file_size / 1024 / 1024)MB > $(math $size_limit / 1024 / 1024)MB)" >>$output_file
                continue
            end

            switch $extension
                case .js .ts .jsx .tsx
                    rg -e "^import .+ from ['\"]\..*['\"]|^require\(['\"]\..*['\"]\)" $file 2>/dev/null | while read -l line
                        set source_file (basename $file)
                        set target_file (echo $line | grep -o "'.*'" | tr -d "'")
                        echo "    $source_file --> $target_file" >>$output_file
                    end
                case .py
                    rg -e "^from \..* import|^import \." $file 2>/dev/null | while read -l line
                        set source_file (basename $file)
                        set target_file (echo $line | awk '{print $2}' | tr -d '.')
                        echo "    $source_file --> $target_file" >>$output_file
                    end
                case .rs
                    rg -e "^use (crate|super|self)::" $file 2>/dev/null | while read -l line
                        set source_file (basename $file)
                        set target_file (echo $line | cut -d':' -f2- | tr -d ';')
                        echo "    $source_file --> $target_file" >>$output_file
                    end
                case .go
                    rg -e '^import \(' -A 100 $file 2>/dev/null | rg -e '".*"' | while read -l line
                        set source_file (basename $file)
                        set target_file (echo $line | tr -d '"' | string trim)
                        if string match -q "./*" -- $target_file
                            echo "    $source_file --> $target_file" >>$output_file
                        end
                    end
                case .rb
                    rg -e "^require_relative|^require ['\"]\." $file 2>/dev/null | while read -l line
                        set source_file (basename $file)
                        set target_file (echo $line | grep -o "'.*'" | tr -d "'")
                        echo "    $source_file --> $target_file" >>$output_file
                    end
                case .java
                    rg -e "^import" $file 2>/dev/null | rg -v "^import static" | while read -l line
                        set source_file (basename $file)
                        set target_file (echo $line | awk '{print $2}' | tr -d ';')
                        if string match -q ".*\.*" -- $target_file
                            echo "    $source_file --> $target_file" >>$output_file
                        end
                    end
            end
        end
    end
    echo "```" >>$output_file
    echo "" >>$output_file

    # 函数调用关系部分
    echo "# 函数调用关系" >>$output_file
    echo "```mermaid" >>$output_file
    echo "flowchart TD" >>$output_file
    echo "    %% 函数调用关系图" >>$output_file
    echo "    subgraph 函数调用" >>$output_file

    # 使用临时文件存储所有关系
    set -l temp_relations (mktemp)

    for file in $files
        set extension (string lower (path extension $file))
        # 只处理支持的文件类型
        switch $extension
            case .js .jsx .ts .tsx
                if test -f $file
                    set file_size (gstat -c%s $file)
                    if test $file_size -gt $size_limit
                        continue
                    end

                    if which node >/dev/null 2>&1
                        set result (timeout $timeout node $SCRIPTS_DIR/fish/plugins/codepack/ts-parser/tree-sitter-parser.js $file 2>/dev/null)
                        if test $status -eq 124 # timeout 退出码
                            echo "注意: 分析 $file 时超时" >>$output_file
                            continue
                        end

                        # 只有当结果不是空数组时才处理
                        if test "$result" != "[]"
                            # 调整 jq 输出格式，确保每行一个关系
                            for relation in (echo $result | jq -r '.[] | "        \(.[0] | split(": ")[1]) --> \(.[1])"')
                                echo $relation >>$temp_relations
                            end
                        end
                    end
                end
        end
    end

    # 批量处理所有关系，去重并保持格式
    if test -f $temp_relations; and test -s $temp_relations
        sort -u $temp_relations >>$output_file
    end

    echo "    end" >>$output_file
    echo "```" >>$output_file
    echo "" >>$output_file

    # 代码复杂度分析部分
    echo "# 代码复杂度分析" >>$output_file
    for file in $files
        set extension (string lower (path extension $file))
        if contains $extension $binary_extensions; or test (basename $file) = ".gitignore"
            continue
        end

        if test -f $file
            set file_size (gstat -c%s $file)
            if test $file_size -gt $size_limit
                continue
            end

            set conditions (rg -c -e "if|while|for|switch|&&|\|\|" $file 2>/dev/null | string match -r '[0-9]+')
            set conditions (test -n "$conditions" && echo $conditions || echo "0")

            set functions (rg -c -e "function|def |class |fn " $file 2>/dev/null | string match -r '[0-9]+')
            set functions (test -n "$functions" && echo $functions || echo "0")

            set lines (wc -l <$file | string trim)

            set max_indent 0
            cat $file | while read -l line
                set spaces (string match -r '^[[:space:]]*' -- "$line" | string length)
                set indent (math "$spaces/4")
                if test $indent -gt $max_indent
                    set max_indent $indent
                end
            end

            echo "## $file 复杂度指标" >>$output_file
            echo "- 条件语句数: $conditions" >>$output_file
            echo "- 函数/类数量: $functions" >>$output_file
            echo "- 最大嵌套深度: $max_indent" >>$output_file
            echo "- 代码行数: $lines" >>$output_file
            if test $conditions -gt 20
                echo "⚠️ 条件语句较多，建议考虑重构" >>$output_file
            end
            if test $max_indent -gt 5
                echo "⚠️ 嵌套层级较深，建议考虑重构" >>$output_file
            end
            echo "" >>$output_file
        end
    end

    # 源代码部分
    echo "# 源代码" >>$output_file
    for file in $files
        set extension (string lower (path extension $file))
        if contains $extension $binary_extensions; or test (basename $file) = ".gitignore"
            continue
        end

        if test -f $file
            set file_size (gstat -c%s $file)
            if test $file_size -gt $size_limit
                echo "注意: $file 超过大小限制 (5MB)，已跳过" >>$output_file
                continue
            end

            echo "## $file" >>$output_file

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

            cat $file >>$output_file
            echo '```' >>$output_file
            echo "" >>$output_file
        end
    end

    echo "代码打包完成，已写入到 $output_file"
    set processed_files (count $files)
    echo "共处理了 $processed_files 个文件"
end
