function pdf_decrypt
    # 检查是否安装了 qpdf
    if not command -v qpdf > /dev/null
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
        echo "用法: pdf_decrypt [选项] 输入文件.pdf [输出文件.pdf]"
        echo ""
        echo "选项:"
        echo "  -i, --info     显示 PDF 加密信息"
        echo "  -p 密码        使用指定密码解密"
        echo "  -s, --simple   尝试无密码解密"
        echo "  -f, --force    尝试强制破解"
        echo ""
        echo "示例:"
        echo "  pdf_decrypt -i encrypted.pdf           # 查看加密信息"
        echo "  pdf_decrypt -p 123456 in.pdf out.pdf  # 使用密码解密"
        echo "  pdf_decrypt -s in.pdf out.pdf         # 尝试无密码解密"
        echo "  pdf_decrypt -f in.pdf out.pdf         # 尝试强制破解"
        return 1
    end

    set -l option
    set -l password ""
    set -l input_file
    set -l output_file

    # 解析参数
    switch $argv[1]
        case -i --info
            if test (count $argv) -lt 2
                echo "错误: 未指定输入文件"
                return 1
            end
            qpdf --show-encryption $argv[2]
            return $status

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
            if test $status -eq 0
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
