# 记录硬链接关系的函数
function _fa_record_link --argument-names target source
    # 检查是否设置了 FISH_ASSISTANT_HOME 环境变量
    if not set -q FISH_ASSISTANT_HOME
        echo "错误: 未设置 FISH_ASSISTANT_HOME 环境变量"
        return 1
    end

    set -l data_dir $FISH_ASSISTANT_HOME/plugins/fa/data
    set -l links_file $data_dir/links.json

    # 确保数据目录存在
    if not test -d $data_dir
        mkdir -p $data_dir
    end

    # 确保 JSON 文件存在
    if not test -f $links_file
        echo '{}' > $links_file
    end

    # 使用 jq 更新 JSON 文件
    # 将目标文件路径作为键，源文件路径作为值
    jq --arg target "$target" --arg source "$source" '.[$target] = $source' $links_file > $links_file.tmp
    mv $links_file.tmp $links_file
end

# 删除硬链接记录的函数
function _fa_remove_link_record --argument-names target
    # 检查是否设置了 FISH_ASSISTANT_HOME 环境变量
    if not set -q FISH_ASSISTANT_HOME
        return 1
    end

    set -l data_dir $FISH_ASSISTANT_HOME/plugins/fa/data
    set -l links_file $data_dir/links.json

    if test -f $links_file
        # 使用 jq 删除指定的键
        jq --arg target "$target" 'del(.[$target])' $links_file > $links_file.tmp
        mv $links_file.tmp $links_file
    end
end

# 获取硬链接源文件的函数
function _fa_get_link_source --argument-names target
    # 检查是否设置了 FISH_ASSISTANT_HOME 环境变量
    if not set -q FISH_ASSISTANT_HOME
        return 1
    end

    set -l data_dir $FISH_ASSISTANT_HOME/plugins/fa/data
    set -l links_file $data_dir/links.json

    if test -f $links_file
        # 使用 jq 获取指定键的值
        set -l source (jq -r --arg target "$target" '.[$target] // empty' $links_file)
        if test -n "$source" -a "$source" != "null"
            echo $source
            return 0
        end
    end
    return 1
end

function fa --description 'Fish Assistant - manage fish functions and plugins'
    set -l fa_version "0.1.0"  # 改名为 fa_version

    # 检查是否设置了 FISH_ASSISTANT_HOME 环境变量
    if not set -q FISH_ASSISTANT_HOME
        echo "错误: 未设置 FISH_ASSISTANT_HOME 环境变量"
        echo "请在 ~/.config/fish/config.fish 中添加以下内容:"
        echo "    set -gx FISH_ASSISTANT_HOME /path/to/fish-assistant"
        echo "其中 /path/to/fish-assistant 是 fish-assistant 项目的根目录"
        return 1
    end

    set -l base_dir $FISH_ASSISTANT_HOME
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
    # 检查是否设置了 FISH_ASSISTANT_HOME 环境变量
    if not set -q FISH_ASSISTANT_HOME
        echo "错误: 未设置 FISH_ASSISTANT_HOME 环境变量"
        return 1
    end

    set -l base_dir $FISH_ASSISTANT_HOME
    set -l plugin_dir $base_dir/plugins/$plugin_name

    if test -d $plugin_dir
        echo "错误: 插件 '$plugin_name' 已存在"
        return 1
    end

    # 创建目录结构
    mkdir -p $plugin_dir/{functions,completions,conf.d}

    # 创建主函数文件
    touch $plugin_dir/functions/$plugin_name.fish

    echo "创建了插件目录结构:"
    echo "  $plugin_dir/"
    echo "  ├─ functions/"
    echo "  │  └─ $plugin_name.fish"
    echo "  └─ conf.d/"
    echo "  └─ completions/"
end

function _fa_plugin_map --argument-names plugin_name
    # 检查是否设置了 FISH_ASSISTANT_HOME 环境变量
    if not set -q FISH_ASSISTANT_HOME
        echo "错误: 未设置 FISH_ASSISTANT_HOME 环境变量"
        return 1
    end

    set -l base_dir $FISH_ASSISTANT_HOME
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
            _fa_record_link $target $f
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
            _fa_record_link $target $f
            echo "创建链接: $target -> $f"
        end
    end

    # 映射 conf.d 文件
    set -l conf_dir $plugin_dir/conf.d
    if test -d $conf_dir
        for f in $conf_dir/*.fish
            if test -f $f
                set -l fname (basename $f)
                set -l target $fish_config_dir/conf.d/$fname
                if test -L $target
                    echo "更新链接: $target"
                    rm $target
                end
                ln -f $f $target
                _fa_record_link $target $f
                echo "创建链接: $target -> $f"
            end
        end
    end
end

function _fa_map --argument-names type file
    # 检查是否设置了 FISH_ASSISTANT_HOME 环境变量
    if not set -q FISH_ASSISTANT_HOME
        echo "错误: 未设置 FISH_ASSISTANT_HOME 环境变量"
        return 1
    end

    set -l base_dir $FISH_ASSISTANT_HOME
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
            _fa_record_link $target $source_path
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
            _fa_record_link $target $source_path
            echo "创建链接: $target -> $source_path"

        case conf.d
            set -l source_path $base_dir/conf.d/$file
            if not test -f $source_path
                echo "错误: 源文件不存在: $source_path"
                return 1
            end

            # 确保目标目录存在
            if not test -d $fish_config_dir/conf.d
                mkdir -p $fish_config_dir/conf.d
            end

            set -l target $fish_config_dir/conf.d/(basename $file)
            if test -L $target
                echo "更新链接: $target"
                rm $target
            end
            ln -f $source_path $target
            _fa_record_link $target $source_path
            echo "创建链接: $target -> $source_path"

        case '*'
            echo "错误: 未知的类型 '$type'"
            echo "可用类型: functions, completions, conf.d, common, apps"
            return 1
    end
end

function _fa_list
    set -l fish_config_dir ~/.config/fish

    # 检查是否设置了 FISH_ASSISTANT_HOME 环境变量
    if not set -q FISH_ASSISTANT_HOME
        echo "错误: 未设置 FISH_ASSISTANT_HOME 环境变量"
        return 1
    end

    set -l data_dir $FISH_ASSISTANT_HOME/plugins/fa/data
    set -l links_file $data_dir/links.json

    echo "函数链接:"
    for f in $fish_config_dir/functions/*.fish
        # 检查软链接
        if test -L $f
            set -l target (readlink $f)
            echo "  $(basename $f) -> $target"
        # 检查硬链接
        else if test -f $links_file
            set -l source (_fa_get_link_source $f)
            if test $status -eq 0
                echo "  $(basename $f) -> $source"
            end
        end
    end

    echo -e "\n配置链接:"
    if test -d $fish_config_dir/conf.d
        for f in $fish_config_dir/conf.d/*.fish
            # 检查软链接
            if test -L $f
                set -l target (readlink $f)
                echo "  $(basename $f) -> $target"
            # 检查硬链接
            else if test -f $links_file
                set -l source (_fa_get_link_source $f)
                if test $status -eq 0
                    echo "  $(basename $f) -> $source"
                end
            end
        end
    end

    echo -e "\n补全链接:"
    for f in $fish_config_dir/completions/*.fish
        # 检查软链接
        if test -L $f
            set -l target (readlink $f)
            echo "  $(basename $f) -> $target"
        # 检查硬链接
        else if test -f $links_file
            set -l source (_fa_get_link_source $f)
            if test $status -eq 0
                echo "  $(basename $f) -> $source"
            end
        end
    end
end

function _fa_check
    set -l fish_config_dir ~/.config/fish

    # 检查是否设置了 FISH_ASSISTANT_HOME 环境变量
    if not set -q FISH_ASSISTANT_HOME
        echo "错误: 未设置 FISH_ASSISTANT_HOME 环境变量"
        return 1
    end

    set -l data_dir $FISH_ASSISTANT_HOME/plugins/fa/data
    set -l links_file $data_dir/links.json
    set -l has_error false

    echo "检查函数链接..."
    for f in $fish_config_dir/functions/*.fish
        # 检查软链接
        if test -L $f; and not test -e $f
            echo "  失效链接: $f -> $(readlink $f)"
            set has_error true
        # 检查硬链接
        else if test -f $links_file
            set -l source (_fa_get_link_source $f)
            if test $status -eq 0; and not test -e $source
                echo "  失效硬链接: $f -> $source"
                set has_error true
            end
        end
    end

    echo -e "\n检查补全链接..."
    for f in $fish_config_dir/completions/*.fish
        # 检查软链接
        if test -L $f; and not test -e $f
            echo "  失效链接: $f -> $(readlink $f)"
            set has_error true
        # 检查硬链接
        else if test -f $links_file
            set -l source (_fa_get_link_source $f)
            if test $status -eq 0; and not test -e $source
                echo "  失效硬链接: $f -> $source"
                set has_error true
            end
        end
    end

    echo -e "\n检查配置链接..."
    if test -d $fish_config_dir/conf.d
        for f in $fish_config_dir/conf.d/*.fish
            # 检查软链接
            if test -L $f; and not test -e $f
                echo "  失效链接: $f -> $(readlink $f)"
                set has_error true
            # 检查硬链接
            else if test -f $links_file
                set -l source (_fa_get_link_source $f)
                if test $status -eq 0; and not test -e $source
                    echo "  失效硬链接: $f -> $source"
                    set has_error true
                end
            end
        end
    end

    if test $has_error = false
        echo "所有链接正常"
    end
end

function _fa_clean
    set -l fish_config_dir ~/.config/fish

    # 检查是否设置了 FISH_ASSISTANT_HOME 环境变量
    if not set -q FISH_ASSISTANT_HOME
        echo "错误: 未设置 FISH_ASSISTANT_HOME 环境变量"
        return 1
    end

    set -l data_dir $FISH_ASSISTANT_HOME/plugins/fa/data
    set -l links_file $data_dir/links.json
    set -l cleaned false

    # 清理失效的软链接
    for f in $fish_config_dir/{functions,completions,conf.d}/*.fish
        if test -L $f; and not test -e $f
            echo "删除失效链接: $f -> $(readlink $f)"
            rm $f
            set cleaned true
        end
    end

    # 清理失效的硬链接
    if test -f $links_file
        # 使用 jq 遍历所有链接
        jq -r 'to_entries | .[] | "\(.key)\t\(.value)"' $links_file | while read -l target source
            # 检查源文件是否存在
            if test -f $target; and not test -e $source
                echo "删除失效硬链接: $target -> $source"
                rm $target
                _fa_remove_link_record $target
                set cleaned true
            end
        end
    end

    if test $cleaned = false
        echo "没有需要清理的链接"
    end
end

function _fa_unmap --argument-names file
    set -l fish_config_dir ~/.config/fish

    # 检查是否设置了 FISH_ASSISTANT_HOME 环境变量
    if not set -q FISH_ASSISTANT_HOME
        echo "错误: 未设置 FISH_ASSISTANT_HOME 环境变量"
        return 1
    end

    set -l data_dir $FISH_ASSISTANT_HOME/plugins/fa/data
    set -l links_file $data_dir/links.json
    set -l found false

    for dir in functions completions conf.d
        set -l target $fish_config_dir/$dir/$file

        # 检查软链接
        if test -L $target
            echo "删除链接: $target -> $(readlink $target)"
            rm $target
            _fa_remove_link_record $target
            set found true
            break
        # 检查硬链接
        else if test -f $target; and test -f $links_file
            set -l source (_fa_get_link_source $target)
            if test $status -eq 0
                echo "删除硬链接: $target -> $source"
                rm $target
                _fa_remove_link_record $target
                set found true
                break
            end
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
    echo "  fa map <type> <file>     创建单个文件的硬链接"
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
    echo "  conf.d     functions/conf.d 下的自动加载配置文件"
    echo "  apps       functions/apps 下的应用函数"
    echo "  completions 补全文件"
end
