# Guia de Debug - Congelamento do Botão Preferences

## Objetivo
Identificar exatamente onde o app congela quando você clica no botão Preferences (engrenagem).

## Passos para Debug

### 1. Abra um Terminal
```bash
cd c:\flutter\Contaslite
```

### 2. Execute o App com Logs Verbosos
```bash
flutter run -v 2>&1 | Tee-Object debug_logs.txt
```

**Ou se estiver no Windows PowerShell:**
```powershell
flutter run -v | Tee-Object -FilePath debug_logs.txt
```

**Ou no Command Prompt (cmd):**
```cmd
flutter run -v > debug_logs.txt 2>&1
```

### 3. Aguarde o App Carregar
Você verá muitos logs. Procure por:
```
🚀 main() - iniciando app...
🚀 main() - WidgetsFlutterBinding inicializado
🔧 PrefsService: init() - iniciando...
🏠 HomeScreen.initState() - iniciando...
🔧 SettingsScreen.initState() - iniciando...
```

### 4. Clique no Botão Preferences (Engrenagem)
Quando o app estiver na tela inicial, clique no botão de engrenagem na barra inferior.

### 5. IMEDIATAMENTE Volte para o Terminal e Pressione `Ctrl+C`
Assim que o app congelar/travar, cancele a execução.

### 6. Analise os Logs
Procure pelos últimos logs que foram impressos. Os logs que você precisa procurar são:

#### Logs de Sucesso Esperados (se não congelar):
```
🏠 HomeScreen.initState() - iniciando...
🏠 HomeScreen.initState() - criando lista de telas...
🏠 HomeScreen.initState() - lista de telas criada
🏠 HomeScreen.initState() - criando listener...
🏠 HomeScreen.initState() - concluído

🔧 SettingsScreen.initState() - iniciando...
🔧 SettingsScreen.initState() - acessando cityNotifier
🔧 SettingsScreen.initState() - cityNotifier OK: São José dos Campos
🔧 SettingsScreen.initState() - acessando themeNotifier
🔧 SettingsScreen.initState() - themeNotifier OK: false
🔧 SettingsScreen.initState() - concluído com sucesso
```

#### Logs Esperados do PrefsService:
```
🔧 PrefsService: init() - iniciando...
🔧 PrefsService: init() - carregando tema...
🔧 PrefsService: init() - tema carregado: light
🔧 PrefsService: init() - carregando localização...
🔧 PrefsService: init() - localização carregada: São José dos Campos, Vale do Paraíba
🔧 PrefsService: init() - carregando intervalo de datas...
🔧 PrefsService: init() - intervalo de datas carregado
🔧 PrefsService: init() - carregando configurações de proteção de banco...
🔧 PrefsService: init() - concluído com sucesso
```

### 7. Identifique o Ponto do Travamento
Se o app congelar, você verá que os logs param em um ponto específico. Por exemplo:

- Se para em `🔧 SettingsScreen.initState() - acessando cityNotifier`, o problema está ali
- Se para em `🏠 HomeScreen.initState() - lista de telas criada`, o problema está na criação da lista de telas
- Se para em algum log do PrefsService, o problema está ali

## O Que Fazer Depois

**Copie e cole os últimos 50 linhas dos logs aqui** para que eu possa analisar exatamente onde está o travamento.

### Como Copiar os Logs

Se você usou `Tee-Object`:
```bash
Get-Content debug_logs.txt -Tail 100
```

Se você redirecionou para arquivo:
```bash
tail -100 debug_logs.txt
```

Ou simplesmente abra o arquivo `debug_logs.txt` em um editor de texto e copie os últimos logs.

## Dica: Salvar os Logs Completos

Para ter um registro completo, você pode também usar:

```bash
flutter run -v > full_debug.log 2>&1 &
```

E depois quando o app congelar:
```bash
Get-Content full_debug.log -Tail 200 | Out-File final_logs.txt
```

---

## Se o App Não Congelar Mais

Se o app não congelar mais e você conseguir navegar normalmente:
1. Navegue para a tela Preferences clicando no botão (engrenagem)
2. Se carregou OK, procure por logs que digam `🔧 SettingsScreen.initState() - concluído com sucesso`
3. Se vir isso, ótimo! O problema foi resolvido.

---

**Data de Criação:** 2026-01-04
**Versão do App:** 1.50.0
**Última Modificação:** Análise de debug para Preferences freeze
