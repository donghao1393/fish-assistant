function token_count --description 'Count tokens in text files for LLM interaction'
    set -l script_dir (dirname (dirname (realpath (status filename))))
    set -l conda_env token_count
    set -l requirements_file $script_dir/requirements.txt
    set -l counter_script $script_dir/token_counter.py

    if test (count $argv) -eq 0
        echo "Usage: token_count <file_path>" >&2
        return 1
    end

    if not test -f $argv[1]
        echo "Error: File not found: $argv[1]" >&2
        return 1
    end

    # 激活 conda 环境
    conda activate $conda_env

    # 检查是否成功激活
    if test $status -ne 0
        echo "Error: Failed to activate conda environment: $conda_env" >&2
        return 1
    end

    # 检查必需的包是否安装
    set -l missing_packages
    for package in (cat $requirements_file)
        if not python -c "import $package" 2>/dev/null
            set -a missing_packages $package
        end
    end

    if test (count $missing_packages) -gt 0
        echo "Missing required packages: $missing_packages" >&2
        echo "Please install them using: pip install -r $requirements_file" >&2
        conda deactivate
        return 1
    end

    # 运行 Python 脚本并解析结果
    set -l result (python $counter_script $argv[1])
    set -l status_code $status

    # 恢复 conda 环境
    conda deactivate

    if test $status_code -ne 0
        return 1
    end

    # 解析并格式化输出
    echo $result | begin
        read -l json
        echo "文件分析结果："
        echo "编码: "(echo $json | string match -r '"encoding":\s*"([^"]*)"' | tail -n 1)
        echo "字符数: "(echo $json | string match -r '"chars":\s*(\d+)' | tail -n 1)
        echo "单词数: "(echo $json | string match -r '"words":\s*(\d+)' | tail -n 1)
        echo "Token数: "(echo $json | string match -r '"tokens":\s*(\d+)' | tail -n 1)
        echo "文件大小: "(echo $json | string match -r '"size":\s*(\d+)' | tail -n 1)" bytes"
    end
end
