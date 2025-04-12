# Token Count

一个用于计算文本文件和PDF文件中token数量的Fish函数，主要用于LLM交互场景。

## 功能

- 支持纯文本文件和PDF文件
- 自动检测文件类型和编码
- 计算字符数、单词数和token数
- 显示文件大小和MIME类型

## 依赖

### Python包

- tiktoken - OpenAI的token计数库
- chardet - 字符编码检测
- python-magic - 文件类型检测
- pdfplumber - PDF文本提取

### 系统依赖

在macOS上，python-magic还需要安装系统依赖：

```bash
brew install libmagic
```

在Linux上，可能需要安装：

```bash
# Debian/Ubuntu
sudo apt-get install libmagic1

# CentOS/RHEL
sudo yum install file-devel
```

## 安装

自动安装（推荐）：

```bash
# 首次使用token_count命令时会自动安装
token_count 文件路径
```

手动安装：

```bash
# 在插件目录下运行安装脚本
cd /path/to/token_count
fish install.fish
```

此安装脚本使用uv创建Python虚拟环境并安装所有依赖。

## 使用方法

```bash
token_count <file_path>
```

示例：

```bash
token_count document.txt   # 处理文本文件
token_count document.pdf   # 处理PDF文件
```

## 输出示例

```
文件分析结果：
文件类型: application/pdf
编码: pdf
字符数: 12345
单词数: 2000
Token数: 2500
文件大小: 98765 bytes
