# 在本地临时生成唯一文件名,用于视频和字幕文件的符号链接
function __play3d_generate_temp_filename
    set prefix $argv[1]  # 前缀：play_shipin_ 或 play_zimu_
    set timestamp (date '+%y%m%d%H%M%S')
    set suffix $argv[2]  # 后缀：.mkv、.srt 等
    echo "$prefix$timestamp$suffix"
end

# 转换字幕为UTF-8编码并创建临时链接
function __play3d_convert_subtitle_to_utf8
    set input_file $argv[1]
    set input_file (string replace -r '^\./' '' -- $input_file)
    
    if not test -f "$input_file"
        echo "错误：文件不存在 - $input_file" >&2
        return 1
    end
    if not string match -q "*.srt" "$input_file"
        echo "错误：不是 .srt 文件 - $input_file" >&2
        return 1
    end
    
    set file_info (file -I "$input_file")
    set current_charset (string match -r 'charset=([^[:space:]]+)' $file_info)[2]
    
    # 生成临时字幕文件名
    set temp_srt (__play3d_generate_temp_filename "play_zimu_" ".srt")
    
    if test "$current_charset" = utf-8
        # 如果已是 UTF-8，创建符号链接
        ln -s (realpath "$input_file") "$temp_srt"
        echo -n $temp_srt
        return 0
    end
    
    # 尝试转换编码
    if test "$current_charset" = unknown-8bit -o "$current_charset" = binary
        if iconv -f gb18030 -t utf-8 "$input_file" >"$temp_srt" 2>/dev/null
            echo "已转换为 UTF-8" >&2
            echo -n $temp_srt
            return 0
        else
            echo "错误：无法确定原始编码或转换失败" >&2
            rm -f "$temp_srt" 2>/dev/null
            return 1
        end
    else
        if iconv -f "$current_charset" -t utf-8 "$input_file" >"$temp_srt" 2>/dev/null
            echo "已转换为 UTF-8" >&2
            echo -n $temp_srt
            return 0
        else
            echo "错误：转换失败" >&2
            rm -f "$temp_srt" 2>/dev/null
            return 1
        end
    end
end

# 播放3D视频的主函数
function play3d --description "播放3D视频，自动处理HSBS格式和字幕，左右两侧都显示字幕"
    if test (count $argv) -eq 0
        echo "用法: play3d <视频文件> [字幕文件]"
        return 1
    end
    
    set video_file (string replace -r '^\./' '' -- $argv[1])
    set subtitle_file ""
    set temp_files # 用于存储所有临时文件路径
    
    # 创建视频文件的符号链接
    set temp_video (__play3d_generate_temp_filename "play_shipin_" (string match -r '\.[^.]*$' "$video_file"))
    ln -s (realpath "$video_file") "$temp_video"
    set -a temp_files "$temp_video"
    
    # 处理字幕
    if test (count $argv) -ge 2
        set subtitle_file (string replace -r '^\./' '' -- $argv[2])
    else
        set file_base (string replace -r '\[.*\]' '' -- $video_file | string replace -r '\.[^.]*$' '')
        set dir_path (dirname $video_file)
        if test "$dir_path" = "."
            set auto_srt "$file_base.srt"
        else
            set auto_srt "$dir_path/$file_base.srt"
        end
        if test -f $auto_srt
            set subtitle_file $auto_srt
        end
    end
    
    if test -n "$subtitle_file"
        set utf8_subtitle (__play3d_convert_subtitle_to_utf8 "$subtitle_file")
        set convert_status $status
        if test $convert_status -eq 0
            set -a temp_files "$utf8_subtitle"
            echo "视频文件: $video_file"
            echo "字幕文件: $subtitle_file"
            # 新的过滤器命令：拆分视频并在两侧都显示字幕
            set filter_complex "split=2[m1][m2];\
[m1]crop=iw/2:ih:0:0,scale=iw*2:ih,subtitles=$utf8_subtitle:charenc=utf8[left];\
[m2]crop=iw/2:ih:iw/2:0,scale=iw*2:ih,subtitles=$utf8_subtitle:charenc=utf8[right];\
[left][right]hstack"
            ffplay -vf "$filter_complex" -- "$temp_video"
        else
            echo "是否继续播放视频（无字幕）？[y/N]"
            read -l confirm
            if test "$confirm" = y -o "$confirm" = Y
                # 无字幕时的基本3D处理
                set filter_complex "split=2[m1][m2];\
[m1]crop=iw/2:ih:0:0,scale=iw*2:ih[left];\
[m2]crop=iw/2:ih:iw/2:0,scale=iw*2:ih[right];\
[left][right]hstack"
                ffplay -vf "$filter_complex" -- "$temp_video"
            end
        end
    else
        echo "视频文件: $video_file"
        # 无字幕时的基本3D处理
        set filter_complex "split=2[m1][m2];\
[m1]crop=iw/2:ih:0:0,scale=iw*2:ih[left];\
[m2]crop=iw/2:ih:iw/2:0,scale=iw*2:ih[right];\
[left][right]hstack"
        ffplay -vf "$filter_complex" -- "$temp_video"
    end
    
    # 清理所有临时文件
    for temp_file in $temp_files
        unlink "$temp_file" 2>/dev/null
    end
end