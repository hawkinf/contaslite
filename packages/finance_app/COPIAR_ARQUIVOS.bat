@echo off
echo.
echo ========================================
echo   COPIANDO ARQUIVOS ATUALIZADOS
echo ========================================
echo.

REM Copiar o arquivo correto
copy /Y "lib\widgets\new_expense_dialog.dart" "C:\flutter\contas_pagar\lib\widgets\new_expense_dialog.dart"

echo.
echo ========================================
echo   ARQUIVO COPIADO!
echo ========================================
echo.
echo Agora faca:
echo 1. No terminal do Flutter, pressione: R
echo 2. Ou feche o app e deixe reabrir
echo.
pause
