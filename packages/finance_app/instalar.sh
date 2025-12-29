#!/bin/bash

echo "========================================"
echo "  INSTALADOR - CONTAS A PAGAR v2.0"
echo "========================================"
echo ""

# Verifica se Flutter está instalado
if ! command -v flutter &> /dev/null; then
    echo "[ERRO] Flutter não encontrado!"
    echo ""
    echo "Por favor, instale o Flutter primeiro:"
    echo "https://docs.flutter.dev/get-started/install"
    echo ""
    exit 1
fi

echo "[OK] Flutter encontrado!"
flutter --version
echo ""

echo "========================================"
echo "  Instalando dependências..."
echo "========================================"
flutter pub get
if [ $? -ne 0 ]; then
    echo "[ERRO] Falha ao instalar dependências!"
    exit 1
fi
echo "[OK] Dependências instaladas!"
echo ""

echo "========================================"
echo "  Verificando configuração..."
echo "========================================"
flutter doctor
echo ""

echo "========================================"
echo "  Opções de Execução"
echo "========================================"
echo "1. Executar em modo debug (desenvolvimento)"
echo "2. Compilar versão release (produção)"
echo "3. Sair"
echo ""
read -p "Escolha uma opção (1-3): " opcao

case $opcao in
    1)
        echo ""
        echo "Iniciando em modo debug..."
        flutter run -d linux
        ;;
    2)
        echo ""
        echo "Compilando versão release..."
        echo "Isso pode levar alguns minutos..."
        flutter build linux --release
        echo ""
        echo "[OK] Compilação concluída!"
        echo ""
        echo "O executável está em: build/linux/x64/release/bundle/"
        echo ""
        read -p "Pressione ENTER para continuar..."
        ;;
    3)
        echo "Saindo..."
        exit 0
        ;;
    *)
        echo "Opção inválida!"
        exit 1
        ;;
esac
