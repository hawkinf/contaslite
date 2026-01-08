@echo off
set DATA=%date% %time%
echo Salvando alteracoes em: %DATA%

:: Adiciona todos os arquivos (incluindo pubspec.yaml, lib, etc)
git add .

:: Faz o commit com a data e hora
git commit -m "Backup pre-alteracao: %DATA%"

echo.
echo Pronto! Alteracoes salvas localmente.
pause