# 📸 Project Snapshots - Guia de Uso

## O que é?

O **Project Snapshots** é um sistema automático que faz backups (snapshots) do seu projeto a cada 30 minutos. Mantém apenas os últimos 10 snapshots para economizar espaço.

## Como Usar?

### 1. Iniciar o Serviço de Snapshots

Abra o VSCode e:

1. Vá para **Run and Debug** (Ctrl+Shift+D)
2. Na dropdown no topo, selecione **"📸 Project Snapshots (30 min intervals)"**
3. Clique no botão de play ou pressione F5

O serviço começará a criar snapshots a cada 30 minutos.

### 2. Listar Snapshots Existentes

Abra o terminal integrado e execute:

```bash
node .vscode/snapshot.js list
```

Isso mostrará todos os snapshots salvos com:
- Data e hora
- Tamanho
- Número de arquivos

### 3. Limpar Snapshots Antigos

Execute:

```bash
node .vscode/snapshot.js cleanup
```

Isso remove snapshots antigos, mantendo apenas os 10 mais recentes.

## 📁 Onde são Guardados?

Os snapshots são salvos em:

```
.snapshots/
├── snapshot-2026-01-06-19-30-45/
│   ├── lib/
│   ├── packages/
│   ├── pubspec.yaml
│   ├── .snapshot.json (metadados)
│   └── ... (outros arquivos)
├── snapshot-2026-01-06-19-00-15/
├── ...
```

## 🎯 O que é Incluído nos Snapshots?

✅ Arquivos importantes:
- `lib/`
- `packages/`
- `pubspec.yaml`
- Arquivos de configuração

❌ Arquivos excluídos (economizando espaço):
- `node_modules/`
- `build/`
- `.dart_tool/`
- `dist/`
- `.git/`
- `.idea/`
- `.vscode/` (exceto o snapshot.js)
- `.snapshots/` (evita recursão)

## 💡 Dicas Úteis

### Snapshot Automático no Startup

Para que o serviço inicie automaticamente com o VSCode, adicione uma tarefa:

1. Vá para **Terminal** → **Configure Default Build Task**
2. Selecione **Create tasks.json from template** → **Others**
3. Adicione:

```json
{
  "label": "Start Snapshots",
  "type": "shell",
  "command": "node",
  "args": [".vscode/snapshot.js"],
  "isBackground": true,
  "problemMatcher": {
    "pattern": {
      "regexp": "^.*$",
      "file": 1,
      "location": 2,
      "message": 3
    },
    "background": {
      "activeOnStart": true,
      "beginsPattern": "^.*Project Snapshot Service Iniciado.*$",
      "endsPattern": "^.*Próximo snapshot em.*$"
    }
  },
  "runOptions": {
    "runOn": "folderOpen"
  }
}
```

### Recuperar de um Snapshot

1. Vá para `.snapshots/`
2. Encontre o snapshot que quer restaurar
3. Copie os arquivos de volta para a raiz do projeto
4. Faça commit das alterações no Git (se necessário)

## ⚙️ Configurações

Abra `.vscode/snapshot.js` para ajustar:

- `SNAPSHOT_INTERVAL`: Intervalo entre snapshots (padrão: 30 minutos)
- `MAX_SNAPSHOTS`: Número máximo de snapshots mantidos (padrão: 10)
- `SNAPSHOTS_DIR`: Diretório onde guardar (padrão: `.snapshots/`)

## 🚀 Exemplo de Uso Completo

```bash
# Iniciar o serviço (em um terminal)
node .vscode/snapshot.js

# Em outro terminal, listar snapshots
node .vscode/snapshot.js list

# Quando quiser, limpar snapshots antigos
node .vscode/snapshot.js cleanup
```

## 📊 Informações de um Snapshot

Cada snapshot contém um arquivo `.snapshot.json` com metadados:

```json
{
  "timestamp": "2026-01-06T19:30:45.123Z",
  "name": "snapshot-2026-01-06-19-30-45",
  "size": 5242880,
  "files": 1234
}
```

## ⚠️ Notas Importantes

- O serviço roda em background enquanto o terminal estiver aberto
- Feche o terminal ou pressione Ctrl+C para parar o serviço
- Snapshots podem usar bastante espaço em disco - monitore periodicamente
- Use `cleanup` para remover snapshots antigos manualmente se necessário
