function token_count --description 'Count tokens in text files for LLM interaction'
    if test (count $argv) -eq 0
        echo "Usage: token_count <file_path>" >&2
        return 1
    end

    set -l script_dir $SCRIPTS_DIR/fish/plugins/token_count
    set -l counter_script $script_dir/token_counter.py
    set -l venv_dir $script_dir/.venv
    set -l file_path (realpath $argv[1])

    if not test -f "$file_path"
        echo "Error: 文件不存在: $file_path" >&2
        return 1
    end

    # 检查虚拟环境是否存在
    if not test -d $venv_dir
        echo "虚拟环境不存在，正在初始化..." >&2
        pushd $script_dir
        fish install.fish
        popd

        if test $status -ne 0
            echo "Error: 初始化虚拟环境失败" >&2
            return 1
        end
    end

    # 检查系统依赖
    if test (uname) = Darwin; and not command -q brew
        echo "Error: 需要安装 Homebrew 以便安装 libmagic" >&2
        return 1
    end

    if not test -f /usr/local/lib/libmagic.dylib; and not test -f /opt/homebrew/lib/libmagic.dylib
        echo "注意: 安装 libmagic 系统依赖..." >&2
        brew install libmagic
    end

    # 使用 uv 运行 Python 脚本并解析结果
    pushd $script_dir
    set -l result (uv run $counter_script $file_path)
    set -l status_code $status
    popd

    if test $status_code -ne 0
        echo "Error: 运行脚本失败" >&2
        return 1
    end

    # 解析并格式化输出
    echo $result | begin
        read -l json
        echo "文件分析结果："
        echo "文件类型: "(echo $json | string match -r '"type":\s*"([^"]*)"' | tail -n 1)
        echo "编码: "(echo $json | string match -r '"encoding":\s*"([^"]*)"' | tail -n 1)
        echo "字符数: "(echo $json | string match -r '"chars":\s*(\d+)' | tail -n 1)
        echo "单词数: "(echo $json | string match -r '"words":\s*(\d+)' | tail -n 1)
        echo "Token数: "(echo $json | string match -r '"tokens":\s*(\d+)' | tail -n 1)
        echo "文件大小: "(echo $json | string match -r '"size":\s*(\d+)' | tail -n 1)" bytes"
    end
end
