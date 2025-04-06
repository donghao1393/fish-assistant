#!/usr/bin/env fish

function dfm --description 'Dotfiles Manager - 管理配置文件'
    set -l dfm_version "1.0.0"
    # set -l repo_path (realpath (dirname (status filename)))
    set -l repo_path $DOTFILES_PATH
    set -l home_path ~
    
    if test (count $argv) -eq 0
        _dfm_help
        return 1
    end
    
    # 解析全局选项
    set -l options 'f/force' 'h/help' 'o/only=' 'c/copy' 'n/no-backup' 'r/restore' 's/skip-git-check'
    argparse $options -- $argv
    set -l has_force_flag $status
    
    # 解析全局选项
    set -l options 'f/force' 'h/help' 'o/only=' 'c/copy' 'n/no-backup' 'r/restore' 's/skip-git-check'
    argparse $options -- $argv
    
    if set -q _flag_help
        _dfm_help
        return 0
    end
    
    set -l cmd $argv[1]
    set -e argv[1]
    
    switch $cmd
        case new
            set -l args
            if set -q _flag_force
                set -a args --force
            end
            if set -q _flag_copy
                set -a args --copy
            end
            if set -q _flag_only
                set -a args --only $_flag_only
            end
            _dfm_new $args $argv
        case link
            set -l args
            if set -q _flag_force
                set -a args --force
            end
            if set -q _flag_no_backup
                set -a args --no-backup
            end
            if set -q _flag_only
                set -a args --only $_flag_only
            end
            _dfm_link $args $argv
        case unlink
            set -l args
            if set -q _flag_force
                set -a args --force
            end
            if set -q _flag_restore
                set -a args --restore
            end
            _dfm_unlink $args $argv
        case sync
            set -l args
            if set -q _flag_force
                set -a args --force
            end
            _dfm_sync $args $argv
        case status
            set -l args
            if set -q _flag_force
                set -a args --force
            end
            _dfm_status $args $argv
        case init
            set -l args
            if set -q _flag_force
                set -a args --force
            end
            if set -q _flag_skip_git_check
                set -a args --skip-git-check
            end
            _dfm_init $args $argv
        case help
            _dfm_help
        case version
            echo "Dotfiles Manager v$version"
        case '*'
            echo "未知命令: $cmd"
            _dfm_help
            return 1
    end
end

# 新建配置
function _dfm_new --argument-names app
    # set -l repo_path (realpath (dirname (status filename)))
    set -l repo_path $DOTFILES_PATH
    set -l options 'f/force' 'c/copy' 'o/only='
    argparse $options -- $argv
    
    if test -z "$app"
        echo "错误: 请指定应用名称"
        echo "用法: dfm new <app_name>"
        return 1
    end
    
    # 检查应用类型
    if string match -q ".*/.+*" $app
        # 相对路径格式，如 .ssh/config
        set parent_dir (dirname $app)
        set target_path "$HOME/$app"
        set repo_path_full "$repo_path/home/$app"
        
        # 创建父目录
        mkdir -p "$repo_path/home/$parent_dir"
    else
        # 默认为.config下的应用
        set target_path "$HOME/.config/$app"
        set repo_path_full "$repo_path/.config/$app"
    end
    
    # 检查目标是否已存在
    if test -d $repo_path_full; or test -f $repo_path_full
        if not set -q _flag_force
            echo "错误: $repo_path_full 已存在，使用 --force 覆盖"
            return 1
        end
    end
    
    # 创建目录
    if test -d $target_path
        mkdir -p $repo_path_full
        echo "创建目录: $repo_path_full"
        
        # 可选复制现有配置
        if set -q _flag_copy
            if test -d $target_path
                cp -r $target_path/* $repo_path_full/ 2>/dev/null
                echo "复制配置: $target_path/* -> $repo_path_full/"
            end
        end
    else if test -f $target_path
        mkdir -p (dirname $repo_path_full)
        touch $repo_path_full
        echo "创建文件: $repo_path_full"
        
        # 可选复制现有配置
        if set -q _flag_copy
            cp $target_path $repo_path_full 2>/dev/null
            echo "复制配置: $target_path -> $repo_path_full"
        end
    else
        mkdir -p $repo_path_full
        echo "创建目录: $repo_path_full (目标尚不存在)"
    end
    
    # 创建链接
    if set -q _flag_only
        set -l only_files (string split , $_flag_only)
        
        # 如果目标是目录，则创建目录
        if test -d $repo_path_full
            for file in $only_files
                set source_file "$repo_path_full/$file"
                set target_file "$target_path/$file"
                
                # 确保父目录存在
                set parent_dir (dirname $target_file)
                if not test -d $parent_dir
                    mkdir -p $parent_dir
                end
                
                # 创建链接
                if test -e $source_file
                    _dfm_create_link $source_file $target_file
                else
                    echo "警告: $source_file 不存在，已跳过"
                end
            end
        else
            # 单文件情况
            _dfm_create_link $repo_path_full $target_path
        end
    else
        # 常规链接
        _dfm_create_link $repo_path_full $target_path
    end
end

# 链接已有配置
function _dfm_link --argument-names app
    # set -l repo_path (realpath (dirname (status filename)))
    set -l repo_path $DOTFILES_PATH
    set -l options 'f/force' 'n/no-backup' 'o/only='
    argparse $options -- $argv
    
    set -l app $argv[1]
    
    if test -z "$app"
        echo "错误: 请指定应用名称"
        echo "用法: dfm link <app_name> [--force] [--no-backup]"
        return 1
    end
    
    # 检查应用类型
    if string match -q ".*" $app; and string match -q -- ".*" (basename $app)
        # 相对路径格式，如 .ssh/config
        set parent_dir (dirname $app)
        set target_path "$HOME/$app"
        set repo_path_full "$repo_path/home/$app"
        
        # 创建父目录
        mkdir -p "$repo_path/home/$parent_dir"
    else
        # 默认为.config下的应用
        set target_path "$HOME/.config/$app"
        set repo_path_full "$repo_path/.config/$app"
    end
    
    # 检查目标是否已存在
    if test -e $repo_path_full; and not set -q _flag_only
        if not set -q _flag_force
            echo "错误: $repo_path_full 已存在，使用 --force 覆盖"
            return 1
        else
            rm -rf $repo_path_full
            echo "移除已存在的: $repo_path_full"
        end
    end
    
    # 检查源目标是否存在
    if not test -e $target_path
        echo "错误: $target_path 不存在"
        return 1
    end
    
    # 备份原始文件
    if test -L $target_path
        echo "$target_path 已经是符号链接，将直接替换"
        rm -f $target_path
    else if not set -q _flag_no_backup
        set backup_path "$target_path.bak.$(date +%Y%m%d%H%M%S)"
        cp -r $target_path $backup_path
        echo "备份原始文件: $target_path -> $backup_path"
    end
    
    # 复制文件到仓库
    if set -q _flag_only
        set -l only_files (string split , $_flag_only)
        
        if test -d $target_path
            # 确保仓库目录存在，但不删除已存在的文件
            mkdir -p $repo_path_full
            
            for file in $only_files
                set source_file "$target_path/$file"
                set dest_file "$repo_path_full/$file"
                
                if test -e $source_file
                    # 确保目标父目录存在
                    set parent_dir (dirname $dest_file)
                    if not test -d $parent_dir
                        mkdir -p $parent_dir
                    end
                    
                    # 复制文件
                    if test -d $source_file
                        cp -r $source_file $dest_file
                    else
                        cp $source_file $dest_file
                    end
                    echo "复制配置: $source_file -> $dest_file"
                    
                    # 删除原始文件
                    rm -rf $source_file
                    
                    # 创建链接
                    _dfm_create_link $dest_file $source_file
                else
                    echo "警告: $source_file 不存在，已跳过"
                end
            end
        else
            # 单文件情况
            mkdir -p (dirname $repo_path_full)
            cp $target_path $repo_path_full
            echo "复制配置: $target_path -> $repo_path_full"
            
            # 删除原始文件
            rm -rf $target_path
            
            # 创建链接
            _dfm_create_link $repo_path_full $target_path
        end
    else
        # 常规复制和链接
        if test -d $target_path
            mkdir -p $repo_path_full
            cp -r $target_path/* $repo_path_full/ 2>/dev/null
            echo "复制配置: $target_path/* -> $repo_path_full/"
        else
            mkdir -p (dirname $repo_path_full)
            cp $target_path $repo_path_full
            echo "复制配置: $target_path -> $repo_path_full"
        end
        
        # 删除原始文件
        rm -rf $target_path
        
        # 创建链接
        _dfm_create_link $repo_path_full $target_path
    end
end

# 取消链接
function _dfm_unlink --argument-names app
    set -l options 'r/restore'
    argparse $options -- $argv
    
    if test -z "$app"
        echo "错误: 请指定应用名称"
        echo "用法: dfm unlink <app_name> [--restore]"
        return 1
    end
    
    # 检查应用类型
    if string match -q ".*" $app; and string match -q -- ".*" (basename $app)
        set target_path "$HOME/$app"
    else
        set target_path "$HOME/.config/$app"
    end
    
    # 检查是否是符号链接
    if not test -L $target_path
        echo "错误: $target_path 不是符号链接"
        return 1
    end
    
    # 获取原始链接目标
    set link_target (readlink $target_path)
    echo "移除链接: $target_path -> $link_target"
    rm -f $target_path
    
    # 如果需要恢复备份
    if set -q _flag_restore
        set backup_path (string replace -r '\.bak\.[0-9]+$' '' $target_path)
        set backup_files $backup_path.bak.*
        
        if test (count $backup_files) -gt 0
            # 找到最新的备份
            set latest_backup (ls -t $backup_files | head -n 1)
            if test -n "$latest_backup"
                if test -d $latest_backup
                    mkdir -p $target_path
                    cp -r $latest_backup/* $target_path/
                else
                    cp $latest_backup $target_path
                end
                echo "恢复备份: $latest_backup -> $target_path"
            end
        else
            echo "未找到备份文件"
        end
    end
end

# 同步配置
function _dfm_sync --argument-names app
    # set -l repo_path (realpath (dirname (status filename)))
    set -l repo_path $DOTFILES_PATH
    set -l options 'f/force'
    argparse $options -- $argv
    
    echo "同步配置文件..."
    
    if test -n "$app"
        if string match -q ".*/.+*" $app
            # 特定的家目录文件
            set src_path "$repo_path/home/$app"
            set target_path "$HOME/$app"
            
            if test -e $src_path
                _dfm_create_link $src_path $target_path
            else
                echo "错误: $src_path 不存在"
                return 1
            end
        else
            # .config下的特定应用
            set src_path "$repo_path/.config/$app"
            set target_path "$HOME/.config/$app"
            
            if test -e $src_path
                _dfm_create_link $src_path $target_path
            else
                echo "错误: $src_path 不存在"
                return 1
            end
        end
    else
        # 同步所有配置
        
        # 同步.config目录下的所有应用
        for config_dir in $repo_path/.config/*/
            set dir_name (basename $config_dir)
            set target_path "$HOME/.config/$dir_name"
            _dfm_create_link $config_dir $target_path
        end
        
        # 同步.config目录下的所有文件
        for config_file in $repo_path/.config/*
            if test -f $config_file
                set file_name (basename $config_file)
                set target_path "$HOME/.config/$file_name"
                _dfm_create_link $config_file $target_path
            end
        end
        
        # 同步home目录下的所有内容
        for home_item in $repo_path/home/.*
            set item_name (basename $home_item)
            # 跳过.和..
            if test "$item_name" != "." -a "$item_name" != ".."
                set target_path "$HOME/$item_name"
                _dfm_create_link $home_item $target_path
            end
        end
        
        # 同步fish密钥(如果存在)
        if test -f $repo_path/secrets/fish_secrets.fish
            set config_fish $HOME/.config/fish/config.fish
            if test -f $config_fish
                if not grep -q "source $repo_path/secrets/fish_secrets.fish" $config_fish
                    echo "" >> $config_fish
                    echo "# 加载密钥" >> $config_fish
                    echo "source $repo_path/secrets/fish_secrets.fish" >> $config_fish
                    echo "添加密钥source到: $config_fish"
                end
            end
        end
        
        echo "同步完成!"
    end
end

# 初始化设置(新机器)
function _dfm_init
    # set -l repo_path (realpath (dirname (status filename)))
    set -l repo_path $DOTFILES_PATH
    set -l options 'f/force' 's/skip-git-check'
    argparse $options -- $argv
    
    echo "初始化dotfiles..."
    
    # 检查git-crypt状态
    if not set -q _flag_skip_git_check
        if test -d $repo_path/secrets; and begin
                set -l test_file (find $repo_path/secrets -type f | head -n 1)
                and test -n "$test_file"
                and head -c 9 "$test_file" 2>/dev/null | grep -q GITCRYPT
            end
            echo "错误: 检测到secrets目录未解密。请先运行:"
            echo "  cd $repo_path && git-crypt unlock"
            echo "或使用 --skip-git-check 选项跳过此检查。"
            return 1
        end
    end
    
    # 执行完整同步
    _dfm_sync
end

# 检查状态
function _dfm_status
    # set -l repo_path (realpath (dirname (status filename)))
    set -l repo_path $DOTFILES_PATH
    # 先收集所有已检查的项
    set -l checked_items
    
    echo "检查dotfiles状态..."
    
    # 检查.config目录下的应用
    echo "检查 .config/ 目录:"
    for config_dir in $repo_path/.config/*
        set dir_name (basename $config_dir)
        set -a checked_items $dir_name
        set target_path "$HOME/.config/$dir_name"
        
        if test -L $target_path
            set link_target (readlink $target_path)
            if test "$link_target" = "$config_dir"
                echo "  ✓ $target_path -> $link_target"
            else
                echo "  ✗ $target_path -> $link_target (应指向 $config_dir)"
            end
        else if test -e $target_path
            echo "  ✗ $target_path 存在但不是链接"
        else
            echo "  ✗ $target_path 不存在"
        end
    end
    
    # 检查.config目录下的文件
    for config_file in $repo_path/.config/*
        if test -f $config_file
            set file_name (basename $config_file)
            if not contains $file_name $checked_items
                set target_path "$HOME/.config/$file_name"
                
                if test -L $target_path
                    set link_target (readlink $target_path)
                    if test "$link_target" = "$config_file"
                        echo "  ✓ $target_path -> $link_target"
                    else
                        echo "  ✗ $target_path -> $link_target (应指向 $config_file)"
                    end
                else if test -e $target_path
                    echo "  ✗ $target_path 存在但不是链接"
                else
                    echo "  ✗ $target_path 不存在"
                end
            end
        end
    end
    
    # 检查home目录
    echo "检查家目录文件:"
    for home_item in $repo_path/home/.*
        set item_name (basename $home_item)
        # 跳过.和..
        if test "$item_name" != "." -a "$item_name" != ".."
            set target_path "$HOME/$item_name"
            
            if test -L $target_path
                set link_target (readlink $target_path)
                if test "$link_target" = "$home_item"
                    echo "  ✓ $target_path -> $link_target"
                else
                    echo "  ✗ $target_path -> $link_target (应指向 $home_item)"
                end
            else if test -e $target_path
                echo "  ✗ $target_path 存在但不是链接"
            else
                echo "  ✗ $target_path 不存在"
            end
        end
    end
    
    # 检查fish密钥
    if test -f $repo_path/secrets/fish_secrets.fish
        echo "检查fish密钥:"
        set config_fish $HOME/.config/fish/config.fish
        if test -f $config_fish
            if grep -q "source $repo_path/secrets/fish_secrets.fish" $config_fish
                echo "  ✓ fish密钥已引用"
            else
                echo "  ✗ fish密钥未引用 (config.fish需要添加)"
            end
        else
            echo "  ✗ fish配置不存在 ($config_fish)"
        end
    end
end

# 创建符号链接辅助函数
function _dfm_create_link
    set src $argv[1]
    set dest $argv[2]
    
    # 确保父目录存在
    set parent_dir (dirname $dest)
    if not test -d $parent_dir
        mkdir -p $parent_dir
        echo "创建目录: $parent_dir"
    end
    
    # 检查目标是否已存在
    if test -e $dest -o -L $dest
        if set -q _flag_force
            rm -rf $dest
            ln -sf $src $dest
            echo "覆盖链接: $dest -> $src"
        else
            echo "跳过: $dest (已存在，使用 --force 覆盖)"
        end
    else
        ln -sf $src $dest
        echo "创建链接: $dest -> $src"
    end
end

# 帮助信息
function _dfm_help
    echo "Dotfiles Manager - 管理配置文件"
    echo ""
    echo "用法: dfm <命令> [选项] [参数]"
    echo ""
    echo "命令:"
    echo "  new <app>      创建新的配置目录并设置链接"
    echo "                 选项: --copy (-c) 复制现有配置"
    echo "                 选项: --only (-o) 指定要管理的文件列表，逗号分隔"
    echo "  link <app>     将已有配置移至仓库并创建链接"
    echo "                 选项: --no-backup (-n) 不创建备份"
    echo "                 选项: --only (-o) 指定要管理的文件列表，逗号分隔"
    echo "  unlink <app>   删除链接"
    echo "                 选项: --restore (-r) 尝试恢复备份"
    echo "  sync [app]     同步所有或指定配置"
    echo "  status         检查链接状态与配置差异"
    echo "  init           在新机器上初始设置"
    echo "                 选项: --skip-git-check (-s) 跳过git-crypt检查"
    echo "  help           显示此帮助信息"
    echo "  version        显示版本信息"
    echo ""
    echo "全局选项:"
    echo "  --force (-f)   强制执行操作，覆盖已存在的文件"
    echo "  --help (-h)    显示命令帮助信息"
    echo ""
    echo "示例:"
    echo "  dfm new zellij           # 创建新的zellij配置"
    echo "  dfm new zellij --copy    # 创建并复制现有配置"
    echo "  dfm link starship        # 链接现有starship配置"
    echo "  dfm link .gitconfig      # 链接家目录下的.gitconfig"
    echo "  dfm link fish --only \"config.fish,fish_variables\"  # 仅链接特定文件"
    echo "  dfm unlink zellij        # 取消zellij配置链接"
    echo "  dfm sync                 # 同步所有配置"
    echo "  dfm status               # 检查所有配置状态"
end
