# dfm (Dotfiles Manager) 自动补全

# 定义基本命令
set -l dfm_commands new link unlink sync status init help version

# 定义选项
set -l dfm_options --force -f --help -h

# 定义特定命令的选项
set -l dfm_new_options --copy -c
set -l dfm_link_options --no-backup -n
set -l dfm_unlink_options --restore -r
set -l dfm_init_options --skip-git-check -s

# 基本命令补全
complete -f -c dfm -n "not __fish_seen_subcommand_from $dfm_commands" -a "new" -d "创建新的配置目录并设置链接"
complete -f -c dfm -n "not __fish_seen_subcommand_from $dfm_commands" -a "link" -d "将已有配置移至仓库并创建链接"
complete -f -c dfm -n "not __fish_seen_subcommand_from $dfm_commands" -a "unlink" -d "删除链接"
complete -f -c dfm -n "not __fish_seen_subcommand_from $dfm_commands" -a "sync" -d "同步所有或指定配置"
complete -f -c dfm -n "not __fish_seen_subcommand_from $dfm_commands" -a "status" -d "检查链接状态与配置差异"
complete -f -c dfm -n "not __fish_seen_subcommand_from $dfm_commands" -a "init" -d "在新机器上初始设置"
complete -f -c dfm -n "not __fish_seen_subcommand_from $dfm_commands" -a "help" -d "显示帮助信息"
complete -f -c dfm -n "not __fish_seen_subcommand_from $dfm_commands" -a "version" -d "显示版本信息"

# 全局选项
complete -f -c dfm -s f -l force -d "强制执行操作，覆盖已存在的文件"
complete -f -c dfm -s h -l help -d "显示帮助信息"

# new命令的选项
complete -f -c dfm -n "__fish_seen_subcommand_from new" -s c -l copy -d "复制现有配置"

# link命令的选项
complete -f -c dfm -n "__fish_seen_subcommand_from link" -s n -l no-backup -d "不创建备份"

# unlink命令的选项
complete -f -c dfm -n "__fish_seen_subcommand_from unlink" -s r -l restore -d "尝试恢复备份"

# init命令的选项
complete -f -c dfm -n "__fish_seen_subcommand_from init" -s s -l skip-git-check -d "跳过git-crypt检查"

# .config目录下的应用名称补全
function __dfm_list_config_apps
    if set -q DOTFILES_PATH
        # 获取已在dotfiles中的.config目录应用
        for app in $DOTFILES_PATH/.config/*
            if test -e $app
                echo (basename $app)
            end
        end
        
        # 获取系统中尚未添加的.config目录应用
        for app in ~/.config/*
            set -l app_name (basename $app)
            if not test -e "$DOTFILES_PATH/.config/$app_name"
                echo $app_name
            end
        end
    end
end

# 家目录下的点文件补全
function __dfm_list_home_dotfiles
    # 已在dotfiles中的点文件
    if set -q DOTFILES_PATH
        for file in $DOTFILES_PATH/home/.*
            set -l file_name (basename $file)
            if test "$file_name" != "." -a "$file_name" != ".."
                echo $file_name
            end
        end
        
        # 系统中尚未添加的点文件
        for file in ~/.*
            set -l file_name (basename $file)
            if test "$file_name" != "." -a "$file_name" != ".." \
               -a "$file_name" != ".config" \
               -a "$file_name" != ".local" \
               -a "$file_name" != ".cache" \
               -a -e $file \
               -a ! -e "$DOTFILES_PATH/home/$file_name"
                echo $file_name
            end
        end
    end
end

# 应用名称补全（用于new和link命令）
complete -f -c dfm -n "__fish_seen_subcommand_from new link" -a "(__dfm_list_config_apps)" -d "应用目录"
complete -f -c dfm -n "__fish_seen_subcommand_from new link" -a "(__dfm_list_home_dotfiles)" -d "家目录点文件"

# 已链接的应用名称补全（用于unlink命令）
function __dfm_list_linked_apps
    if set -q DOTFILES_PATH
        # .config下的链接
        for app in ~/.config/*
            if test -L $app
                set -l target (readlink $app)
                if string match -q "$DOTFILES_PATH/.config/*" $target
                    echo (basename $app)
                end
            end
        end
        
        # 家目录下的链接
        for file in ~/.*
            if test -L $file
                set -l target (readlink $file)
                if string match -q "$DOTFILES_PATH/home/*" $target
                    echo (basename $file)
                end
            end
        end
    end
end

# unlink命令的补全
complete -f -c dfm -n "__fish_seen_subcommand_from unlink" -a "(__dfm_list_linked_apps)" -d "已链接的配置"

# sync命令的补全
complete -f -c dfm -n "__fish_seen_subcommand_from sync" -a "(__dfm_list_config_apps)" -d "应用目录" 
complete -f -c dfm -n "__fish_seen_subcommand_from sync" -a "(__dfm_list_home_dotfiles)" -d "家目录点文件"
