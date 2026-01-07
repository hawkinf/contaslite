# 📸 Snapshot Shortcuts no VS Code

## Como Usar

### Método 1: Atalho de Teclado (Mais Rápido)
Pressione **`Ctrl+Shift+S`** para criar um snapshot instantaneamente!

### Método 2: Comando da Paleta
1. Pressione **`Ctrl+Shift+P`** para abrir a Paleta de Comandos
2. Digite **`Tasks: Run Task`** ou apenas **`run task`**
3. Selecione **`📸 Create Quick Snapshot`**

### Método 3: Menu Terminal
1. Vá para: **Terminal → Run Task**
2. Selecione **`📸 Create Quick Snapshot`**

## Outras Tarefas Disponíveis

### 📋 Listar Todos os Snapshots
- Atalho: **`Ctrl+Shift+P`** → `Run Task` → `📋 List All Snapshots`
- Mostra todos os snapshots criados com seus tamanhos

### 🗑️ Limpar Snapshots Antigos
- Atalho: **`Ctrl+Shift+P`** → `Run Task` → `🗑️ Cleanup Old Snapshots`
- Remove snapshots antigos para economizar espaço

## Configuração

A configuração está em `.vscode/tasks.json` e `.vscode/keybindings.json`

**Atalho Principal:** `Ctrl+Shift+S` → Cria snapshot

Se você quiser mudar o atalho, edite `.vscode/keybindings.json` e altere a key.

## Exemplo de Uso Rápido

```
Ctrl+Shift+S  →  [Abre o terminal]  →  [Snapshot criado]  →  [Mostra resumo]
```

Tudo acontece em segundos! ⚡
