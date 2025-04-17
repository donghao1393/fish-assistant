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
```

3. 在项目根目录下安装 git hooks：

```bash
cd /path/to/fish-assistant
pre-commit install
```

## 使用

安装后，每次执行 `git commit` 命令时，pre-commit 会自动运行配置的检查。如果检查失败，commit 将被阻止，并显示错误信息。

你也可以手动运行检查：

```bash
# 检查所有文件
pre-commit run --all-files

# 检查特定文件
pre-commit run --files plugins/fa/functions/fa.fish
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
pre-commit autoupdate
```

## 配置文件

pre-commit 的配置在项目根目录的 `.pre-commit-config.yaml` 文件中。你可以根据需要修改此文件，添加或删除检查项。
