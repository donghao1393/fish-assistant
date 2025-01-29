complete -c pdf_decrypt -f

# 选项补全
complete -c pdf_decrypt -s i -l info -d "Show PDF encryption info"
complete -c pdf_decrypt -s p -d "Decrypt with password"
complete -c pdf_decrypt -s s -l simple -d "Try simple decryption without password"
complete -c pdf_decrypt -s f -l force -d "Try force decryption"

# PDF 文件补全
complete -c pdf_decrypt -n "__fish_is_nth_token 2" -k -a "(command ls *.pdf 2>/dev/null)"
complete -c pdf_decrypt -n "__fish_is_nth_token 3; and __fish_prev_arg_in -p" -k -a "(command ls *.pdf 2>/dev/null)"
complete -c pdf_decrypt -n "__fish_is_nth_token 4; and __fish_prev_arg_in -p" -k -a "(command ls *.pdf 2>/dev/null)"
complete -c pdf_decrypt -n "__fish_is_nth_token 3; and __fish_prev_arg_in -s --simple" -k -a "(command ls *.pdf 2>/dev/null)"
complete -c pdf_decrypt -n "__fish_is_nth_token 3; and __fish_prev_arg_in -f --force" -k -a "(command ls *.pdf 2>/dev/null)"
