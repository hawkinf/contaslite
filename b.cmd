@echo off
REM Script para tirar snapshot automático do projeto
REM Executa o script PowerShell sem pedir confirmação
REM Uso: b.cmd (Clique duplo para executar)

powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0b.ps1" && (
    echo.
    echo [OK] Snapshot criado com sucesso!
    timeout /t 2 /nobreak
    exit /b 0
) || (
    echo.
    echo [ERRO] Falha ao criar snapshot
    pause
    exit /b 1
)
