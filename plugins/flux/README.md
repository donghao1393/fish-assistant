# Flux Image Generator

一个使用 Flux AI 模型生成图像的工具。

## 功能

- 支持不同模型: `flux-pro-1.1` 和 `flux-pro-1.1-ultra`
- 自定义宽高比和尺寸
- 支持随机种子设置
- 自动保存生成的图像和提示词

## 安装

使用 uv 创建和设置虚拟环境:

```bash
mkdir -p ~/studio/scripts/fish/plugins/flux
cd ~/studio/scripts/fish/plugins/flux
uv venv .venv
uv pip install -e .
```

## 使用方法

在 fish shell 中:

```fish
flux -p "一个美丽的风景"
```

或者从文件读取提示词:

```fish
flux -f prompt.txt
```

查看帮助:

```fish
flux --help
```

## 环境变量

- `BFL_API_KEY`: 你的 Flux AI API 密钥
- `SCRIPTS_DIR`: 指向脚本目录的路径
