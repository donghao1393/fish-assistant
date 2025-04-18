# brow 插件国际化支持

brow 插件支持多语言显示，目前支持以下语言：

- 中文 (zh)
- 英文 (en)

## 如何切换语言

使用以下命令查看当前语言和可用语言：

```fish
brow language
```

使用以下命令切换语言：

```fish
brow language set <语言代码>
```

例如，切换到英文：

```fish
brow language set en
```

## 如何添加新的语言支持

1. 在 `~/.config/brow/i18n/` 目录下创建一个新的 JSON 文件，文件名为语言代码，例如 `fr.json` 表示法语
2. 复制 `zh.json` 或 `en.json` 文件的内容，并翻译所有的字符串
3. 重新加载 brow 插件或重启 fish shell
4. 使用 `brow language set <语言代码>` 命令切换到新的语言

## 翻译文件格式

翻译文件是一个 JSON 文件，包含所有需要翻译的字符串。每个字符串都有一个唯一的键，例如：

```json
{
  "pod_list_title": "活跃的brow Pod:",
  "pod_name": "Pod名称",
  "config": "配置",
  "service": "服务",
  "created_at": "创建时间",
  "ttl": "TTL",
  "status": "状态",
  "context": "上下文",
  "no_pods_found": "没有找到活跃的brow Pod"
}
```

翻译时，只需要翻译右侧的值，不要修改左侧的键。

## 格式化字符串

有些字符串包含占位符，例如 `%s`，这些占位符会在运行时被替换为实际的值。翻译时，需要保留这些占位符，例如：

```json
"pod_ready": "Pod '%s' 已创建并就绪"
```

在英文翻译中：

```json
"pod_ready": "Pod '%s' created and ready"
```

确保占位符的数量和顺序与原始字符串相同。

## 注意事项

- 翻译文件必须使用 UTF-8 编码
- 翻译文件必须是有效的 JSON 格式
- 翻译文件必须包含所有需要翻译的字符串，否则会显示为空字符串
- 如果翻译文件中缺少某个键，会使用默认语言（中文）的翻译
