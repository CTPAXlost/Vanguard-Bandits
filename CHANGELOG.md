# Vanguard Bandits Remaster 1.9.12

## Исправлено

- Устранён parse error Godot 4.6.3 в `model_gallery.gd`: события мыши и клавиатуры теперь явно приводятся к `InputEventMouseButton`, `InputEventMouseMotion` и `InputEventKey`; `delta_mouse` имеет явный тип `Vector2`.
- Исправлена ложноположительная проверка `AllScriptsCompileSmoke`: простой `load()` раньше мог вернуть ресурс скрипта после ошибки компиляции, из-за чего тест печатал `ALL_GDSCRIPT_COMPILE_OK`. Теперь каждый ресурс загружается как `Script` с заменой кеша и обязан пройти `Script.can_instantiate()`.
- Добавлены регрессионные Python-тесты, запрещающие возврат небезопасного `var delta_mouse := event.position ...` и проверяющие честное падение compile-smoke.
- Версии проекта и Windows export metadata обновлены до 1.9.12.
- Сохранены обязательные Godot import, компиляция всех GDScript, миссии I–VI, обе стороны миссии VI, runtime-smoke и Windows-export.
- `continue-on-error` не используется.

## Изученная рабочая сборка

Загруженный рабочий Windows x64 архив разобран как эталон. EXE содержит встроенный PCK Godot 4.6.3 с 1199 файлами, включая `ModelGallery`, `CampaignHub`, `BattlePrototype`, `Mission6Smoke`, `mission_06.json` и скомпилированные GDScript-ресурсы. Исходный код из `.gdc` не подменялся и не восстанавливался; рабочая сборка использована для проверки состава и наличия ключевых ресурсов.
