# brow插件的国际化支持函数

# 全局变量，存储当前语言和翻译字符串
set -g _brow_i18n_current_lang ""
set -g _brow_i18n_strings ""

function _brow_i18n_init
    # 初始化i18n系统
    # 如果已经设置了语言，则使用该语言
    # 否则，尝试从配置文件中读取语言设置
    # 如果配置文件中没有语言设置，则使用系统语言
    # 如果系统语言不受支持，则使用默认语言（中文）

    # 如果已经初始化，则直接返回
    if test -n "$_brow_i18n_current_lang"
        return 0
    end

    # 获取配置文件中的语言设置
    set -l config_file ~/.config/brow/config.json
    if test -f $config_file
        set -l lang (jq -r '.language // ""' $config_file 2>/dev/null)
        if test -n "$lang" -a "$lang" != null
            _brow_i18n_load $lang
            return 0
        end
    end

    # 尝试使用系统语言
    set -l system_lang (string match -r '^[a-z]{2}' -- $LANG)
    if test -n "$system_lang"
        if _brow_i18n_load $system_lang
            return 0
        end
    end

    # 默认使用中文
    _brow_i18n_load zh
end

function _brow_i18n_load --argument-names lang
    # 加载指定语言的翻译文件
    # 参数:
    #   lang: 语言代码，如zh、en
    # 返回:
    #   0: 成功
    #   1: 失败（语言不支持）

    # 首先尝试从用户配置目录加载
    set -l user_i18n_dir ~/.config/brow/i18n
    set -l user_lang_file $user_i18n_dir/$lang.json

    # 如果用户配置目录中的语言文件不存在，尝试从插件目录加载
    set -l script_dir (dirname (status filename))
    set -l plugin_i18n_dir $script_dir/../i18n
    set -l plugin_lang_file $plugin_i18n_dir/$lang.json

    # 确保用户配置目录存在
    if not test -d $user_i18n_dir
        mkdir -p $user_i18n_dir
    end

    # 初始化语言文件路径
    set -l lang_file ""

    # 尝试从用户配置目录加载
    if test -f $user_lang_file
        set lang_file $user_lang_file
    else if test -f $plugin_lang_file
        # 如果插件目录中存在语言文件，复制到用户配置目录
        set lang_file $plugin_lang_file
        cp $plugin_lang_file $user_lang_file 2>/dev/null
    else
        # 如果指定的语言不存在，尝试使用默认语言
        if test "$lang" != zh
            echo "Language '$lang' not supported, falling back to Chinese" >&2
            _brow_i18n_load zh
            return $status
        end
        echo "Error: Language file not found in $user_i18n_dir or $plugin_i18n_dir" >&2
        return 1
    end

    # 读取语言文件
    set -l lang_data (cat $lang_file)
    if test $status -ne 0
        echo "Error: Failed to read language file: $lang_file" >&2
        return 1
    end

    # 设置当前语言和翻译字符串
    set -g _brow_i18n_current_lang $lang
    set -g _brow_i18n_strings $lang_data

    return 0
end

function _brow_i18n_get --argument-names key
    # 获取指定键的翻译字符串
    # 参数:
    #   key: 翻译键
    # 返回:
    #   翻译字符串，如果未找到则返回键本身

    # 确保i18n系统已初始化
    if test -z "$_brow_i18n_current_lang"
        _brow_i18n_init
    end

    # 从翻译字符串中获取指定键的值
    set -l value (echo $_brow_i18n_strings | jq -r ".[\"$key\"] // \"\"" 2>/dev/null)

    # 如果未找到翻译，返回键本身
    if test -z "$value" -o "$value" = null
        echo $key
        return 1
    end

    echo $value
    return 0
end

function _brow_i18n_format --argument-names key
    # 格式化翻译字符串，支持printf风格的格式化
    # 参数:
    #   key: 翻译键
    #   ...: 格式化参数
    # 返回:
    #   格式化后的翻译字符串

    # 获取翻译字符串
    set -l format (_brow_i18n_get $key)

    # 如果没有额外参数，直接返回翻译字符串
    if test (count $argv) -eq 1
        echo $format
        return 0
    end

    # 移除第一个参数（key）
    set -e argv[1]

    # 使用printf格式化字符串
    printf "$format" $argv
end

function _brow_i18n_set_language --argument-names lang
    # 设置当前语言
    # 参数:
    #   lang: 语言代码，如zh、en
    # 返回:
    #   0: 成功
    #   1: 失败（语言不支持）

    # 尝试加载语言
    if not _brow_i18n_load $lang
        return 1
    end

    # 更新配置文件
    set -l config_file ~/.config/brow/config.json
    if test -f $config_file
        # 读取现有配置
        set -l config_data (cat $config_file)

        # 更新语言设置
        set -l updated_config (echo $config_data | jq ".language = \"$lang\"")

        # 写入配置文件
        echo $updated_config >$config_file
    else
        # 创建配置目录
        mkdir -p (dirname $config_file)

        # 创建新的配置文件
        echo "{\"language\": \"$lang\"}" >$config_file
    end

    return 0
end

function _brow_i18n_get_available_languages
    # 获取可用的语言列表
    # 返回:
    #   可用语言的列表，以空格分隔

    # 首先检查用户配置目录
    set -l user_i18n_dir ~/.config/brow/i18n

    # 然后检查插件目录
    set -l script_dir (dirname (status filename))
    set -l plugin_i18n_dir $script_dir/../i18n

    # 合并两个目录中的语言文件
    set -l lang_files

    # 先检查用户配置目录
    if test -d $user_i18n_dir
        set -a lang_files (find $user_i18n_dir -name "*.json" 2>/dev/null)
    end

    # 再检查插件目录
    if test -d $plugin_i18n_dir
        set -a lang_files (find $plugin_i18n_dir -name "*.json" 2>/dev/null)
    end

    # 提取语言代码
    set -l langs
    for file in $lang_files
        set -l lang (basename $file .json)
        # 确保每种语言只出现一次
        if not contains $lang $langs
            set -a langs $lang
        end
    end

    # 返回语言列表
    echo (string join " " $langs)
end
