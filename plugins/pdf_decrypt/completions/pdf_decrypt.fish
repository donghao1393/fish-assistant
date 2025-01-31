complete -c pdf_decrypt -f

# 选项补全
complete -c pdf_decrypt -s i -l info -d "Show PDF encryption info"
complete -c pdf_decrypt -s p -d "Decrypt with password"
complete -c pdf_decrypt -s s -l simple -d "Try simple decryption without password"
complete -c pdf_decrypt -s f -l force -d "Try force decryption"
complete -c pdf_decrypt -s b -l batch -d "Batch decrypt multiple PDFs"

# 批量模式的特殊补全 - 只在还没有-p选项时才提示
complete -c pdf_decrypt -n "__fish_seen_argument -s b -l batch; and not __fish_seen_argument -s p" -a -p -d "Password required for batch mode"

# PDF 文件补全
function __fish_pdf_files
    set -l token (commandline -ct)
    command find . -maxdepth 1 -type f -name "*.pdf" | string replace -r '^./' '' | string match -r ".*$token.*"
end

complete -c pdf_decrypt -n "__fish_is_nth_token 2; and not __fish_seen_argument -s b -l batch" -k -a "(__fish_pdf_files)"
complete -c pdf_decrypt -n "__fish_is_nth_token 3; and __fish_prev_arg_in -p" -k -a "(__fish_pdf_files)"
complete -c pdf_decrypt -n "__fish_is_nth_token 4; and __fish_prev_arg_in -p" -k -a "(__fish_pdf_files)"
complete -c pdf_decrypt -n "__fish_is_nth_token 3; and __fish_prev_arg_in -s --simple" -k -a "(__fish_pdf_files)"
complete -c pdf_decrypt -n "__fish_is_nth_token 3; and __fish_prev_arg_in -f --force" -k -a "(__fish_pdf_files)"

# 对于批量模式，允许在密码之后补全任意数量的PDF文件
complete -c pdf_decrypt -n "__fish_seen_argument -s b -l batch; and __fish_seen_argument -s p; and not __fish_seen_argument -d" -k -a "(__fish_pdf_files)"

# 批量模式下的目录补全（只在已经输入了一些PDF文件之后才提示目录）
function __fish_list_directories
    set -l token (commandline -ct)
    command find . -maxdepth 1 -type d ! -name '.*' | string replace -r '^./' '' | string match -r ".*$token.*"
end

complete -c pdf_decrypt -n "__fish_seen_argument -s b -l batch; and __fish_seen_argument -s p; and __fish_contains_opt -s p" -F -a "(__fish_list_directories)"
