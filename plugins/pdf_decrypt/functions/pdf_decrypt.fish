function pdf_decrypt
    # 检查是否安装了 qpdf
    if not command -v qpdf >/dev/null
        echo "qpdf 未安装。是否要安装？(y/n)"
        read -l confirm
        switch $confirm
            case y Y
                brew install qpdf
                if test $status -ne 0
                    echo "安装失败，请手动执行: brew install qpdf"
                    return 1
                end
            case '*'
                echo "请先安装 qpdf: brew install qpdf"
                return 1
        end
    end

    # 参数检查
    if test (count $argv) -lt 1
        echo "用法: pdf_decrypt [选项] 输入文件.pdf [输入文件2.pdf ...] [输出目录]"
        echo ""
        echo "选项:"
        echo "  -i, --info     显示 PDF 加密信息"
        echo "  -p 密码        使用指定密码解密"
        echo "  -s, --simple   尝试无密码解密"
        echo "  -f, --force    尝试强制破解"
        echo "  -b, --batch    批量解密模式 (与 -p 配合使用)"
        echo ""
        echo "示例:"
        echo "  pdf_decrypt -i encrypted.pdf              # 查看加密信息"
        echo "  pdf_decrypt -p 123456 in.pdf out.pdf     # 使用密码解密单个文件"
        echo "  # 批量解密示例 (请先列出PDF文件)"
        echo "  set pdfs *.pdf"
        echo "  pdf_decrypt -b -p 123456 \$pdfs decrypted/   # 批量解密到指定目录"
        echo "  pdf_decrypt -s in.pdf out.pdf            # 尝试无密码解密"
        echo "  pdf_decrypt -f in.pdf out.pdf            # 尝试强制破解"
        return 1
    end

    set -l option
    set -l password ""
    set -l input_files
    set -l output_dir
    set -l is_batch 0

    # 解析参数
    switch $argv[1]
        case -i --info
            if test (count $argv) -lt 2
                echo "错误: 未指定输入文件"
                return 1
            end
            qpdf --show-encryption $argv[2]
            return $status

        case -b --batch
            if test (count $argv) -lt 4
                echo "错误: 批量模式需要指定密码选项、输入文件和输出目录"
                return 1
            end
            if test $argv[2] != -p
                echo "错误: 批量模式目前仅支持密码解密"
                return 1
            end
            set is_batch 1
            set password $argv[3]
            set -e argv[1..3] # 移除已处理的参数
            set output_dir $argv[-1] # 最后一个参数为输出目录
            set -e argv[-1] # 移除输出目录参数
            set input_files $argv # 剩余参数为输入文件

            # 检查是否有输入文件
            if test (count $input_files) -eq 0
                echo "错误: 未找到PDF文件"
                echo "提示: 在fish中使用通配符需要先展开，例如："
                echo "  set pdfs *.pdf"
                echo "  pdf_decrypt -b -p 密码 \$pdfs output_dir/"
                return 1
            end

            # 检查输入文件是否都存在
            for f in $input_files
                if not test -f $f
                    echo "错误: 文件不存在: $f"
                    return 1
                end
            end

            # 检查并创建输出目录
            if not test -d $output_dir
                mkdir -p $output_dir
            end

            # 处理每个输入文件
            set -l success_count 0
            set -l total_count (count $input_files)

            for input_file in $input_files
                set -l output_file $output_dir/(basename $input_file)
                echo "处理文件: $input_file"
                qpdf --password=$password --decrypt $input_file $output_file
                set -l result $status
                if test $result -eq 0 -o $result -eq 3 # 0是成功，3是有警告但成功
                    set success_count (math $success_count + 1)
                    echo "✓ 解密成功: $output_file"
                else
                    echo "✗ 解密失败: $input_file"
                end
            end

            echo ""
            echo "批量处理完成: $success_count/$total_count 个文件成功解密"

        case -p
            if test (count $argv) -lt 3
                echo "错误: 密码解密需要指定密码和输入文件"
                return 1
            end
            set password $argv[2]
            set input_file $argv[3]
            if test (count $argv) -ge 4
                set output_file $argv[4]
            else
                set output_file "decrypted_"(basename $input_file)
            end
            qpdf --password=$password --decrypt $input_file $output_file
            set -l result $status
            if test $result -eq 0 -o $result -eq 3 # 0是成功，3是有警告但成功
                echo "解密成功，输出文件: $output_file"
            else
                echo "解密失败，可能密码错误"
                return 1
            end

        case -s --simple
            if test (count $argv) -lt 2
                echo "错误: 未指定输入文件"
                return 1
            end
            set input_file $argv[2]
            if test (count $argv) -ge 3
                set output_file $argv[3]
            else
                set output_file "decrypted_"(basename $input_file)
            end
            qpdf --decrypt --password="" $input_file $output_file
            if test $status -eq 0
                echo "无密码解密成功，输出文件: $output_file"
            else
                echo "无密码解密失败，可能需要密码"
                return 1
            end

        case -f --force
            if test (count $argv) -lt 2
                echo "错误: 未指定输入文件"
                return 1
            end
            set input_file $argv[2]
            if test (count $argv) -ge 3
                set output_file $argv[3]
            else
                set output_file "decrypted_"(basename $input_file)
            end
            echo "尝试强制破解，这可能需要一些时间..."
            qpdf --password-is-hex-key --password=00000000000000000000000000000000 --decrypt $input_file $output_file
            if test $status -eq 0
                echo "强制破解成功，输出文件: $output_file"
            else
                echo "强制破解失败"
                return 1
            end

        case '*'
            echo "错误: 无效的选项"
            return 1
    end
end
