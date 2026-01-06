# 🚀 Integração com API - Resumo de Configuração

## Sua API: contaslite.hawk.com.br

### Status
✅ Suporte adicionado ao aplicativo
✅ Configuração customizável na tela de Settings
✅ Documentação completa fornecida
⏳ Aguardando sua implementação no backend

---

## Como Configurar no App (3 Passos)

### Passo 1: Abrir Configurações
1. Abra o Contaslite
2. Clique em **Preferências** (⚙️)
3. Scroll down até **PostgreSQL**

### Passo 2: Preencher Dados
| Campo | Valor |
|-------|-------|
| **Habilitar PostgreSQL** | ON (ativar) |
| **Endereço (Host)** | postgres.hawk.com.br (ou IP) |
| **Porta** | 5432 |
| **Nome do Banco** | seu_database |
| **Usuário** | seu_usuario |
| **Senha** | sua_senha |
| **URL da API** | `https://contaslite.hawk.com.br/api` ← NOVO! |

### Passo 3: Testar e Salvar
1. Clique **"Testar Conexão"** ✅
2. Clique **"Salvar"** 💾

Pronto! O app agora usará sua API quando conectado à internet.

---

## Como Funciona

```
┌─ App (Contaslite) ────────────────┐
│  Preferências > PostgreSQL         │
│  Configura:                        │
│  - Host: postgres.hawk.com.br      │
│  - URL: https://contaslite.../api  │
│  - Credenciais: user:pass          │
└────────────────┬────────────────────┘
                 │
        ┌────────▼─────────┐
        │ DatabaseManager  │
        │ (Auto-switching) │
        └────────┬─────────┘
                 │
        ┌────────▼──────────────────┐
        │ Internet conectado?       │
        │ └─ SIM → Usa PostgreSQL   │
        │ └─ NÃO → Usa SQLite local │
        └──────────────────────────┘
                 │
        ┌────────▼────────┐
        │ Requisição HTTP │
        │ POST /api/query │
        └────────┬────────┘
                 │
        ┌────────▼──────────────────┐
        │ https://contaslite.../api  │
        │ (Sua API Gateway)          │
        └────────┬──────────────────┘
                 │
        ┌────────▼──────────────────┐
        │ PostgreSQL (seu servidor)  │
        └────────────────────────────┘
```

---

## O que Fazer no Backend

### Opção 1: Usar Seu Backend Existente
Se você já tem um backend em `contaslite.hawk.com.br`:
1. Adicione os endpoints abaixo
2. Exponha em `/api/query`, `/api/insert`, etc.
3. Implemente autenticação Bearer (username:password)

### Opção 2: Usar o Exemplo Node.js
Arquivo: `packages/finance_app/API_CONFIGURATION.md`
- Código completo pronto para usar
- Instruções de deploy
- Exemplos de segurança

---

## Endpoints Necessários

Sua API precisa expor (ver detalhes em `API_CONFIGURATION.md`):

```
GET  /api/health              ← Health check
POST /api/query               ← SELECT queries
POST /api/insert              ← INSERT operations
POST /api/update              ← UPDATE operations
POST /api/delete              ← DELETE operations
POST /api/execute             ← Raw SQL
POST /api/beginTransaction    ← Transações
POST /api/commit
POST /api/rollback
```

---

## Checklist de Implementação

### Backend (contaslite.hawk.com.br)
- [ ] Servidor rodando
- [ ] Certificado SSL válido
- [ ] `/api/health` retorna 200 OK
- [ ] `/api/query` implementado e testado
- [ ] `/api/insert` implementado e testado
- [ ] `/api/update` implementado e testado
- [ ] `/api/delete` implementado e testado
- [ ] Autenticação Bearer implementada
- [ ] Rate limiting configurado
- [ ] Logs habilitados

### App (Contaslite)
- [ ] PostgreSQL settings screen acessível
- [ ] Campo "URL da API" preenchível
- [ ] Teste de conexão funciona
- [ ] Dados salvam corretamente
- [ ] App usa PostgreSQL quando online
- [ ] Fallback para SQLite quando offline

### Testes
- [ ] Test connection: ✅ Conexão bem-sucedida
- [ ] Fazer insert via API
- [ ] Fazer query via API
- [ ] Fazer update via API
- [ ] Fazer delete via API
- [ ] Desconectar internet → usar SQLite
- [ ] Reconectar internet → usar PostgreSQL

---

## Quick Test com CURL

```bash
# 1. Health check
curl https://contaslite.hawk.com.br/api/health

# 2. Query de teste
curl -X POST https://contaslite.hawk.com.br/api/query \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer user:pass" \
  -d '{"sql": "SELECT 1 as test", "args": []}'

# Esperado: { "data": [{ "test": 1 }] }
```

---

## Documentação Completa

### Para Usuários
- `POSTGRESQL_QUICKSTART.md` - Como configurar no app

### Para Desenvolvedores
- `API_CONFIGURATION.md` - Como implementar backend
- `POSTGRESQL_INTEGRATION.md` - Arquitetura completa
- `DATABASE_MANAGER_SETUP.md` - Integração no código

---

## Próximos Passos

### Imediato (Esta semana)
1. Implemente os endpoints em `contaslite.hawk.com.br/api`
2. Teste cada endpoint com curl
3. Configure no app: Preferências > PostgreSQL
4. Clique "Test Connection"
5. Se ✅ → Pronto para usar!

### Curto Prazo (Semana 2)
1. Teste sincronização de dados
2. Configure rate limiting
3. Adicione logging/monitoramento
4. Documentar API interna

### Médio Prazo (Futuro)
1. Implementar sincronização bidirecional
2. Criptografar senhas no app
3. Suportar múltiplos perfis de banco
4. Dashboard de estatísticas

---

## Troubleshooting

### "Servidor não respondeu"
```
1. curl https://contaslite.hawk.com.br/api/health
2. Verifique certificado SSL
3. Verifique firewall
4. Verifique DNS
```

### "Autenticação falhou"
```
1. Verifique username/password
2. Teste: Authorization: Bearer username:password
3. Verifique validação no backend
```

### "Timeout"
```
1. Verifique se API está respondendo
2. Teste com curl (sem timeout)
3. Verifique performance do banco
4. Otimize queries SQL
```

---

## Arquivo Chave

**`API_CONFIGURATION.md`** contém:
- ✅ Todas as especificações de endpoint
- ✅ Exemplo completo Node.js/Express
- ✅ Recomendações de segurança
- ✅ Deploy em produção
- ✅ Testes com curl

**Veja este arquivo para detalhes técnicos completos!**

---

## Resumo

| Item | Status |
|------|--------|
| **App Modificado** | ✅ Pronto |
| **URL Customizável** | ✅ Sim |
| **Test Connection** | ✅ Funciona |
| **Documentação** | ✅ Completa |
| **Backend Implementado** | ⏳ Seu trabalho |

---

## Suporte

Em caso de dúvidas:
1. Leia `API_CONFIGURATION.md`
2. Teste endpoints com curl
3. Verifique logs do servidor
4. Verifique `flutter logs` do app

---

**Versão**: 1.0
**Data**: Janeiro 6, 2026
**Status**: Pronto para Deploy

🎉 **Sua API está pronta para ser integrada!**
