#!/usr/bin/env fish

function show_help
    echo "用法: "(status filename)" SOURCE_IP SOURCE_USER [SOURCE_PASSWORD]"
    echo "从旧的Mac迁移用户文件夹到新Mac，保留所有原始时间戳等信息"
    echo ""
    echo "参数:"
    echo "  SOURCE_IP       旧Mac的IP地址"
    echo "  SOURCE_USER     旧Mac的用户名"
    echo "  SOURCE_PASSWORD 可选: 旧Mac的密码（不提供则需要手动输入）"
    echo ""
    echo "选项:"
    echo "  --bwlimit=KBPS  限制带宽，单位为KB/s"
    echo "  --exclude=PATTERN 排除匹配的文件或目录，可多次使用"
    echo ""
    echo "示例:"
    echo "  "(status filename)" 192.168.1.100 john.doe"
    echo "  "(status filename)" 192.168.1.100 john.doe --bwlimit=1000 --exclude='.DS_Store' --exclude='node_modules'"
end

# 解析命令行选项
set -l options h/help 'b/bwlimit=' 'e/exclude=+'
argparse $options -- $argv 2>/dev/null
or begin
    show_help
    exit 1
end

if set -q _flag_help
    show_help
    exit 0
end

# 检查基本参数
if test (count $argv) -lt 2; or test (count $argv) -gt 3
    show_help
    exit 1
end

set source_ip $argv[1]
set source_user $argv[2]
set source_pass ""
if test (count $argv) -eq 3
    set source_pass $argv[3]
end

# 默认要同步的文件夹列表（macOS的标准用户目录）
set default_folders Documents Downloads Desktop Pictures Music Movies Library Applications

# 询问用户是否要自定义同步文件夹
echo "默认同步的文件夹: "(string join ', ' $default_folders)
read -P "是否要自定义同步文件夹列表？[y/N] " customize_folders
set folders $default_folders

if test "$customize_folders" = y; or test "$customize_folders" = Y
    set -l custom_folders
    echo "请输入要同步的文件夹名称（每行一个，直接回车结束）："
    while read -P "文件夹名称: " folder
        if test -z "$folder"
            break
        end
        set -a custom_folders $folder
    end
    if test (count $custom_folders) -gt 0
        set folders $custom_folders
    end
end

# 创建日志目录和文件
set log_dir $HOME/.logs
set timestamp (date +"%Y%m%d_%H%M%S")
set log_file $log_dir/mac_migrate_$timestamp.log

if not test -d $log_dir
    mkdir -p $log_dir
end

# 记录日志的函数
function log
    echo (date +"%Y-%m-%d %H:%M:%S")" $argv" | tee -a $log_file
end

log "开始迁移用户数据"
log "源主机: $source_ip"
log "源用户: $source_user"
log "同步文件夹: "(string join ', ' $folders)

# 测试SSH连接
if not ssh -o BatchMode=yes -o ConnectTimeout=5 "$source_user@$source_ip" echo "SSH连接测试成功" 2>/dev/null
    log "错误: 无法连接到源主机 $source_ip"
    echo "请确保："
    echo "1. 源主机已开启远程登录（系统设置 -> 共享 -> 远程登录）"
    echo "2. IP地址正确"
    echo "3. 网络连接正常"
    exit 1
end

# 构建rsync选项
set rsync_opts -avP --partial --partial-dir=.rsync-partial # --delete

# 添加带宽限制
if set -q _flag_bwlimit
    set -a rsync_opts --bwlimit=$_flag_bwlimit
    log "带宽限制: $_flag_bwlimit KB/s"
end

# 添加排除项
if set -q _flag_exclude
    for pattern in $_flag_exclude
        set -a rsync_opts --exclude=$pattern
    end
    log "排除项: "(string join ', ' $_flag_exclude)
end

# 为每个文件夹执行rsync
for folder in $folders
    set source_path "/Users/$source_user/$folder/"
    set target_path "$HOME/$folder/"

    # 确保目标目录存在
    if not test -d $target_path
        mkdir -p $target_path
    end

    log "正在同步 $folder ..."

    # 使用rsync进行同步
    # -a: 归档模式，保留所有元数据
    # -v: 详细输出
    # -P: 显示进度
    # --delete: 删除目标端不存在于源端的文件
    # --partial: 保留部分传输的文件，方便断点续传
    # --partial-dir: 指定用于存放部分传输文件的目录
    rsync $rsync_opts \
        "$source_user@$source_ip:$source_path" \
        "$target_path" 2>&1 | tee -a $log_file

    if test $status -ne 0
        log "警告: $folder 同步过程中出现错误"
    end
end

log "迁移完成"
echo "详细日志已保存到: $log_file"

