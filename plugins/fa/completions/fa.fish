function __fish_fa_needs_command
    set -l cmd (commandline -opc)
    if test (count $cmd) -eq 1
        return 0
    end
    return 1
end

function __fish_fa_using_command
    set -l cmd (commandline -opc)
    if test (count $cmd) -gt 1
        if test "$argv[1]" = "$cmd[2]"
            return 0
        end
    end
    return 1
end

function __fish_fa_needs_type
    set -l cmd (commandline -opc)
    if test (count $cmd) -eq 2; and test "$cmd[2]" = "map"
        return 0
    end
    return 1
end

function __fish_fa_needs_file
    set -l cmd (commandline -opc)
    if test (count $cmd) -eq 3; and test "$cmd[2]" = "map"
        string match -q -r '^(functions|common|apps|completions)$' -- "$cmd[3]"
        return $status
    end
    return 1
end

function __fish_fa_list_files --argument-names type
    set -l base_dir ~/dev/scripts/fish
    set -l dir
    switch $type
        case functions
            set dir $base_dir/functions
        case common
            set dir $base_dir/functions/common
        case apps
            set dir $base_dir/functions/apps
        case completions
            set dir $base_dir/completions
        case '*'
            return 1
    end

    if test -d "$dir"
        # 获取目录下的所有 .fish 文件
        for f in $dir/*.fish
            # 检查文件是否真实存在（避免空目录下的通配符匹配）
            if test -f "$f"
                basename "$f"
            end
        end
    end
end

function __fish_fa_list_plugins
    set -l plugins_dir ~/dev/scripts/fish/plugins
    if test -d "$plugins_dir"
        command ls -1 "$plugins_dir" 2>/dev/null
    end
end

function __fish_fa_list_linked_files
    for f in ~/.config/fish/{functions,completions}/*.fish
        if test -L "$f"
            basename "$f"
        end
    end
end

# 主命令补全
complete -f -c fa -n __fish_fa_needs_command -a plugin -d '管理插件'
complete -f -c fa -n __fish_fa_needs_command -a map -d '创建单个文件的软链接'
complete -f -c fa -n __fish_fa_needs_command -a list -d '列出所有已创建的链接'
complete -f -c fa -n __fish_fa_needs_command -a check -d '检查链接状态'
complete -f -c fa -n __fish_fa_needs_command -a clean -d '清理失效的链接'
complete -f -c fa -n __fish_fa_needs_command -a unmap -d '删除指定的链接'
complete -f -c fa -n __fish_fa_needs_command -a help -d '显示帮助信息'
complete -f -c fa -n __fish_fa_needs_command -a version -d '显示版本信息'

# plugin 子命令补全
complete -f -c fa -n '__fish_fa_using_command plugin' -a add -d '创建新插件目录结构'
complete -f -c fa -n '__fish_fa_using_command plugin' -a map -d '映射插件中的所有文件'

# map 命令的类型补全
complete -f -c fa -n __fish_fa_needs_type -a functions -d '直接在 functions 目录下的文件'
complete -f -c fa -n __fish_fa_needs_type -a common -d 'functions/common 下的通用函数'
complete -f -c fa -n __fish_fa_needs_type -a apps -d 'functions/apps 下的应用函数'
complete -f -c fa -n __fish_fa_needs_type -a completions -d '补全文件'

# 文件名补全
complete -f -c fa -n __fish_fa_needs_file -a '(__fish_fa_list_files (commandline -opc)[3])'

# plugin 命令的插件名补全
complete -f -c fa -n '__fish_fa_using_command plugin' -a '(__fish_fa_list_plugins)'

# unmap 命令的文件补全
complete -f -c fa -n '__fish_fa_using_command unmap' -a '(__fish_fa_list_linked_files)'
