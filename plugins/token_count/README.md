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
token_count [-h|--human-readable] [-v|--verbose] <file_path> [file_path...]
```

### 参数

- `-h` 或 `--human-readable`: 使用人类可读格式显示数字（如K/M/G等）
- `-v` 或 `--verbose`: 显示详细处理信息和警告（默认不显示）

### 示例

```bash
token_count document.txt                 # 处理单个文本文件
token_count document.pdf                 # 处理单个PDF文件
token_count *.md                         # 处理所有Markdown文件
token_count document1.txt document2.txt  # 处理多个指定文件
token_count -h *.md                      # 使用人类可读格式显示所有Markdown文件的统计
token_count -v document.pdf              # 处理PDF文件并显示详细警告信息
```

### 单文件输出示例

```
文件分析结果：
文件: document.txt
文件类型: text/plain
编码: utf-8
字符数: 12345
单词数: 2000
Token数: 2500
文件大小: 98765 bytes
```

### 单文件输出示例（人类可读格式）

```
文件分析结果：
文件: document.txt
文件类型: text/plain
编码: utf-8
字符数: 12.3K
单词数: 2.0K
Token数: 2.5K
文件大小: 96.5 KB
```

### 多文件输出示例

```
文件统计表格：
```
文件统计表格：
文件                          	类型        	编码    	字符数    	单词数    	Token数    	大小            
------------------------------	------------	--------	----------	----------	----------	---------------
file1.txt                      	text/plain  	utf-8   	1000      	200       	300       	1500 bytes      
file2.txt                      	text/plain  	utf-8   	2000      	400       	600       	3000 bytes      
------------------------------	------------	--------	----------	----------	----------	---------------
总计(2文件)                 	            	        	3000      	600       	900       	4500 bytes      
```

### 多文件输出示例（人类可读格式）

```
文件统计表格：
文件                          	类型        	编码    	字符数    	单词数    	Token数    	大小            
------------------------------	------------	--------	----------	----------	----------	---------------
file1.txt                      	text/plain  	utf-8   	1.0K      	200       	300       	1.5 KB           
file2.txt                      	text/plain  	utf-8   	2.0K      	400       	600       	2.9 KB           
------------------------------	------------	--------	----------	----------	----------	---------------
总计(2文件)                 	            	        	3.0K      	600       	900       	4.4 KB           
```
