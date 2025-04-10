function fzl
    argparse 'h/help' 'e/edit=' 'l/list' 's/save=' 'd/delete=' -- $argv
    or return 1
    
    set -l layout_dir ~/.config/zellij/layouts
    
    # 确保布局目录存在
    if not test -d $layout_dir
        mkdir -p $layout_dir
    end
    
    # 检查zellij是否已安装
    if not command -v zellij >/dev/null 2>&1
        echo "错误: 未找到zellij。请先安装它:"
        echo "  brew install zellij"
        return 1
    end
    
    if set -q _flag_help
        echo "Zellij layout manager"
        echo
        echo "Usage:"
        echo "  fzl NAME         Load layout"
        echo "  fzl -e NAME      Edit layout"
        echo "  fzl -l           List available layouts"
        echo "  fzl -s NAME      Save current session as layout"
        echo "  fzl -d NAME      Delete layout"
        echo
        return 0
    end
    
    if set -q _flag_list
        echo "Available layouts:"
        if count $layout_dir/*.kdl >/dev/null 2>&1
            for file in $layout_dir/*.kdl
                set -l name (string replace -r "$layout_dir/(.+)\.kdl" '$1' $file)
                echo "  $name"
            end
        else
            echo "  No layouts found in $layout_dir"
        end
        return 0
    end
    
    if set -q _flag_save
        set -l layout_file "$layout_dir/$_flag_save.kdl"
        if test -f $layout_file
            read -P "布局已存在: $_flag_save. 是否覆盖? [y/N] " confirm
            if test "$confirm" != "y" -a "$confirm" != "Y"
                return 1
            end
        end
        
        # 检查是否在zellij会话中
        if test -z "$ZELLIJ"
            echo "错误: 你必须在zellij会话中才能保存布局"
            return 1
        end
        
        echo "保存当前布局为: $_flag_save"
        zellij action dump-layout > $layout_file
        echo "布局已保存到: $layout_file"
        return 0
    end
    
    if set -q _flag_delete
        set -l layout_file "$layout_dir/$_flag_delete.kdl"
        if test -f $layout_file
            read -P "确定要删除布局 '$_flag_delete'? [y/N] " confirm
            if test "$confirm" = "y" -o "$confirm" = "Y"
                rm $layout_file
                echo "布局已删除: $_flag_delete"
            end
        else
            echo "未找到布局: $_flag_delete"
            return 1
        end
        return 0
    end
    
    
    if set -q _flag_edit
        set -l layout_file "$layout_dir/$_flag_edit.kdl"
        if test -f $layout_file
            $EDITOR $layout_file
        else
            echo "未找到布局: $_flag_edit"
            return 1
        end
        return 0
    end
    
    if test -n "$argv[1]"
        set -l layout_name $argv[1]
        set -l layout_file "$layout_dir/$layout_name.kdl"
        
        # 检查布局文件是否存在
        if not test -f $layout_file
            echo "未找到布局: $layout_name"
            return 1
        end
        
        zellij --layout $layout_name
    else
        # 如果安装了fzf，使用交互式选择
        if command -v fzf >/dev/null 2>&1
            # 检查是否有可用布局
            if not count $layout_dir/*.kdl >/dev/null 2>&1
                echo "没有可用布局。使用 -s NAME 保存当前会话作为布局。"
                return 1
            end
            
            set -l layouts (string replace -r "$layout_dir/(.+)\.kdl" '$1' $layout_dir/*.kdl)
            set -l selected_layout (printf "%s\n" $layouts | fzf --prompt="选择布局: ")
            
            if test -n "$selected_layout"
                zellij --layout $selected_layout
            else
                return 0
            end
        else
            echo "请提供布局名称或使用 -l 列出可用布局"
            return 1
        end
    end
end
