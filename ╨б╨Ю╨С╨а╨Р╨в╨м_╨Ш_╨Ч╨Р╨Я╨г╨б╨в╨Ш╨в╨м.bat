@echo off
chcp 65001 >nul
set GODOT=godot4.exe
where %GODOT% >nul 2>nul
if errorlevel 1 (
  set GODOT=godot.exe
)
where %GODOT% >nul 2>nul
if errorlevel 1 (
  echo Godot 4 не найден в PATH.
  echo Установите Godot 4.6.3 или собирайте проект через GitHub Actions.
  pause
  exit /b 1
)
%GODOT% --editor --path "%~dp0project"
