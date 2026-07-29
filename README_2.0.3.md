# Vanguard Bandits Remaster 2.0.3

Исправление компиляции цепочки кампании в Godot 4.6.3.

- Общая проверка headless/smoke перенесена в базовый `scripts/campaign_battle.gd`.
- Миссии I–VII теперь наследуют один и тот же доступный метод.
- Устранена ошибка `Function _is_headless_or_smoke_runtime() not found in base self`.
- Устранено каскадное падение загрузки `campaign_battle_v08/v12/v18/v19/v20`.
- Добавлена статическая защита от возврата этой ошибки.

Подробности: `CHANGELOG_2.0.3.txt`.
