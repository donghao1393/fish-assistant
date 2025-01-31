function imgconv
    # 检查参数数量
    if test (count $argv) -lt 2
        echo "使用方法:"
        echo "单个文件转换: imgconv <源文件> <目标格式>"
        echo "目录批量转换: imgconv <源目录> <源格式> <目标格式>"
        echo "例如:"
        echo "  imgconv image.png jpg"
        echo "  imgconv ~/Pictures png jpg"
        echo "支持的格式: jpg, png, tiff, gif, bmp, jp2 等"
        return 1
    end

    # 支持的格式列表
    set -l supported_formats jpg jpeg png gif tiff tif bmp jp2

    # 检查是文件还是目录
    if test -f $argv[1]
        # 单文件模式
        set -l source_file $argv[1]
        set -l target_format (string lower $argv[2])

        # 检查目标格式是否支持
        if not contains $target_format $supported_formats
            echo "错误: 不支持的目标格式 '$target_format'"
            return 1
        end

        # 构建目标文件路径
        set -l filename (path change-extension '' $source_file)
        set -l target_file "$filename.$target_format"

        echo "转换: $source_file → $target_file"
        if sips -s format $target_format $source_file --out $target_file 2>/dev/null
            echo "✓ 转换成功"
        else
            echo "✗ 转换失败"
        end
    else if test -d $argv[1]
        # 目录模式
        if test (count $argv) -lt 3
            echo "错误: 目录模式需要指定源格式和目标格式"
            return 1
        end

        set -l source_dir $argv[1]
        set -l source_format (string lower $argv[2])
        set -l target_format (string lower $argv[3])

        # 检查格式是否支持
        if not contains $source_format $supported_formats
            echo "错误: 不支持的源格式 '$source_format'"
            return 1
        end
        if not contains $target_format $supported_formats
            echo "错误: 不支持的目标格式 '$target_format'"
            return 1
        end

        # 遍历目录
        for source_file in $source_dir/*.$source_format
            if test -f $source_file
                set -l filename (path change-extension '' $source_file)
                set -l target_file "$filename.$target_format"

                echo "转换: $source_file → $target_file"
                if sips -s format $target_format $source_file --out $target_file 2>/dev/null
                    echo "✓ 转换成功"
                else
                    echo "✗ 转换失败"
                end
            end
        end
    else
        echo "错误: '$argv[1]' 既不是文件也不是目录"
        return 1
    end

    echo "所有转换任务完成！"
end