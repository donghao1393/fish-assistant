# Brow - Kubernetes 连接管理工具

![Brow Logo](https://img.shields.io/badge/Brow-Kubernetes%20连接管理工具-blue)
![Fish Shell](https://img.shields.io/badge/Shell-Fish-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

Brow 是一个为 Fish Shell 设计的 Kubernetes 连接管理工具，它简化了与 Kubernetes 集群中服务的连接过程，特别适合需要频繁连接到不同环境（开发、测试、生产）中的数据库或其他服务的开发人员和运维人员。

## 功能特点

- **简化连接管理**：通过配置名称一键创建连接，无需记忆复杂的 Kubernetes 命令
- **多环境支持**：轻松管理多个 Kubernetes 上下文和环境
- **安全连接**：使用 Kubernetes 代理 Pod 进行安全连接，无需暴露服务
- **自动清理**：自动管理 Pod 生命周期，避免资源泄漏
- **高级功能**：提供高级命令用于更精细的控制和管理

## 安装方法

### 前提条件

- [Fish Shell](https://fishshell.com/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) 命令行工具
- 对 Kubernetes 集群的访问权限

### 安装步骤

1. 克隆 fish-assistant 仓库：

```bash
git clone https://github.com/donghao1393/fish-assistant.git
cd fish-assistant
```

2. 将插件目录链接到 Fish 配置目录：

```bash
ln -f plugins/brow/functions/*.fish ~/.config/fish/functions/
ln -f plugins/brow/completions/*.fish ~/.config/fish/completions/
```

3. 重新加载 Fish 配置：

```bash
source ~/.config/fish/config.fish
```

> **注意**：Brow 会在首次运行时自动创建必要的配置目录和文件，无需手动设置。

## 使用方法

### 基本命令

#### 添加配置

```bash
brow config add <名称> <Kubernetes上下文> <IP> [本地端口] [远程端口] [服务名称] [TTL]
```

例如：

```bash
brow config add mysql-dev jygd-dev-aks 10.0.0.1 3306 3306 mysql 30m
```

#### 创建连接

```bash
brow connect <配置名称> [本地端口]
```

例如：

```bash
brow connect mysql-dev
```

#### 查看连接

```bash
brow list
```

#### 停止连接

```bash
brow stop <配置名称>
```

例如：

```bash
brow stop mysql-dev
```

### 高级命令

#### 管理 Pod

```bash
brow pod list                     # 列出当前所有 Pod
brow pod info <配置名称>         # 查看指定配置的 Pod 详情
brow pod delete <配置名称>       # 删除指定配置的 Pod
brow pod cleanup                  # 清理过期的 Pod
```

#### 管理端口转发

```bash
brow forward list                 # 列出活跃的转发
brow forward stop <配置名称>     # 停止转发 (不删除Pod)
brow forward start <配置名称>    # 开始端口转发
```

#### 健康检查

```bash
brow health-check                 # 检查和修复不一致的状态
```

### 配置管理

```bash
brow config list                  # 列出所有配置
brow config show <名称>           # 显示特定配置详情
brow config edit <名称>           # 编辑配置
brow config remove <名称>         # 删除配置
```

## 使用场景

### 场景一：开发人员连接到开发环境数据库

```bash
# 添加开发环境数据库配置
brow config add mysql-dev jygd-dev-aks 10.0.0.1 3306 3306 mysql 30m

# 连接到开发环境数据库
brow connect mysql-dev

# 使用本地客户端连接
mysql -h localhost -P 3306 -u user -p

# 完成工作后停止连接
brow stop mysql-dev
```

### 场景二：运维人员临时访问生产环境服务

```bash
# 添加生产环境服务配置
brow config add redis-prod jygd-prod-aks 10.0.1.2 6379 6379 redis 15m

# 连接到生产环境服务
brow connect redis-prod

# 使用本地客户端连接
redis-cli -h localhost -p 6379

# 临时断开连接但保留 Pod
brow forward stop redis-prod

# 稍后重新连接
brow forward start redis-prod

# 完成工作后停止连接并删除 Pod
brow stop redis-prod
```

### 场景三：管理多个环境的连接

```bash
# 添加多个环境的配置
brow config add mysql-dev jygd-dev-aks 10.0.0.1 3306 3306 mysql 30m
brow config add mysql-test jygd-test-aks 10.0.1.1 3307 3306 mysql 30m
brow config add mysql-prod jygd-prod-aks 10.0.2.1 3308 3306 mysql 15m

# 查看所有配置
brow config list

# 同时连接到多个环境
brow connect mysql-dev
brow connect mysql-test
brow connect mysql-prod

# 查看所有连接
brow list

# 完成工作后停止所有连接
brow stop mysql-dev
brow stop mysql-test
brow stop mysql-prod
```

## 设计理念

Brow 插件的设计基于以下几个核心理念：

### 1. 抽象层设计

Brow 提供了一个抽象层，使用户可以通过配置名称来管理连接，而不需要关心底层的 Kubernetes 命令和资源。这种设计使得用户可以更加专注于业务需求，而不是技术细节。

### 2. 分层命令结构

Brow 的命令结构分为基本命令和高级命令两层：

- **基本命令**：适合日常使用，简单直观
- **高级命令**：提供更精细的控制，适合高级用户和特殊场景

### 3. 安全最佳实践

Brow 遵循 Kubernetes 安全最佳实践，使用代理 Pod 进行连接，避免直接暴露服务。同时，它提供了 TTL（生存时间）设置，确保连接不会无限期存在。

### 4. 自动化管理

Brow 自动管理 Pod 的生命周期和端口转发，减少了用户的操作负担。它还提供了健康检查功能，自动检测和修复不一致的状态。

## 贡献指南

欢迎贡献代码、报告问题或提出改进建议！请通过 GitHub Issues 或 Pull Requests 参与项目开发。

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

## 作者

- [董昊](https://github.com/donghao1393)

## 致谢

- 感谢 Fish Shell 社区提供的优秀工具
- 感谢 Kubernetes 社区的支持和贡献
