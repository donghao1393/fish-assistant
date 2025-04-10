# 为fzl命令提供自动完成支持
function __fzl_layouts
    set -l layout_dir ~/.config/zellij/layouts
    if test -d $layout_dir
        for file in $layout_dir/*.kdl
            string replace -r "$layout_dir/(.+)\.kdl" '$1' $file
        end
    end
end

complete -c fzl -s h -l help -d "显示帮助信息"
complete -c fzl -s l -l list -d "列出可用布局"
complete -c fzl -s e -l edit -d "编辑指定布局" -xa "(__fzl_layouts)"
complete -c fzl -s s -l save -d "保存当前会话为布局"
complete -c fzl -s d -l delete -d "删除指定布局" -xa "(__fzl_layouts)"
complete -c fzl -f -a "(__fzl_layouts)" -d "加载布局"
