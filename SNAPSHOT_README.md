# 📸 Script de Snapshot Automático

## Como Usar

### Opção 1: Clique Duplo (Mais Fácil)
1. Vá até `c:\flutter\Contaslite\`
2. Clique duplo em **`snapshot.cmd`**
3. Pronto! Snapshot será criado automaticamente

### Opção 2: PowerShell
1. Abra PowerShell na pasta `c:\flutter\Contaslite\`
2. Execute: `.\snapshot.ps1`
3. Aguarde o snapshot ser criado

### Opção 3: Linha de Comando (CMD)
1. Abra CMD na pasta `c:\flutter\Contaslite\`
2. Execute: `snapshot.cmd`
3. Aguarde o snapshot ser criado

## O que o Script Faz

✅ Cria pasta com timestamp automático em `.snapshots/`
✅ Copia todo o projeto (excluindo arquivos temporários)
✅ Mostra tamanho do snapshot em MB
✅ Lista os últimos 5 snapshots criados
✅ Não pergunta nada durante a execução
✅ Fecha automaticamente ao terminar

## Formato dos Nomes

Os snapshots são salvos com nome no formato:
```
snapshot-YYYY-MM-DDTHH-MM-SS
Exemplo: snapshot-2026-01-07T10-49-50
```

## Localização dos Snapshots

Todos os snapshots são salvos em:
```
c:\flutter\Contaslite\.snapshots\
```

## Arquivos Excluídos

Para economizar espaço, os seguintes arquivos/pastas NÃO são copiados:
- `.git/` - Histórico do git
- `build/` - Artefatos de build
- `.dart_tool/` - Cache do Dart
- `.idea/` - Configurações do IDE
- `ios/Pods/` - Dependências iOS
- `.flutter-plugins*` - Arquivos de plugins
- `.packages` - Cache de pacotes
- `pubspec.lock` - Lock file (será recriado)
- `.vscode` - Configurações VSCode

## Dica de Uso

Use `snapshot.cmd` para criar snapshots rápidos quando quiser salvar o estado do projeto antes de fazer mudanças grandes.

O arquivo é totalmente automatizado - basta clicar duplo! 🚀
