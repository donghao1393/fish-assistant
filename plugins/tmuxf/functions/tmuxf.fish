function tmuxf --description 'Tmux session manager for fish'
    argparse 'h/help' 'n/no-attach' 'f/force' 'd/delay=' -- $argv
    or return 1

    if set -q _flag_help
        echo "Tmux session manager for fish"
        echo
        echo "Usage:"
        echo "  tmuxf save NAME      Save current tmux session"
        echo "  tmuxf load NAME      Load saved session"
        echo "  tmuxf list          List saved sessions"
        echo "  tmuxf delete NAME    Delete saved session"
        echo
        echo "Options:"
        echo "  -h, --help          Show this help"
        echo "  -n, --no-attach     Create session without attaching"
        echo "  -f, --force         Force overwrite existing session"
        echo "  -d, --delay=SEC     Add delay between commands (in seconds)"
        return 0
    end

    # 设置延迟，默认为0
    set -l delay 0
    if set -q _flag_delay
        set delay $_flag_delay
    end
    
    set -l cmd $argv[1]
    set -l name $argv[2]
    set -l tmux_config_dir "$HOME/.config/tmuxf"

    if not test -d $tmux_config_dir
        mkdir -p $tmux_config_dir
    end

    switch "$cmd"
        case "save"
            if test -z "$name"
                echo "Usage: tmuxf save NAME"
                return 1
            end
            
            # 确保tmux在运行
            if not tmux list-sessions 2>/dev/null >/dev/null
                echo "No tmux session running"
                return 1
            end

            set -l current_session (tmux display-message -p '#S')
            set -l windows (tmux list-windows -t $current_session -F '#{window_index} #{window_name} #{window_layout} #{pane_current_path} #{pane_current_command}')
            set -l config_file "$tmux_config_dir/$name.fish"

            if test -f $config_file; and not set -q _flag_force
                echo "Session '$name' already exists. Use -f/--force to overwrite."
                return 1
            end

            echo "# Tmux session saved by tmuxf on "(date) > $config_file
            echo "set -q _flag_delay; and set -l delay \$_flag_delay; or set -l delay 0" >> $config_file
            echo >> $config_file
            echo "# 检查是否已存在同名会话" >> $config_file
            echo "tmux has-session -t '$name' 2>/dev/null" >> $config_file
            echo "and begin" >> $config_file
            echo "    set -q _flag_force; or begin" >> $config_file
            echo "        echo \"Session '$name' already exists. Use -f/--force to overwrite.\"" >> $config_file
            echo "        return 1" >> $config_file
            echo "    end" >> $config_file
            echo "    tmux kill-session -t '$name'" >> $config_file
            echo "end" >> $config_file
            echo >> $config_file
            
            echo "# 创建新会话" >> $config_file
            # 获取第一个窗口的信息用于创建会话
            set -l first_window (echo $windows[1] | string split " ")
            set -l first_path $first_window[4]
            set -l first_cmd $first_window[5]
            if test $first_cmd = "fish"; or test $first_cmd = "bash"; or test $first_cmd = "zsh"
                echo "tmux new-session -d -s '$name' -c '$first_path'" >> $config_file
            else
                echo "tmux new-session -d -s '$name' -c '$first_path' '$first_cmd'" >> $config_file
            end
            echo "test \$delay -gt 0; and sleep \$delay" >> $config_file
            
            for window in $windows
                set -l parts (string split " " $window)
                set -l idx $parts[1]
                set -l wname $parts[2]
                set -l layout $parts[3]
                set -l path $parts[4]
                set -l cmd $parts[5]

                if test $idx = 0
                    echo "tmux rename-window -t '$name:0' '$wname'" >> $config_file
                else
                    # 如果命令不是默认shell，直接在new-window时指定
                    if not contains $cmd fish bash zsh
                        echo "tmux new-window -t '$name' -n '$wname' -c '$path' '$cmd'" >> $config_file
                    else
                        echo "tmux new-window -t '$name' -n '$wname' -c '$path'" >> $config_file
                    end
                end
                echo "test \$delay -gt 0; and sleep \$delay" >> $config_file

                # 获取并保存window中的额外pane
                set -l panes (tmux list-panes -t $current_session:$idx -F '#{pane_index} #{pane_current_path} #{pane_current_command}')
                # 跳过第一个pane，因为它已经在创建窗口时处理了
                if test (count $panes) -gt 1
                    set -l panes_subset $panes[2..-1]
                    for pane in $panes_subset
                        set -l pane_parts (string split " " $pane)
                        set -l pane_idx $pane_parts[1]
                        set -l pane_path $pane_parts[2]
                        set -l pane_cmd $pane_parts[3]

                        echo "tmux split-window -t '$name:$idx' -c '$pane_path'" >> $config_file
                        if not contains $pane_cmd fish bash zsh
                            echo "tmux send-keys -t '$name:$idx.$pane_idx' '$pane_cmd' C-m" >> $config_file
                        end
                        echo "test \$delay -gt 0; and sleep \$delay" >> $config_file
                    end
                end

                # 应用布局
                echo "tmux select-layout -t '$name:$idx' '$layout'" >> $config_file
                echo >> $config_file
            end

            echo "# 选择初始窗口" >> $config_file
            echo "tmux select-window -t '$name:0'" >> $config_file
            echo >> $config_file
            echo "# 根据选项决定是否连接到会话" >> $config_file
            echo "if not set -q _flag_no_attach" >> $config_file
            echo "    tmux attach-session -t '$name'" >> $config_file
            echo "end" >> $config_file

            echo "Session saved to $config_file"

        case "load"
            if test -z "$name"
                echo "Usage: tmuxf load NAME"
                return 1
            end

            set -l config_file "$tmux_config_dir/$name.fish"
            if not test -f $config_file
                echo "Session configuration not found: $config_file"
                return 1
            end

            source $config_file

        case "list"
            echo "Available sessions:"
            for file in $tmux_config_dir/*.fish
                string replace -r "$tmux_config_dir/(.+)\.fish" '$1' $file
            end

        case "delete"
            if test -z "$name"
                echo "Usage: tmuxf delete NAME"
                return 1
            end

            set -l config_file "$tmux_config_dir/$name.fish"
            if test -f $config_file
                rm $config_file
                echo "Session configuration deleted: $name"
            else
                echo "Session configuration not found: $name"
                return 1
            end

        case '*'
            echo "Unknown command: $cmd"
            echo "Run 'tmuxf --help' for usage information"
            return 1
    end
end