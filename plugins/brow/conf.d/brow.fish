# brow 插件初始化和环境设置

# 确保配置目录存在
if not test -d ~/.config/brow
    mkdir -p ~/.config/brow/active
end

# 确保配置文件存在
if not test -f ~/.config/brow/config.json
    echo "{}" > ~/.config/brow/config.json
end

# 定义一个函数，在brow插件加载完成后清理过期的Pod
function __brow_init --on-event fish_prompt
    # 只在第一次提示符时执行
    functions -e __brow_init

    # 检查kubectl是否可用以及_brow_pod_cleanup函数是否存在
    if command -v kubectl >/dev/null 2>&1; and functions -q _brow_pod_cleanup
        # 异步执行清理，不阻塞shell使用
        fish -c "_brow_pod_cleanup" &
    end
end
