## 1.6.1 — Исправление сборки Campaign Hub

- Добавлен отсутствовавший помощник `_set_status()` в `campaign_hub.gd`.
- Исправлена ошибка компиляции Godot: `Function "_set_status()" not found in base self`.
- Добавлен регрессионный тест для Campaign Hub и сохранена его headless smoke-проверка в GitHub Actions.
- Игровая логика, баланс, сохранения и содержимое версии 1.6 не изменялись.

# Changelog

## 1.4.1 — исправление GitHub smoke-тестов

- Исправлено неверное понимание `--quit-after`: значение задаётся в кадрах.
- ArenaSmoke теперь получает достаточно времени для завершения анимации.
- Mission3Smoke и Mission4Smoke безопасно создают боевую сцену после кадра и печатают контрольные маркеры.
- Удаление временных узлов арены выполняется отложенно через `queue_free()`.


## 1.4.0 — исправление миссии 4, союзного ИИ и арена атак

- Диалог Kamorge из первой миссии теперь жёстко привязан к карте приграничной деревни и больше не появляется в главе IV.
- Исправлено повторное появление Kamorge в миссии 4.
- Тактическое поле всегда использует стабильные многовидовые модели; статические GLB больше не могут сделать юнита невидимым или чрезмерно плотным на карте.
- Союзный ИИ выбирает реально достижимую цель, прокладывает путь через ворота, повторно оценивает цели после движения и атакует, если вошёл в радиус.
- Добавлена экспериментальная отдельная арена атак: после выбора приёма и цели показывается крупный план атакующего и противника, движение, удар или снаряд, реакция на попадание и возврат на карту.
- Арена включена по умолчанию и отключается в лагере. Её SubViewport полностью выключен вне атаки, поэтому новый режим не создаёт постоянной нагрузки.
- Добавлены изображения мечей, амулетов и камня Опал в список товаров и панель предпросмотра магазина.
- Уменьшен портрет и включён перенос длинных подписей в правой панели боя.
- Формат сохранения обновлён до версии 14.
- Добавлен отдельный GitHub Actions smoke-тест арены.

## 1.3.1 — исправление сборки GitHub

- Исправлен `.gitignore`: оптимизированные GLB-модели Alba, Serata и Glaive теперь добавляются в репозиторий.
- Добавлен регрессионный тест, чтобы GitHub Actions больше не падал из-за отсутствующих `*_optimized.glb`.
- Игровая логика и формат сохранения версии 13 не изменялись.

## 1.3.0 — критическая оптимизация и диагностика

- Ограничена частота кадров до 60 FPS, включены VSync и low processor mode.
- Добавлен глобальный PerformanceGuard: F10 показывает FPS, RAM, VRAM, draw calls и используемый GPU; F9 включает безопасный режим 30 FPS без теней.
- Добавлен журнал `user://performance_v13.log` для поиска утечек и неправильного видеоадаптера.
- Текстуры многовидовых ATAC теперь загружаются лениво и совместно используются одинаковыми юнитами вместо дублирования в памяти.
- Проверка ракурса 2.5D-модели выполняется с интервалом, а не каждый кадр.
- Сотни отдельных клеток карты заменены пакетным MultiMesh-рендерингом; вода и стены замка также объединены в пакеты.
- Alba, Serata и Glaive переведены с десятков отдельных OBJ-материалов на компактные одно-материальные GLB-модели.
- Исправлено ошибочное превращение Serata и Glaive в Barbatos при возврате к 2.5D.
- Исправлена невидимость Eigol в четвёртой миссии.
- Уточнён статус 3D: текущие модели статические, без Skeleton3D/Skin; полноценное скелетное анимирование вынесено в следующий этап после проверки стабильности.

## 1.2.0 — штурм замка, общий магазин и экспериментальный 3D

- Кошелёк окончательно переведён в единый фонд всей команды.
- Добавлен общий магазин, общий склад, экипировка персонажей и продажа предметов за 40% стоимости.
- Добавлены улучшенные мечи, Амулет единства и камень умения «Опал» с усилением «Яркой бомбы» на 10%.
- Добавлена четвёртая миссия «Штурм имперского замка» для ветки выжившего Kamorge.
- Kamorge получает Eigol 20-го уровня и новые способности: Буря в пустыне, Зыбучие пески, Вязкая буря в песках и запрет лечения.
- Добавлены Galvas / Serata 18-го уровня и восстанавливающая аура +15 HP/энергии в радиусе трёх клеток.
- Добавлены General Zakov / Einlager, ловушка раз в пять раундов, Duyere с отступлением ниже 40% HP, четыре Captain Soldiers и Barbatos.
- Добавлены Zeira и пять союзных ИИ-гвардейцев на Glaive, прибывающие подкреплением.
- Добавлены вступительные, боевые, отступательные и финальные диалоги новой главы.
- Добавлен экспериментальный настоящий 3D-режим для Alba, Serata и Glaive с безопасным возвратом к 2.5D.
- Экран тестового выбора расширен четвёртой миссией.
- Формат сохранения обновлён до версии 12 с миграцией старой короткой миссии Eigol.

## 1.1.0 — выбор миссий и монеты

- Добавлен отдельный экран выбора миссий с русскими названиями.
- Миссию 3 можно запустить сразу в двух тестовых вариантах: союз с партизанами или плен.
- Добавлен кошелёк и сохранение монет.
- За уничтожение обычного ATAC начисляется 25 монет, командирского — 50, элитного — 75.
- За первое завершение миссий начисляется 200, 300 и 500 монет соответственно.
- Старые сохранения автоматически получают награды за уже завершённые миссии.
- Баланс монет отображается в главном меню, лагере и во время боя.
- Подготовлена экономика для магазина следующей миссии.

## 1.0.0

- Corrected both outcomes of the bridge decision.
- Added a multi-exchange Faulkner versus Kamorge duel before Kamorge dies.
- Added Ione / Amphisia level 8, Reyna / Haurol level 10 and Zeira / Toreadore level 18.
- Added spear throw, ice rain with 30% freeze, ultrasound confusion and the high-energy slide attack.
- Added Toreadore double movement, three 50% energy restorations and automatic 200% rear kick with five-cell knockback.
- Added forest-partisan rescue combat and branch-specific forest camp story.
- Added the no-help three-round resistance followed by Bastion and Andrew's capture.
- Retained the old Eigol mission data only for save compatibility; it is no longer routed from the bridge choice.
- Save format upgraded to version 10.

## 0.9.0

- Compact unshaded MultiView rendering and smoother 16-phase movement.
- Permanent Kamorge death branch.
- Escape branch with lost Barazaph and solo Eigol mission.
- Eigol attacks, Desert Whirl, Quicksand status effects.
- Imperial prison story scene and save migration.
- Added Mission 4 and story scene smoke tests.

## 1.5 — Cinematic arena and ATAC visibility

- Fixed tactical ATAC sheets disappearing or turning edge-on from rotated camera angles.
- Added a top-level camera-facing rig, safer visibility bounds and higher-quality alpha edges.
- Unified the 3D attack arena for player, allied AI, enemy AI and counterattacks.
- Enforced inward combatant facing and mirrored three-quarter artwork for multiview ATACs.
- Rebuilt melee, projectile, ice, ultrasound and sand effects with hit-stop and camera reaction.
- Added GitHub runtime smoke tests for AI arena attacks and four-angle tactical visibility.

## 1.6 — Tactical control and individual combat animation
- Removed the separate 3D battle arena from normal gameplay.
- Added keyboard-facing controls, a target list, and safe move undo.
- Unified tactical attack presentation for player, allied AI, enemy AI, and counterattacks.
- Added per-skill color, focus, impact, and particle presentation while preserving unique skill effects.
