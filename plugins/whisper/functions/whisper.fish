function whisper --description "一键音视频转录文字"
    argparse h/help s/srt -- $argv
    or return

    if set -ql _flag_help
        echo "用法: whisper [-s/--srt] <音频或视频文件路径>"
        echo "选项:"
        echo "  -s, --srt      输出 SRT 格式字幕文件（默认为 TXT）"
        echo "  -h, --help     显示此帮助信息"
        return 0
    end

    # 检查是否提供了文件参数
    if not set -q argv[1]
        echo "错误: 请提供音频或视频文件路径"
        echo "使用 --help 查看帮助信息"
        return 1
    end

    set -l media_file $argv[1]

    if not test -f "$media_file"
        echo "错误: 文件 '$media_file' 不存在"
        return 1
    end

    # 激活 Conda 环境
    conda activate whisper

    if test $status -ne 0
        echo "错误: 无法激活 whisper 环境"
        return 1
    end

    # 构建命令：总是使用 -v，根据 srt 标志决定格式
    if set -ql _flag_srt
        python $SCRIPTS_DIR/fish/plugins/transcribe.py "$media_file" --model medium -v --format srt
    else
        python $SCRIPTS_DIR/fish/plugins/transcribe.py "$media_file" --model medium -v
    end

    # 保存执行状态
    set -l status_code $status

    # 返回到之前的环境
    conda deactivate

    # 返回执行状态
    return $status_code
end
