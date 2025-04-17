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

2. 设置环境变量：

在 `~/.config/fish/config.fish` 中添加以下内容：
```fish
# 设置 Fish Assistant 的根目录
set -gx FISH_ASSISTANT_HOME /path/to/fish-assistant
```

请将 `/path/to/fish-assistant` 替换为实际的项目根目录路径。

3. 链接主程序：
```fish
mkdir -p ~/.config/fish/{functions,completions}
# 使用硬链接而非软链接
ln -f $FISH_ASSISTANT_HOME/plugins/fa/functions/fa.fish ~/.config/fish/functions/
ln -f $FISH_ASSISTANT_HOME/plugins/fa/completions/fa.fish ~/.config/fish/completions/
```

## 使用方法

### 创建新插件

```fish
# 创建一个新的插件目录结构
fa plugin add myplugin

# 编辑插件文件
vi $FISH_ASSISTANT_HOME/plugins/myplugin/functions/myplugin.fish
vi $FISH_ASSISTANT_HOME/plugins/myplugin/completions/myplugin.fish

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
$FISH_ASSISTANT_HOME/
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

## 开发贡献

### 代码质量

本项目使用 pre-commit 来自动运行代码质量检查。它会在你执行 `git commit` 时自动运行，并且可以自动修复简单的问题（如尾随空格、文件结束换行符等）。

详细信息请参考 [docs/pre-commit.md](docs/pre-commit.md)。

### 如何贡献

1. Fork 本仓库
2. 在项目目录下创建虚拟环境并安装依赖: `uv venv && uv pip install pre-commit`
3. 安装 pre-commit hooks: `uv run pre-commit install`
   (如果 uv 命令不可用，请参考 [docs/pre-commit.md](docs/pre-commit.md) 中的说明)
4. 创建功能分支: `git checkout -b feature/your-feature-name`
5. 提交更改: `git commit -m "添加新功能"`
6. 推送到你的 Fork: `git push origin feature/your-feature-name`
7. 创建 Pull Request

欢迎提交 Issue 和 Pull Request！

## 许可证

[MIT](LICENSE)
