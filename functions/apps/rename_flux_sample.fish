function rename_flux_sample
    # 解析参数
    argparse 'v/verbose' -- $argv
    
    # 检查 gstat 命令
    if not command -q gstat
        echo "错误：需要安装 gstat 命令"
        echo "提示：在 macOS 上可以使用 'brew install coreutils' 安装"
        return 1
    end

    set -l txt_file "sample.txt"
    set -l jpeg_file "sample.jpeg"
    
    # 详细模式下显示初始信息
    if set -q _flag_verbose
        echo "开始处理..."
        echo "文本文件：$txt_file"
        echo "图片文件：$jpeg_file"
    end
    
    # 检查文件是否存在
    if not test -f $txt_file
        echo "错误：找不到文件 $txt_file"
        return 1
    end
    
    if not test -f $jpeg_file
        echo "错误：找不到文件 $jpeg_file"
        return 1
    end
    
    # 生成新文件名
    if set -q _flag_verbose
        echo "计算文本文件 MD5..."
    end
    set -l md5sum (md5 $txt_file | awk '{print $NF}')
    
    if set -q _flag_verbose
        echo "获取图片文件时间戳..."
    end
    set -l timestamp (gstat --format=%W $jpeg_file)
    
    set -l new_jpeg_name "$md5sum.t$timestamp.jpeg"
    set -l new_txt_name "$md5sum.txt"
    
    if set -q _flag_verbose
        echo "新文件名："
        echo "  → $new_jpeg_name"
        echo "  → $new_txt_name"
    end
    
    # 检查目标文件是否已存在
    if test -f $new_jpeg_name
        echo "警告：文件 $new_jpeg_name 已存在"
        read -P "是否覆盖？[y/N] " confirm
        if test "$confirm" != "y" -a "$confirm" != "Y"
            echo "操作已取消"
            return 1
        end
    end
    
    if test -f $new_txt_name
        echo "警告：文件 $new_txt_name 已存在"
        read -P "是否覆盖？[y/N] " confirm
        if test "$confirm" != "y" -a "$confirm" != "Y"
            echo "操作已取消"
            return 1
        end
    end
    
    # 执行重命名
    if mv $jpeg_file $new_jpeg_name
        and mv $txt_file $new_txt_name
        echo "✓ 文件重命名成功："
        echo "  $jpeg_file -> $new_jpeg_name"
        echo "  $txt_file -> $new_txt_name"
    else
        echo "× 重命名过程中发生错误"
        return 1
    end
end