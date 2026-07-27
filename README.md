# Vanguard Bandits Remaster 1.9.11

Исправление загрузки лагеря кампании и усиление проверки GDScript.

Перед Windows-export GitHub Actions обязательно выполняет:

1. Python-тесты.
2. Импорт проекта Godot 4.6.3.
3. Компиляцию всех GDScript через `AllScriptsCompileSmoke.tscn`.
4. Загрузку миссий I–VI, включая обе стороны миссии VI.
5. Runtime-smoke основных сцен и механик.
6. Windows-export.

Ошибки не маскируются, `continue-on-error` отсутствует.
