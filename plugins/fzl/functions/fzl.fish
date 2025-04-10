function fzl
    argparse 'h/help' 'e/edit=' 'l/list' -- $argv
    or return 1
    
    set -l layout_dir ~/.config/zellij/layouts
    
    if set -q _flag_help
        echo "Zellij layout manager"
        echo
        echo "Usage:"
        echo "  fzl NAME         Load layout"
        echo "  fzl -e NAME      Edit layout"
        echo "  fzl -l           List available layouts"
        echo
        return 0
    end
    
    if set -q _flag_list
        echo "Available layouts:"
        for file in $layout_dir/*.kdl
            string replace -r "$layout_dir/(.+)\.kdl" '$1' $file
        end
        return 0
    end
    
    if set -q _flag_edit
        set -l layout_file "$layout_dir/$_flag_edit.kdl"
        if test -f $layout_file
            $EDITOR $layout_file
        else
            echo "Layout not found: $_flag_edit"
            return 1
        end
        return 0
    end
    
    if test -n "$argv[1]"
        set -l layout_name $argv[1]
        zellij --layout $layout_name
    else
        echo "Please provide a layout name or use -l to list available layouts"
        return 1
    end
end
