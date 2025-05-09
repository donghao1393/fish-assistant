# Поддержка интернационализации плагина brow

Плагин brow поддерживает отображение на нескольких языках. В настоящее время поддерживаются следующие языки:

- Китайский (zh)
- Английский (en)
- Русский (ru)

## Как переключить язык

Используйте следующую команду для просмотра текущего языка и доступных языков:

```fish
brow language
```

Используйте следующую команду для переключения языка:

```fish
brow language set <код_языка>
```

Например, для переключения на русский:

```fish
brow language set ru
```

## Как добавить поддержку нового языка

1. Создайте новый JSON-файл в директории `~/.config/brow/i18n/`, с именем файла в виде кода языка, например, `fr.json` для французского
2. Скопируйте содержимое `zh.json` или `en.json` и переведите все строки
3. Перезагрузите плагин brow или перезапустите fish shell
4. Используйте команду `brow language set <код_языка>` для переключения на новый язык

## Формат файла перевода

Файл перевода - это JSON-файл, содержащий все строки, которые необходимо перевести. Каждая строка имеет уникальный ключ, например:

```json
{
  "pod_list_title": "Активные Поды brow:",
  "pod_name": "Имя Пода",
  "config": "Конфигурация",
  "service": "Сервис",
  "created_at": "Создан",
  "ttl": "TTL",
  "status": "Статус",
  "context": "Контекст",
  "no_pods_found": "Активные Поды brow не найдены"
}
```

При переводе переводите только значения справа, не изменяйте ключи слева.

## Строки форматирования

Некоторые строки содержат заполнители, такие как `%s`, которые будут заменены фактическими значениями во время выполнения. При переводе необходимо сохранить эти заполнители, например:

```json
"pod_ready": "Под '%s' создан и готов"
```

В английском переводе:

```json
"pod_ready": "Pod '%s' created and ready"
```

Убедитесь, что количество и порядок заполнителей такие же, как в исходной строке.

## Примечания

- Файлы перевода должны использовать кодировку UTF-8
- Файлы перевода должны быть в правильном формате JSON
- Файлы перевода должны включать все строки, которые необходимо перевести, иначе они будут отображаться как пустые строки
- Если ключ отсутствует в файле перевода, будет использован перевод языка по умолчанию (китайский)
