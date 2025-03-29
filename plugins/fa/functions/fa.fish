function fa --description 'Fish Assistant - manage fish functions and plugins'
    set -l fa_version "0.1.0"  # 改名为 fa_version
    set -l base_dir $STUDIO_HOME/scripts/fish
    set -l fish_config_dir ~/.config/fish

    # 子命令解析
    if test (count $argv) -eq 0
        _fa_help
        return 1
    end

    set -l cmd $argv[1]
    set -e argv[1]

    switch $cmd
        case plugin
            if test (count $argv) -lt 1
                echo "错误: plugin 命令需要指定操作类型 (add/map)"
                return 1
            end

            set -l subcmd $argv[1]
            set -e argv[1]

            switch $subcmd
                case add
                    if test (count $argv) -ne 1
                        echo "用法: fa plugin add <plugin_name>"
                        return 1
                    end
                    _fa_plugin_add $argv[1]

                case map
                    if test (count $argv) -ne 1
                        echo "用法: fa plugin map <plugin_name>"
                        return 1
                    end
                    _fa_plugin_map $argv[1]

                case '*'
                    echo "未知的 plugin 子命令: $subcmd"
                    return 1
            end

        case map
            if test (count $argv) -ne 2
                echo "用法: fa map <type> <file>"
                echo "type 可以是: functions, completions, common, apps"
                return 1
            end
            _fa_map $argv[1] $argv[2]

        case list
            _fa_list

        case check
            _fa_check

        case clean
            _fa_clean

        case help
            _fa_help

        case unmap
            if test (count $argv) -ne 1
                echo "用法: fa unmap <file>"
                return 1
            end
            _fa_unmap $argv[1]

        case version
            echo "Fish Assistant v$fa_version"

        case '*'
            echo "未知命令: $cmd"
            _fa_help
            return 1
    end
end

function _fa_plugin_add --argument-names plugin_name
    set -l base_dir $STUDIO_HOME/scripts/fish
    set -l plugin_dir $base_dir/plugins/$plugin_name

    if test -d $plugin_dir
        echo "错误: 插件 '$plugin_name' 已存在"
        return 1
    end

    # 创建目录结构
    mkdir -p $plugin_dir/{functions,completions}

    # 创建主函数文件
    touch $plugin_dir/functions/$plugin_name.fish

    echo "创建了插件目录结构:"
    echo "  $plugin_dir/"
    echo "  ├─ functions/"
    echo "  │  └─ $plugin_name.fish"
    echo "  └─ completions/"
end

function _fa_plugin_map --argument-names plugin_name
    set -l base_dir $STUDIO_HOME/scripts/fish
    set -l fish_config_dir ~/.config/fish
    set -l plugin_dir $base_dir/plugins/$plugin_name

    if not test -d $plugin_dir
        echo $plugin_dir
        echo "错误: 插件 '$plugin_name' 不存在"
        return 1
    end

    # 映射函数文件
    for f in $plugin_dir/functions/*.fish
        if test -f $f
            set -l fname (basename $f)
            set -l target $fish_config_dir/functions/$fname
            if test -L $target
                echo "更新链接: $target"
                rm $target
            end
            ln -f $f $target
            echo "创建链接: $target -> $f"
        end
    end

    # 映射补全文件
    for f in $plugin_dir/completions/*.fish
        if test -f $f
            set -l fname (basename $f)
            set -l target $fish_config_dir/completions/$fname
            if test -L $target
                echo "更新链接: $target"
                rm $target
            end
            ln -f $f $target
            echo "创建链接: $target -> $f"
        end
    end
end

function _fa_map --argument-names type file
    set -l base_dir $STUDIO_HOME/scripts/fish
    set -l fish_config_dir ~/.config/fish

    switch $type
        case functions common apps
            set -l source_path
            if test $type = functions
                set source_path $base_dir/functions/$file
            else
                set source_path $base_dir/functions/$type/$file
            end

            if not test -f $source_path
                echo "错误: 源文件不存在: $source_path"
                return 1
            end

            set -l target $fish_config_dir/functions/(basename $file)
            if test -L $target
                echo "更新链接: $target"
                rm $target
            end
            ln -f $source_path $target
            echo "创建链接: $target -> $source_path"

        case completions
            set -l source_path $base_dir/completions/$file
            if not test -f $source_path
                echo "错误: 源文件不存在: $source_path"
                return 1
            end

            set -l target $fish_config_dir/completions/(basename $file)
            if test -L $target
                echo "更新链接: $target"
                rm $target
            end
            ln -f $source_path $target
            echo "创建链接: $target -> $source_path"

        case '*'
            echo "错误: 未知的类型 '$type'"
            echo "可用类型: functions, completions, common, apps"
            return 1
    end
end

function _fa_list
    set -l fish_config_dir ~/.config/fish

    echo "函数链接:"
    for f in $fish_config_dir/functions/*.fish
        if test -L $f
            set -l target (readlink $f)
            echo "  $(basename $f) -> $target"
        end
    end

    echo -e "\n补全链接:"
    for f in $fish_config_dir/completions/*.fish
        if test -L $f
            set -l target (readlink $f)
            echo "  $(basename $f) -> $target"
        end
    end
end

function _fa_check
    set -l fish_config_dir ~/.config/fish
    set -l has_error false

    echo "检查函数链接..."
    for f in $fish_config_dir/functions/*.fish
        if test -L $f; and not test -e $f
            echo "  失效链接: $f -> $(readlink $f)"
            set has_error true
        end
    end

    echo -e "\n检查补全链接..."
    for f in $fish_config_dir/completions/*.fish
        if test -L $f; and not test -e $f
            echo "  失效链接: $f -> $(readlink $f)"
            set has_error true
        end
    end

    if test $has_error = false
        echo "所有链接正常"
    end
end

function _fa_clean
    set -l fish_config_dir ~/.config/fish
    set -l cleaned false

    for f in $fish_config_dir/{functions,completions}/*.fish
        if test -L $f; and not test -e $f
            echo "删除失效链接: $f -> $(readlink $f)"
            rm $f
            set cleaned true
        end
    end

    if test $cleaned = false
        echo "没有需要清理的链接"
    end
end

function _fa_unmap --argument-names file
    set -l fish_config_dir ~/.config/fish
    set -l found false

    for dir in functions completions
        set -l target $fish_config_dir/$dir/$file
        if test -L $target
            echo "删除链接: $target -> $(readlink $target)"
            rm $target
            set found true
            break
        end
    end

    if test $found = false
        echo "未找到链接: $file"
        return 1
    end
end

function _fa_help
    echo "Fish Assistant - 管理 fish 函数和插件"
    echo
    echo "用法:"
    echo "  fa plugin add <name>     创建新插件目录结构"
    echo "  fa plugin map <name>     映射插件中的所有文件"
    echo "  fa map <type> <file>     创建单个文件的软链接"
    echo "  fa list                  列出所有已创建的链接"
    echo "  fa check                 检查链接状态"
    echo "  fa clean                 清理失效的链接"
    echo "  fa unmap <file>          删除指定的链接"
    echo "  fa help                  显示此帮助信息"
    echo "  fa version               显示版本信息"
    echo
    echo "类型 (type) 可以是:"
    echo "  functions   直接在 functions 目录下的文件"
    echo "  common     functions/common 下的通用函数"
    echo "  apps       functions/apps 下的应用函数"
    echo "  completions 补全文件"
end
