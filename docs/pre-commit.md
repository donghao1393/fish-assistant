# Pre-commit 钩子

本项目使用 [pre-commit](https://pre-commit.com/) 来运行代码质量检查，确保提交的代码符合基本的质量标准。

## 安装

1. 首先，确保已安装 uv：

```bash
# 检查 uv 是否安装
uv --version

# 如果没有安装，可以使用 curl 安装
curl -LsSf https://astral.sh/uv/install.sh | sh
```

2. 安装 pre-commit：

```bash
# 使用 uv 安装
uv pip install pre-commit

# 或者在项目目录下创建虚拟环境并安装
uv venv
uv pip install pre-commit

# 注意：如果 uv 命令不可用，可以使用完整路径
/path/to/uv pip install pre-commit
```

3. 在项目根目录下安装 git hooks：

```bash
cd /path/to/fish-assistant
uv run pre-commit install

# 注意：如果 uv 命令不可用，可以使用完整路径
/path/to/uv run pre-commit install

# 或者如果已经激活了虚拟环境，可以直接使用
pre-commit install
```

## 使用

### 自动检查和修复

安装 pre-commit hooks 后，它会自动集成到 git 的提交流程中。当你执行 `git commit` 命令时，pre-commit 会自动运行配置的检查，无需手动执行任何额外命令。

对于许多检查项（如尾随空格、文件结束换行符等），pre-commit 会自动修复问题，然后让你重新暂存修复后的文件。

例如，如果你的文件中有尾随空格，当你尝试提交时，pre-commit 会：

1. 自动删除尾随空格
2. 显示一条消息，说明文件已被修改
3. 阻止提交，要求你重新暂存修复后的文件
4. 当你重新暂存并再次提交时，检查将通过

### 手动运行检查

虽然 pre-commit 会在提交时自动运行，但你也可以手动运行检查，以提前发现和修复问题：

```bash
# 检查所有文件
uv run pre-commit run --all-files

# 检查特定文件
uv run pre-commit run --files plugins/fa/functions/fa.fish

# 注意：如果 uv 命令不可用，可以使用完整路径
/path/to/uv run pre-commit run --all-files

# 或者如果已经激活了虚拟环境，可以直接使用
pre-commit run --all-files
```

## 跳过检查

在特殊情况下，可以跳过 pre-commit 检查：

```bash
git commit -m "紧急修复" --no-verify
```

但请谨慎使用此选项，尽量确保代码符合质量标准。

## 更新钩子

定期更新 pre-commit 钩子以获取最新的检查规则：

```bash
uv run pre-commit autoupdate

# 注意：如果 uv 命令不可用，可以使用完整路径
/path/to/uv run pre-commit autoupdate

# 或者如果已经激活了虚拟环境，可以直接使用
pre-commit autoupdate
```

## 配置文件

pre-commit 的配置在项目根目录的 `.pre-commit-config.yaml` 文件中。你可以根据需要修改此文件，添加或删除检查项。
