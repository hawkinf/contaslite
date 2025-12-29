@echo off
echo ========================================
echo   INSTALADOR - CONTAS A PAGAR v2.0
echo ========================================
echo.

REM Verifica se Flutter está instalado
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERRO] Flutter nao encontrado!
    echo.
    echo Por favor, instale o Flutter primeiro:
    echo https://docs.flutter.dev/get-started/install
    echo.
    pause
    exit /b 1
)

echo [OK] Flutter encontrado!
flutter --version
echo.

echo ========================================
echo   Instalando dependencias...
echo ========================================
call flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo [ERRO] Falha ao instalar dependencias!
    pause
    exit /b 1
)
echo [OK] Dependencias instaladas!
echo.

echo ========================================
echo   Verificando configuracao...
echo ========================================
call flutter doctor
echo.

echo ========================================
echo   Opcoes de Execucao
echo ========================================
echo 1. Executar em modo debug (desenvolvimento)
echo 2. Compilar versao release (producao)
echo 3. Sair
echo.
set /p opcao="Escolha uma opcao (1-3): "

if "%opcao%"=="1" (
    echo.
    echo Iniciando em modo debug...
    flutter run -d windows
) else if "%opcao%"=="2" (
    echo.
    echo Compilando versao release...
    echo Isso pode levar alguns minutos...
    flutter build windows --release
    echo.
    echo [OK] Compilacao concluida!
    echo.
    echo O executavel esta em: build\windows\runner\Release\
    echo.
    pause
) else if "%opcao%"=="3" (
    echo Saindo...
    exit /b 0
) else (
    echo Opcao invalida!
    pause
    exit /b 1
)
