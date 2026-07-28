# Vanguard Bandits Remaster 2.0.0

Проект рассчитан на **Godot 4.6.3**. Архив подготовлен как корень GitHub-репозитория: `project.godot`, `.github`, `assets`, `data`, `scenes`, `scripts` и `tools` находятся на верхнем уровне.

## Главное обновление

- официальный баланс открытия приёмов для 34 ATAC;
- опыт и повышение уровня непосредственно в бою;
- три очка характеристик за уровень и прокачка в лагере/бою;
- исправленный путь Kamorge: Barazaph в миссиях I–III, Eigol только после выживания в третьей миссии;
- исправленные цельные изображения старых ATAC;
- последствия союза с Logan или Alden;
- новые Milea/Panther, Puck/Engineer и Ganlon/Waiban;
- глава VII «Штурм имперского замка»;
- отдельные эффекты Crimson, Snow Soldier и Altagrave.

Полный перечень изменений находится в `CHANGELOG_2.0.0.txt`.

## Проверка

Локальная статическая проверка:

```bash
python3 tools/validate_project.py
```

GitHub Actions выполняет импорт Godot, компиляцию всех GDScript, загрузку миссий I–VII, сюжетные smoke-тесты и Windows x64 export. Workflow не использует `continue-on-error`.
