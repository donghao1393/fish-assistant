# Brow 插件记忆库

本文档记录了 Brow 插件的设计、开发和改进历程，作为开发者的参考资料。

## 插件概述

Brow 是一个为 Fish Shell 设计的 Kubernetes 连接管理工具，它简化了与 Kubernetes 集群中服务的连接过程。主要功能包括：

- 配置管理：添加、编辑、查看和删除连接配置
- 连接管理：创建、列出和停止连接
- Pod 管理：创建、查看、删除和清理 Pod
- 端口转发：启动、列出和停止端口转发
- 国际化支持：支持中文、英文和俄语

## 核心设计理念

1. **抽象层设计**：通过配置名称管理连接，隐藏底层 Kubernetes 命令和资源
2. **分层命令结构**：基本命令（日常使用）和高级命令（精细控制）
3. **安全最佳实践**：使用代理 Pod 进行连接，支持 TTL 设置
4. **自动化管理**：自动管理 Pod 生命周期和端口转发

## 文件结构

```
plugins/brow/
├── README.md                 # 主要文档
├── completions/              # 命令补全
│   └── brow.fish             # 命令补全定义
├── conf.d/                   # 配置目录
│   └── brow.fish             # 配置文件
├── docs/                     # 文档目录
│   ├── chats/                # 开发讨论记录
│   └── memory.md             # 记忆库（本文件）
├── functions/                # 函数目录
│   ├── _brow_config.fish     # 配置管理函数
│   ├── _brow_forward.fish    # 端口转发函数
│   ├── _brow_i18n.fish       # 国际化支持函数
│   ├── _brow_parse_time.fish # 时间解析函数
│   ├── _brow_pod.fish        # Pod 管理函数
│   └── brow.fish             # 主函数
└── i18n/                     # 国际化目录
    ├── README.md             # 国际化文档
    ├── en.json               # 英文翻译
    ├── ru.json               # 俄语翻译
    └── zh.json               # 中文翻译
```

## 命令结构

### 主要命令

- `brow start <配置名称> [本地端口]`：创建连接到指定配置
- `brow list`：列出活跃的连接
- `brow stop <连接ID|配置名称>`：停止连接并删除 Pod

### 配置管理

- `brow config add <名称> <Kubernetes上下文> <IP> [本地端口] [远程端口] [服务名称] [TTL]`：添加新配置
- `brow config list`：列出所有配置
- `brow config show <名称>`：显示特定配置详情
- `brow config edit <名称>`：编辑配置
- `brow config remove <名称>`：删除配置

### 高级命令

#### Pod 管理

- `brow pod list`：列出当前所有 Pod
- `brow pod info <配置名称>`：查看指定配置的 Pod 详情
- `brow pod delete <配置名称>`：删除指定配置的 Pod
- `brow pod cleanup`：清理过期的 Pod

#### 端口转发管理

- `brow forward list`：列出活跃的转发（同 `brow list`）
- `brow forward stop <ID|配置名称>`：停止转发（不删除 Pod）
- `brow forward start <配置名称> [本地端口]`：开始端口转发（同 `brow start`）

#### 其他命令

- `brow health-check`：检查和修复不一致的状态
- `brow language [set <语言代码>]`：管理语言设置
- `brow version`：显示版本信息
- `brow help`：显示帮助信息

## 国际化支持

Brow 插件支持多语言，目前包括：

- 中文 (zh)：默认语言
- 英文 (en)
- 俄语 (ru)

国际化实现通过 `_brow_i18n.fish` 模块，主要函数包括：

- `_brow_i18n_init`：初始化国际化系统
- `_brow_i18n_load`：加载指定语言的翻译文件
- `_brow_i18n_get`：获取指定键的翻译字符串
- `_brow_i18n_format`：格式化翻译字符串，支持 printf 风格的格式化
- `_brow_i18n_set_language`：设置当前语言
- `_brow_i18n_get_available_languages`：获取可用的语言列表

语言文件存储在 `i18n/` 目录下，使用 JSON 格式。用户可以通过 `brow language set <语言代码>` 命令切换语言。

## 重要改进记录

### 1. 修复 sudo 密码输入问题

**问题**：使用 `--sudo` 选项访问低序号端口 (0-1023) 时，密码输入与程序输出混合，导致用户体验不佳。

**解决方案**：
- 使用 `sudo true` 命令先获取密码输入
- 密码输入完成后再启动端口转发
- 使用 `jobs -lp` 获取进程 ID，避免使用不兼容的 `$!` 变量

**实现细节**：
- 移除了临时文件和复杂的轮询逻辑
- 直接使用 Fish shell 提供的功能获取进程 ID
- 确保变量作用域正确，使 pid 在整个函数中可用

### 2. 命令一致性改进

**问题**：`brow connect` 和 `brow stop` 命令名称不一致，不符合直觉。

**解决方案**：
- 将 `brow connect` 命令改为 `brow start`，与 `brow stop` 形成一对
- 完全移除 `connect` 命令，不保留别名
- 确保所有引用都更新为 `start` 命令

**实现细节**：
- 更新了主函数中的命令处理逻辑
- 更新了自动补全文件
- 更新了所有语言的翻译文件
- 更新了帮助文本和示例

## 最佳实践

### 1. 命令设计

- 主要命令应该简单直观，遵循一致的命名规则（如 `start`/`stop` 对）
- 高级命令应该放在子命令下，如 `forward start`、`pod delete` 等

### 2. 国际化实现

- 所有用户可见的字符串都应该使用 `_brow_i18n_get` 或 `_brow_i18n_format` 函数
- 翻译键应该具有描述性，便于理解其用途
- 翻译文件应该保持同步，确保所有语言都有相同的键

### 3. 错误处理

- 所有可能的错误都应该有适当的错误消息
- 错误消息应该提供有用的信息，帮助用户解决问题
- 关键操作应该有确认步骤，避免意外操作

### 4. 进程管理

- 在 Fish shell 中获取后台进程 ID 应该使用 `jobs -lp`，而不是 `$!`（不兼容）
- 使用 `$last_pid` 变量时要注意作用域问题，特别是在函数中
- 在函数中使用 `$last_pid` 时，可能需要设置 `status job-control full`

### 5. 表格格式化

- 使用 `_pad_to_width` 函数处理表格格式化，确保正确处理中文等宽字符
- 使用 `string length --visible` 计算字符串的可见宽度，而不是字节长度

## 待改进事项

1. **性能优化**：减少不必要的 kubectl 调用，特别是在列出大量 Pod 时
2. **错误处理增强**：提供更详细的错误信息和恢复建议
3. **配置验证**：添加配置验证功能，确保配置有效
4. **自动补全增强**：提供更多上下文相关的自动补全信息
5. **文档完善**：添加更多示例和使用场景
