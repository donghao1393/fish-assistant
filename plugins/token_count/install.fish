#!/usr/bin/env fish

echo "正在安装token_count依赖..."

# 检查是否在macOS上，如果是则安装libmagic
if test (uname) = Darwin
    if not test -f /usr/local/lib/libmagic.dylib; and not test -f /opt/homebrew/lib/libmagic.dylib
        echo "安装libmagic系统依赖..."
        brew install libmagic
    end
end

# 创建虚拟环境并安装依赖
echo "创建Python虚拟环境..."
uv venv -p 3.12
echo "安装Python依赖..."
uv pip install -r requirements.txt

echo "安装完成！"

# 测试安装
echo "测试安装..."
if test -f README.md
    uv run token_counter.py README.md
else
    echo "测试文件不存在，跳过测试"
end

echo "token_count安装和测试完成！"
