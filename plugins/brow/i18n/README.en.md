# brow Plugin Internationalization Support

The brow plugin supports multiple languages. Currently, the following languages are supported:

- Chinese (zh)
- English (en)
- Russian (ru)

## How to Switch Languages

Use the following command to view the current language and available languages:

```fish
brow language
```

Use the following command to switch languages:

```fish
brow language set <language_code>
```

For example, to switch to English:

```fish
brow language set en
```

## How to Add Support for a New Language

1. Create a new JSON file in the `~/.config/brow/i18n/` directory, with the filename as the language code, e.g., `fr.json` for French
2. Copy the contents of `zh.json` or `en.json` and translate all the strings
3. Reload the brow plugin or restart the fish shell
4. Use the `brow language set <language_code>` command to switch to the new language

## Translation File Format

The translation file is a JSON file containing all the strings that need to be translated. Each string has a unique key, for example:

```json
{
  "pod_list_title": "Active brow Pods:",
  "pod_name": "Pod Name",
  "config": "Config",
  "service": "Service",
  "created_at": "Created At",
  "ttl": "TTL",
  "status": "Status",
  "context": "Context",
  "no_pods_found": "No active brow Pods found"
}
```

When translating, only translate the values on the right side, do not modify the keys on the left side.

## Format Strings

Some strings contain placeholders, such as `%s`, which will be replaced with actual values at runtime. When translating, you need to preserve these placeholders, for example:

```json
"pod_ready": "Pod '%s' created and ready"
```

In the Chinese translation:

```json
"pod_ready": "Pod '%s' 已创建并就绪"
```

Make sure the number and order of placeholders are the same as in the original string.

## Notes

- Translation files must use UTF-8 encoding
- Translation files must be valid JSON format
- Translation files must include all strings that need to be translated, otherwise they will be displayed as empty strings
- If a key is missing in the translation file, the default language (Chinese) translation will be used
