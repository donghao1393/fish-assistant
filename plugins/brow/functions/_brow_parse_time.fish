function _brow_parse_time --argument-names iso_time
    # 解析ISO 8601格式的时间字符串为Unix时间戳
    # 支持格式: 2024-04-16T12:34:56Z
    
    if test -z "$iso_time"
        echo 0
        return 1
    end
    
    # 尝试使用macOS的date命令
    set -l timestamp (date -jf "%Y-%m-%dT%H:%M:%SZ" "$iso_time" +%s 2>/dev/null)
    
    # 如果成功，返回结果
    if test $status -eq 0
        echo $timestamp
        return 0
    end
    
    # 如果失败，尝试使用Linux的date命令
    set -l timestamp (date -d "$iso_time" +%s 2>/dev/null)
    
    # 如果成功，返回结果
    if test $status -eq 0
        echo $timestamp
        return 0
    end
    
    # 如果两种方法都失败，手动解析
    # 格式: 2024-04-16T12:34:56Z
    set -l year (echo $iso_time | cut -d'-' -f1)
    set -l month (echo $iso_time | cut -d'-' -f2)
    set -l day (echo $iso_time | cut -d'-' -f3 | cut -dT -f1)
    set -l hour (echo $iso_time | cut -dT -f2 | cut -d: -f1)
    set -l minute (echo $iso_time | cut -d: -f2)
    set -l second (echo $iso_time | cut -d: -f3 | cut -dZ -f1)
    
    # 使用GNU date命令的另一种格式
    set -l timestamp (date -d "$year-$month-$day $hour:$minute:$second" +%s 2>/dev/null)
    
    if test $status -eq 0
        echo $timestamp
        return 0
    end
    
    # 如果所有方法都失败，返回0
    echo 0
    return 1
end
