# Vanguard Bandits Remaster 1.9.12

Исправление реальной ошибки компиляции Godot 4.6.3 из лога `logs_82049256476.zip` и усиление проверки GDScript без маскировки ошибок.

Перед Windows-export GitHub Actions обязательно выполняет:

1. Python-тесты.
2. Импорт проекта Godot 4.6.3.
3. Загрузку и проверку `Script.can_instantiate()` для каждого GDScript.
4. Загрузку миссий I–VI, включая обе стороны миссии VI.
5. Runtime-smoke основных сцен и механик.
6. Windows-export.

Ошибки не маскируются, `continue-on-error` отсутствует.
