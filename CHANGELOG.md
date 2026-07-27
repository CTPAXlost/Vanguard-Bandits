# Vanguard Bandits Remaster 1.9.11

## Исправлено

- В `campaign_hub.gd` восстановлены отсутствовавшие обработчики `_save_progress()` и `_open_characters()`, из-за которых Godot выдавал parse error при загрузке `CampaignHub.tscn`.
- Добавлен отдельный обязательный runtime-тест `AllScriptsCompileSmoke.tscn`, который через нормальный запуск проекта загружает и компилирует каждый `.gd`-файл.
- Оба GitHub Actions workflow теперь останавливаются до игровых smoke-тестов, если хотя бы один GDScript не компилируется.
- Сохранены обязательные проверки миссий I–VI, обеих сторон миссии VI, магазина, моделей, замка и Windows-export.
- `continue-on-error` не используется.
