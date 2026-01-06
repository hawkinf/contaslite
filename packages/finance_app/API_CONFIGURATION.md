# API Configuration para contaslite.hawk.com.br

## Overview

O aplicativo Contaslite agora suporta configuração customizada da URL da API PostgreSQL, permitindo que você use qualquer endpoint de backend que expor uma API REST compatível.

## Sua Configuração

### URL da API
```
https://contaslite.hawk.com.br/api
```

### Configuração no Aplicativo

1. **Abra o Aplicativo**
2. **Preferências** → **PostgreSQL**
3. Preencha os campos:
   - **Endereço (Host)**: Deixe em branco ou use um placeholder
   - **Porta**: Qualquer valor (será ignorado se URL customizada for usada)
   - **Nome do Banco**: Seu banco PostgreSQL
   - **Usuário**: Username do PostgreSQL
   - **Senha**: Senha do PostgreSQL
   - **URL da API** (Novo!): `https://contaslite.hawk.com.br/api`

4. Clique **"Testar Conexão"** para validar
5. Clique **"Salvar"**

## Endpoints Esperados

Sua API em `contaslite.hawk.com.br` deve expor os seguintes endpoints:

### 1. Health Check
```
GET /api/health
Response: 200 OK
```

Exemplo:
```bash
curl -X GET https://contaslite.hawk.com.br/api/health
```

### 2. Query (SELECT)
```
POST /api/query
Headers:
  Content-Type: application/json
  Authorization: Bearer {username}:{password}

Body:
{
  "sql": "SELECT * FROM accounts WHERE id = ?",
  "args": [1]
}

Response:
{
  "data": [
    { "id": 1, "name": "Account 1", "value": 100.00 },
    ...
  ]
}
```

### 3. Insert
```
POST /api/insert
Body:
{
  "table": "accounts",
  "values": {
    "name": "New Account",
    "value": 250.50
  }
}

Response:
{
  "id": 5  // Auto-generated ID
}
```

### 4. Update
```
POST /api/update
Body:
{
  "table": "accounts",
  "values": { "name": "Updated Name" },
  "where": "id = ?",
  "whereArgs": [5]
}

Response:
{
  "rowsAffected": 1
}
```

### 5. Delete
```
POST /api/delete
Body:
{
  "table": "accounts",
  "where": "id = ?",
  "whereArgs": [5]
}

Response:
{
  "rowsAffected": 1
}
```

### 6. Execute (Raw SQL)
```
POST /api/execute
Body:
{
  "sql": "UPDATE accounts SET value = value * 1.1",
  "args": []
}

Response:
{
  "rowsAffected": 15
}
```

### 7. Transactions
```
POST /api/beginTransaction
Response: { "status": "ok" }

POST /api/commit
Response: { "status": "ok" }

POST /api/rollback
Response: { "status": "ok" }
```

## Exemplo de Implementação Backend

### Node.js + Express + PostgreSQL

```javascript
const express = require('express');
const { Pool } = require('pg');
const app = express();

app.use(express.json());

// Pool de conexão PostgreSQL
const pool = new Pool({
  host: 'seu_host',
  port: 5432,
  database: 'seu_database',
  user: 'seu_usuario',
  password: 'sua_senha',
});

// Middleware de autenticação
app.use((req, res, next) => {
  // Validar token ou credenciais
  const auth = req.headers.authorization;
  if (!auth) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  // Extrair username:password do token
  const [username, password] = auth.replace('Bearer ', '').split(':');

  // TODO: Validar credenciais contra seu banco
  // Por exemplo: verificar na tabela de usuários

  next();
});

// Health Check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date() });
});

// Query (SELECT)
app.post('/api/query', async (req, res) => {
  try {
    const { sql, args } = req.body;
    const result = await pool.query(sql, args);
    res.json({ data: result.rows });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Single Query
app.post('/api/querySingle', async (req, res) => {
  try {
    const { sql, args } = req.body;
    const result = await pool.query(sql, args);
    res.json({ data: result.rows[0] || null });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Insert
app.post('/api/insert', async (req, res) => {
  try {
    const { table, values } = req.body;
    const columns = Object.keys(values);
    const columnList = columns.join(', ');
    const placeholders = columns.map((_, i) => `$${i + 1}`).join(', ');
    const sql = `INSERT INTO ${table} (${columnList}) VALUES (${placeholders}) RETURNING id`;

    const result = await pool.query(sql, Object.values(values));
    res.json({ id: result.rows[0].id });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Update
app.post('/api/update', async (req, res) => {
  try {
    const { table, values, where, whereArgs } = req.body;
    const setClause = Object.keys(values)
      .map((col, i) => `${col} = $${i + 1}`)
      .join(', ');

    const args = [...Object.values(values), ...whereArgs];
    const sql = `UPDATE ${table} SET ${setClause} WHERE ${where}`;

    const result = await pool.query(sql, args);
    res.json({ rowsAffected: result.rowCount });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Delete
app.post('/api/delete', async (req, res) => {
  try {
    const { table, where, whereArgs } = req.body;
    const sql = `DELETE FROM ${table} WHERE ${where}`;

    const result = await pool.query(sql, whereArgs);
    res.json({ rowsAffected: result.rowCount });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Execute
app.post('/api/execute', async (req, res) => {
  try {
    const { sql, args } = req.body;
    const result = await pool.query(sql, args);
    res.json({ rowsAffected: result.rowCount });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Transactions
let client = null;

app.post('/api/beginTransaction', async (req, res) => {
  try {
    client = await pool.connect();
    await client.query('BEGIN');
    res.json({ status: 'ok' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/commit', async (req, res) => {
  try {
    await client.query('COMMIT');
    client.release();
    res.json({ status: 'ok' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/rollback', async (req, res) => {
  try {
    await client.query('ROLLBACK');
    client.release();
    res.json({ status: 'ok' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`API Gateway running on port ${PORT}`);
  console.log(`Endpoints available at https://localhost:${PORT}/api/*`);
});
```

### Para Deploy em Produção

```bash
# Install dependencies
npm install express pg

# Set environment variables
export DB_HOST=seu_host
export DB_PORT=5432
export DB_NAME=seu_database
export DB_USER=seu_usuario
export DB_PASSWORD=sua_senha
export PORT=443  # Para HTTPS

# Use reverse proxy (nginx/Apache) para:
# 1. Servir HTTPS
# 2. Adicionar headers de segurança
# 3. Rate limiting
# 4. Logging e monitoramento

# Configure SSL/TLS com certificados válidos
# Use Let's Encrypt para certificados gratuitos
```

## Testando a Configuração

### Test 1: Health Check
```bash
curl https://contaslite.hawk.com.br/api/health
# Esperado: { "status": "ok", "timestamp": "..." }
```

### Test 2: Query com Credenciais
```bash
curl -X POST https://contaslite.hawk.com.br/api/query \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer username:password" \
  -d '{"sql": "SELECT 1", "args": []}'
# Esperado: { "data": [...] }
```

### Test 3: Usar curl para Testar Endpoints
```bash
# Insert
curl -X POST https://contaslite.hawk.com.br/api/insert \
  -H "Authorization: Bearer user:pass" \
  -d '{"table": "accounts", "values": {"name": "Test"}}'

# Query
curl -X POST https://contaslite.hawk.com.br/api/query \
  -H "Authorization: Bearer user:pass" \
  -d '{"sql": "SELECT * FROM accounts", "args": []}'

# Update
curl -X POST https://contaslite.hawk.com.br/api/update \
  -H "Authorization: Bearer user:pass" \
  -d '{"table": "accounts", "values": {"name": "Updated"}, "where": "id = ?", "whereArgs": [1]}'
```

## Segurança

### Recomendações para Production

1. **Use HTTPS/TLS**
   - Certificados SSL válidos
   - Redirecionamento HTTP → HTTPS

2. **Autenticação Forte**
   - Implementar autenticação além de username:password
   - Considerar JWT tokens
   - Rate limiting por IP/usuário

3. **Validação de Input**
   - Validar SQL queries
   - Prevenir SQL injection (usar parameterized queries)
   - Validar tipos de dados

4. **CORS (se necessário)**
   ```javascript
   const cors = require('cors');
   app.use(cors({
     origin: 'https://seu_app.com',
     methods: ['POST', 'GET'],
     credentials: true
   }));
   ```

5. **Rate Limiting**
   ```javascript
   const rateLimit = require('express-rate-limit');
   const limiter = rateLimit({
     windowMs: 15 * 60 * 1000, // 15 minutos
     max: 100 // máx 100 requisições por IP
   });
   app.use('/api/', limiter);
   ```

6. **Logging e Monitoramento**
   - Log todas as requisições
   - Monitor de performance
   - Alertas de erro

## Troubleshooting

### "Servidor não respondeu"
1. Verifique se `https://contaslite.hawk.com.br/api/health` está acessível
2. Verifique certificado SSL (não deve ter erros)
3. Verifique firewall/proxy rules

### "Autenticação falhou"
1. Verifique username e password
2. Verifique se header `Authorization` está sendo enviado corretamente
3. Verifique validação no backend

### Timeout nas operações
1. Verifique performance da API
2. Aumente timeout em `postgresql_impl.dart` (linha 267)
3. Otimize queries SQL

## Próximos Passos

1. **Deploy da API Gateway** em `contaslite.hawk.com.br`
2. **Testar Health Check** primeiro
3. **Testar cada endpoint** individualmente
4. **Configurar no App**: Preferências > PostgreSQL
5. **Teste de Conexão** no app
6. **Início da sincronização de dados**

## Suporte

Para problemas:
1. Verifique logs do servidor
2. Verifique logs do app (flutter logs)
3. Teste endpoints manualmente com curl
4. Verifique conectividade de rede

---

**Data**: Janeiro 6, 2026
**Status**: Pronto para Implementação
**Versão da API**: 1.0
