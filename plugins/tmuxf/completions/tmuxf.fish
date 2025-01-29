complete -c tmuxf -f

# 主要命令的自动补全
complete -c tmuxf -n "not __fish_seen_subcommand_from save load list delete" -a "save" -d "Save current tmux session"
complete -c tmuxf -n "not __fish_seen_subcommand_from save load list delete" -a "load" -d "Load saved session"
complete -c tmuxf -n "not __fish_seen_subcommand_from save load list delete" -a "list" -d "List saved sessions"
complete -c tmuxf -n "not __fish_seen_subcommand_from save load list delete" -a "delete" -d "Delete saved session"

# 选项的自动补全
complete -c tmuxf -s h -l help -d "Show help information"
complete -c tmuxf -s n -l no-attach -d "Create session without attaching"
complete -c tmuxf -s f -l force -d "Force overwrite existing session"
complete -c tmuxf -s d -l delay -d "Add delay between commands (in seconds)" -r

# 为 load 和 delete 命令补全已存在的会话名
function __tmuxf_list_sessions
    set -l config_dir "$HOME/.config/tmuxf"
    if test -d $config_dir
        for file in $config_dir/*.fish
            string replace -r ".+/(.+)\.fish\$" '$1' $file
        end
    end
end

complete -c tmuxf -n "__fish_seen_subcommand_from load delete" -a "(__tmuxf_list_sessions)" -d "Saved session"