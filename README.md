# Fish Scripts Manager

一个用于管理 Fish Shell 函数和插件的工具集，帮助你以更结构化的方式组织你的 Fish 配置文件。

## 特性

- 结构化的目录组织
  - `functions/common/`: 通用工具函数
  - `functions/apps/`: 应用特定函数
  - `completions/`: 自动补全脚本
  - `plugins/`: 完整的功能模块

- 便捷的管理工具 `fa` (Fish Assistant)
  - 创建新插件：`fa plugin add <name>`
  - 映射插件文件：`fa plugin map <name>`
  - 创建单个链接：`fa map <type> <file>`
  - 查看所有链接：`fa list`
  - 检查链接状态：`fa check`
  - 清理无效链接：`fa clean`

- 智能的自动补全
  - 命令和子命令补全
  - 文件类型补全
  - 动态文件名补全

## 安装

1. 克隆仓库：
```fish
git clone https://github.com/username/fish-toolkit.git ~/dev/scripts/fish
```

2. 链接主程序：
```fish
mkdir -p ~/.config/fish/{functions,completions}
ln -sf ~/dev/scripts/fish/plugins/fa/functions/fa.fish ~/.config/fish/functions/
ln -sf ~/dev/scripts/fish/plugins/fa/completions/fa.fish ~/.config/fish/completions/
```

## 使用方法

### 创建新插件

```fish
# 创建一个新的插件目录结构
fa plugin add myplugin

# 编辑插件文件
vi ~/dev/scripts/fish/plugins/myplugin/functions/myplugin.fish
vi ~/dev/scripts/fish/plugins/myplugin/completions/myplugin.fish

# 映射插件到 Fish 配置目录
fa plugin map myplugin
```

### 管理单个函数

```fish
# 映射通用函数
fa map common util.fish

# 映射应用特定函数
fa map apps mytool.fish

# 映射补全文件
fa map completions mytool.fish

# 查看所有已创建的链接
fa list

# 检查链接状态
fa check

# 清理失效的链接
fa clean
```

### 目录结构

```
~/dev/scripts/fish/
├── README.md
├── functions/          # 存放所有函数文件
│   ├── common/        # 通用函数
│   └── apps/          # 特定应用的函数
├── completions/        # 存放所有补全文件
└── plugins/           # 存放完整的插件
    └── example/       # 示例插件
        ├── functions/
        └── completions/
```

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

[MIT](LICENSE)