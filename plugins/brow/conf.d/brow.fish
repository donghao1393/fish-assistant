# brow 插件初始化和环境设置

# 确保配置目录存在
if not test -d ~/.config/brow
    mkdir -p ~/.config/brow/active
end

# 确保配置文件存在
if not test -f ~/.config/brow/config.json
    echo "{}" > ~/.config/brow/config.json
end

# 在启动时清理过期的Pod
if command -v kubectl >/dev/null 2>&1
    # 异步执行清理，不阻塞shell启动
    fish -c "_brow_pod_cleanup" &
end
