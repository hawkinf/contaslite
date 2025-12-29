# 🪟 GUIA DE INSTALAÇÃO - WINDOWS

## 📍 Seu Projeto
**Localização:** `C:\flutter\contas_pagar`

---

## ⚡ INSTALAÇÃO RÁPIDA

### Opção 1: Script Automático (Recomendado)

1. **Extraia o ZIP** para `C:\flutter\contas_pagar`
2. **Navegue até a pasta:**
   ```cmd
   cd C:\flutter\contas_pagar
   ```
3. **Execute o instalador:**
   ```cmd
   INSTALAR.bat
   ```
4. **Escolha a opção:**
   - `1` - Executar em modo debug (desenvolvimento)
   - `2` - Compilar versão release (executável final)

---

### Opção 2: Manual

1. **Abra o Prompt de Comando** (Win + R → `cmd`)

2. **Navegue até a pasta:**
   ```cmd
   cd C:\flutter\contas_pagar
   ```

3. **Instale as dependências:**
   ```cmd
   flutter pub get
   ```

4. **Execute o aplicativo:**
   ```cmd
   flutter run -d windows
   ```

---

## 🏗️ COMPILAR VERSÃO FINAL (EXE)

Para criar o executável Windows:

```cmd
cd C:\flutter\contas_pagar
flutter build windows --release
```

**O executável estará em:**
```
C:\flutter\contas_pagar\build\windows\x64\runner\Release\contas_pagar.exe
```

Você pode copiar toda a pasta `Release` para qualquer lugar e distribuir!

---

## 🔧 TROUBLESHOOTING

### Problema: "flutter não é reconhecido"

**Solução:** Adicione o Flutter ao PATH do Windows

1. Abra as Variáveis de Ambiente:
   - Win + R → `sysdm.cpl` → Avançado → Variáveis de Ambiente
2. Em "Variáveis do Sistema", encontre `Path`
3. Adicione: `C:\flutter\bin` (ou onde você instalou o Flutter)
4. Clique OK e reabra o CMD

### Problema: "Visual Studio não encontrado"

O Flutter precisa do Visual Studio Build Tools para Windows.

**Solução:**
```cmd
flutter doctor
```

Siga as instruções para instalar o que falta.

**Ou baixe:**
- Visual Studio 2022 Community (gratuito)
- Durante instalação, marque: "Desenvolvimento de Desktop com C++"

### Problema: Erro de compilação

**Solução:**
```cmd
cd C:\flutter\contas_pagar
flutter clean
flutter pub get
flutter run -d windows
```

### Problema: Banco de dados não abre

**Localização do banco:**
```
C:\Users\[SeuUsuario]\AppData\Roaming\finance_app\finance_v62.db
```

**Para resetar:**
1. Feche o aplicativo
2. Delete o arquivo `finance_v62.db`
3. Reabra o aplicativo

---

## 📁 ESTRUTURA DO PROJETO

```
C:\flutter\contas_pagar\
│
├── lib\                      # Código-fonte
│   ├── main.dart            # Entrada da aplicação
│   ├── database\            # Banco de dados
│   ├── models\              # Modelos de dados
│   ├── screens\             # Telas
│   ├── services\            # Serviços
│   ├── utils\               # Utilitários
│   └── widgets\             # Componentes
│
├── windows\                  # Configurações Windows
├── build\                    # Arquivos compilados
├── pubspec.yaml             # Dependências
├── README.md                # Documentação
└── INSTALAR.bat             # Instalador automático
```

---

## 🚀 COMANDOS ÚTEIS

### Verificar instalação do Flutter
```cmd
flutter doctor -v
```

### Atualizar dependências
```cmd
flutter pub upgrade
```

### Ver dispositivos disponíveis
```cmd
flutter devices
```

### Executar em modo release (mais rápido)
```cmd
flutter run -d windows --release
```

### Limpar cache e rebuild
```cmd
flutter clean
flutter pub get
flutter run -d windows
```

---

## 📊 VERIFICAÇÃO PÓS-INSTALAÇÃO

Execute estes comandos para verificar se tudo está OK:

```cmd
cd C:\flutter\contas_pagar

REM 1. Verificar Flutter
flutter --version

REM 2. Verificar saúde do projeto
flutter doctor

REM 3. Analisar código
flutter analyze

REM 4. Obter dependências
flutter pub get

REM 5. Executar aplicativo
flutter run -d windows
```

Se todos os comandos funcionarem, está tudo OK! ✅

---

## 💡 DICAS PARA WINDOWS

### Desempenho
- Execute em modo `--release` para melhor performance
- Feche outros programas pesados durante compilação
- Use SSD para melhor velocidade de build

### Antivírus
Se o antivírus bloquear:
1. Adicione `C:\flutter` às exclusões
2. Adicione `C:\flutter\contas_pagar\build` às exclusões

### Visual Studio Code
Recomendado para edição:
1. Instale VS Code
2. Instale extensões: Flutter, Dart
3. Abra a pasta `C:\flutter\contas_pagar`

---

## 🎯 PRIMEIRA EXECUÇÃO

Após executar `flutter run -d windows`, você verá:

```
Launching lib\main.dart on Windows in debug mode...
Building Windows application...
✓ Built build\windows\x64\runner\Debug\contas_pagar.exe
Syncing files to device Windows...
```

O aplicativo abrirá automaticamente! 🎉

---

## 📱 EXECUTAR EM OUTRAS PLATAFORMAS

### Android
```cmd
flutter run -d android
```
(Requer dispositivo conectado ou emulador)

### Web
```cmd
flutter run -d chrome
```

### Linux (via WSL)
```cmd
wsl
cd /mnt/c/flutter/contas_pagar
flutter run -d linux
```

---

## 🆘 SUPORTE

### Documentação Incluída
- 📄 README.md - Guia completo
- 📄 INICIO_RAPIDO.md - Primeiros passos
- 📄 TESTES.md - Como testar
- 📄 OTIMIZACOES.md - Detalhes técnicos

### Comandos de Diagnóstico
```cmd
REM Ver erros detalhados
flutter run -d windows -v

REM Verificar problemas
flutter doctor -v

REM Limpar tudo e começar do zero
flutter clean && flutter pub get
```

---

## ✅ CHECKLIST FINAL

Antes de começar a usar:

- [ ] Flutter instalado e no PATH
- [ ] Visual Studio Build Tools instalado
- [ ] Projeto extraído em `C:\flutter\contas_pagar`
- [ ] `flutter pub get` executado com sucesso
- [ ] `flutter run -d windows` funcionando
- [ ] Aplicativo abre sem erros

Se todos os itens estão marcados: **Parabéns! Está tudo pronto!** 🎉

---

**Windows Version:** 10/11  
**Flutter Version:** 3.0+  
**Última Atualização:** Dezembro 2024

**Bom uso! 💰✅**
