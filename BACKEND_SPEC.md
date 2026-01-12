# Backend API Specification - Contaslite Multi-User

## 📋 Visão Geral

Este documento especifica a arquitetura completa do backend PostgreSQL para suportar múltiplos usuários no Contaslite, com sincronização bidirecional offline-first.

**Princípios:**
- Autenticação JWT (access + refresh tokens)
- Sincronização incremental baseada em timestamps
- Resolução de conflitos: **server-wins**
- Suporte a operações offline no cliente
- Rate limiting e segurança

---

## 🗄️ Schema PostgreSQL

### Tabela: `users`
```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created_at ON users(created_at);
```

### Tabela: `refresh_tokens`
```sql
CREATE TABLE refresh_tokens (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    revoked BOOLEAN DEFAULT false,
    device_info TEXT
);

CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_token_hash ON refresh_tokens(token_hash);
CREATE INDEX idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);
```

### Tabela: `account_types`
```sql
CREATE TABLE account_types (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    icon VARCHAR(50),
    color VARCHAR(20),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(user_id, name)
);

CREATE INDEX idx_account_types_user_id ON account_types(user_id);
```

### Tabela: `categories`
```sql
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    icon VARCHAR(50),
    color VARCHAR(20),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(user_id, name)
);

CREATE INDEX idx_categories_user_id ON categories(user_id);
```

### Tabela: `subcategories`
```sql
CREATE TABLE subcategories (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(user_id, category_id, name)
);

CREATE INDEX idx_subcategories_user_id ON subcategories(user_id);
CREATE INDEX idx_subcategories_category_id ON subcategories(category_id);
```

### Tabela: `payment_methods`
```sql
CREATE TABLE payment_methods (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    icon VARCHAR(50),
    color VARCHAR(20),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(user_id, name)
);

CREATE INDEX idx_payment_methods_user_id ON payment_methods(user_id);
```

### Tabela: `accounts`
```sql
CREATE TABLE accounts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type_id INTEGER REFERENCES account_types(id) ON DELETE SET NULL,
    category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
    subcategory_id INTEGER REFERENCES subcategories(id) ON DELETE SET NULL,
    payment_method_id INTEGER REFERENCES payment_methods(id) ON DELETE SET NULL,
    
    description TEXT NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    due_date DATE NOT NULL,
    payment_date DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    notes TEXT,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    deleted_at TIMESTAMP,
    
    CHECK (status IN ('pending', 'paid', 'overdue', 'cancelled'))
);

CREATE INDEX idx_accounts_user_id ON accounts(user_id);
CREATE INDEX idx_accounts_type_id ON accounts(type_id);
CREATE INDEX idx_accounts_category_id ON accounts(category_id);
CREATE INDEX idx_accounts_due_date ON accounts(due_date);
CREATE INDEX idx_accounts_status ON accounts(status);
CREATE INDEX idx_accounts_updated_at ON accounts(updated_at);
CREATE INDEX idx_accounts_deleted_at ON accounts(deleted_at);
```

### Tabela: `sync_log` (auditoria)
```sql
CREATE TABLE sync_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action VARCHAR(20) NOT NULL,
    table_name VARCHAR(50) NOT NULL,
    record_id INTEGER NOT NULL,
    client_timestamp TIMESTAMP,
    server_timestamp TIMESTAMP DEFAULT NOW(),
    conflict_resolution VARCHAR(50),
    
    CHECK (action IN ('create', 'update', 'delete'))
);

CREATE INDEX idx_sync_log_user_id ON sync_log(user_id);
CREATE INDEX idx_sync_log_timestamp ON sync_log(server_timestamp);
```

---

## 🔐 Autenticação - Endpoints

### Base URL
```
https://api.contaslite.com/v1
```

### 1. POST `/api/auth/register`
**Descrição:** Cria nova conta de usuário.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "name": "João Silva"
}
```

**Validações:**
- Email válido e único
- Senha: mínimo 8 caracteres, 1 maiúscula, 1 número
- Nome: mínimo 2 caracteres

**Response 201:**
```json
{
  "user": {
    "id": 123,
    "email": "user@example.com",
    "name": "João Silva",
    "createdAt": "2026-01-12T10:30:00Z"
  },
  "accessToken": "eyJhbGciOiJIUzI1NiIs...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIs...",
  "expiresIn": 3600
}
```

**Errors:**
- `400`: Email já existe, senha fraca, dados inválidos
- `429`: Rate limit excedido

---

### 2. POST `/api/auth/login`
**Descrição:** Autentica usuário existente.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!"
}
```

**Response 200:**
```json
{
  "user": {
    "id": 123,
    "email": "user@example.com",
    "name": "João Silva"
  },
  "accessToken": "eyJhbGciOiJIUzI1NiIs...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIs...",
  "expiresIn": 3600
}
```

**Errors:**
- `401`: Email ou senha incorretos
- `403`: Conta desativada
- `429`: Rate limit (máximo 5 tentativas em 15 minutos)

---

### 3. POST `/api/auth/refresh`
**Descrição:** Renova access token usando refresh token.

**Request:**
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIs..."
}
```

**Response 200:**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIs...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIs...",
  "expiresIn": 3600
}
```

**Errors:**
- `401`: Refresh token inválido ou revogado
- `403`: Refresh token expirado

---

### 4. POST `/api/auth/logout`
**Descrição:** Revoga refresh token do usuário.

**Headers:**
```
Authorization: Bearer {accessToken}
```

**Request:**
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIs..."
}
```

**Response 200:**
```json
{
  "message": "Logout realizado com sucesso"
}
```

---

## 🔄 Sincronização - Endpoints

### 5. POST `/api/sync/push`
**Descrição:** Envia alterações locais para o servidor.

**Headers:**
```
Authorization: Bearer {accessToken}
Content-Type: application/json
```

**Request:**
```json
{
  "changes": {
    "accounts": [
      {
        "localId": 42,
        "serverId": null,
        "action": "create",
        "data": {
          "typeId": 1,
          "categoryId": 5,
          "description": "Conta de luz",
          "amount": 150.50,
          "dueDate": "2026-01-20",
          "status": "pending"
        },
        "updatedAt": "2026-01-12T08:00:00Z"
      },
      {
        "localId": 15,
        "serverId": 98,
        "action": "update",
        "data": {
          "status": "paid",
          "paymentDate": "2026-01-12"
        },
        "updatedAt": "2026-01-12T09:15:00Z"
      },
      {
        "localId": 20,
        "serverId": 75,
        "action": "delete",
        "updatedAt": "2026-01-12T10:00:00Z"
      }
    ],
    "categories": [...],
    "paymentMethods": [...]
  }
}
```

**Response 200:**
```json
{
  "processed": {
    "accounts": [
      {
        "localId": 42,
        "serverId": 150,
        "action": "created",
        "serverTimestamp": "2026-01-12T10:30:05Z"
      },
      {
        "localId": 15,
        "serverId": 98,
        "action": "updated",
        "serverTimestamp": "2026-01-12T10:30:06Z"
      },
      {
        "localId": 20,
        "serverId": 75,
        "action": "deleted",
        "serverTimestamp": "2026-01-12T10:30:07Z"
      }
    ]
  },
  "conflicts": [
    {
      "localId": 15,
      "serverId": 98,
      "table": "accounts",
      "reason": "Server version is newer",
      "serverVersion": {
        "id": 98,
        "status": "cancelled",
        "updatedAt": "2026-01-12T09:30:00Z"
      },
      "resolution": "server_wins"
    }
  ],
  "serverTimestamp": "2026-01-12T10:30:10Z"
}
```

**Regras de Conflito:**
1. Se `server.updated_at > client.updated_at` → **Server wins**
2. Cliente recebe versão do servidor em `conflicts[]`
3. Cliente substitui local com versão do servidor
4. Log de conflito gravado em `sync_log`

**Errors:**
- `401`: Token inválido ou expirado
- `422`: Dados inválidos (validação falhou)
- `409`: Conflito não resolvível (registro já deletado)

---

### 6. GET `/api/sync/pull?since={timestamp}`
**Descrição:** Baixa alterações do servidor desde último sync.

**Headers:**
```
Authorization: Bearer {accessToken}
```

**Query Parameters:**
- `since` (opcional): ISO 8601 timestamp (ex: `2026-01-12T08:00:00Z`)
- Se omitido, retorna todos os registros do usuário

**Response 200:**
```json
{
  "data": {
    "accountTypes": [
      {
        "id": 1,
        "name": "Pagamentos",
        "icon": "💳",
        "color": "#E53935",
        "updatedAt": "2026-01-10T12:00:00Z",
        "deletedAt": null
      }
    ],
    "categories": [...],
    "subcategories": [...],
    "paymentMethods": [...],
    "accounts": [
      {
        "id": 98,
        "typeId": 1,
        "categoryId": 5,
        "description": "Internet",
        "amount": 99.90,
        "dueDate": "2026-01-15",
        "status": "pending",
        "updatedAt": "2026-01-12T09:30:00Z",
        "deletedAt": null
      }
    ]
  },
  "serverTimestamp": "2026-01-12T10:30:15Z",
  "hasMore": false
}
```

**Comportamento:**
- Inclui registros com `updated_at > since`
- Inclui registros com `deleted_at IS NOT NULL` (soft deletes)
- Cliente processa `deletedAt` para remover localmente
- Paginação: máximo 1000 registros por request

**Errors:**
- `401`: Token inválido
- `400`: Formato de timestamp inválido

---

## 🔒 Segurança

### JWT Configuration
```javascript
{
  "accessToken": {
    "secret": process.env.JWT_ACCESS_SECRET,
    "expiresIn": "1h",
    "algorithm": "HS256"
  },
  "refreshToken": {
    "secret": process.env.JWT_REFRESH_SECRET,
    "expiresIn": "30d",
    "algorithm": "HS256"
  }
}
```

### Access Token Payload
```json
{
  "userId": 123,
  "email": "user@example.com",
  "iat": 1736680200,
  "exp": 1736683800
}
```

### Refresh Token Payload
```json
{
  "userId": 123,
  "tokenId": "uuid-v4",
  "iat": 1736680200,
  "exp": 1739272200
}
```

### Password Hashing
- **Bcrypt** com salt rounds = 12
- Armazenar apenas hash, nunca senha em texto plano

### Rate Limiting
- Login: 5 tentativas / 15 minutos / IP
- Register: 3 tentativas / 1 hora / IP
- Sync endpoints: 100 requests / 1 hora / usuário

### Headers de Segurança
```
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
```

---

## 📁 Estrutura de Pastas Sugerida (Node.js/Express)

```
backend/
├── src/
│   ├── config/
│   │   ├── database.js          # Configuração PostgreSQL
│   │   ├── jwt.js               # Configuração JWT
│   │   └── environment.js       # Variáveis de ambiente
│   ├── models/
│   │   ├── User.js
│   │   ├── RefreshToken.js
│   │   ├── Account.js
│   │   ├── Category.js
│   │   └── ...
│   ├── controllers/
│   │   ├── authController.js    # register, login, refresh, logout
│   │   └── syncController.js    # push, pull
│   ├── middleware/
│   │   ├── authenticate.js      # Verifica JWT
│   │   ├── rateLimiter.js       # Rate limiting
│   │   └── validateRequest.js   # Validação de schemas
│   ├── routes/
│   │   ├── auth.js              # /api/auth/*
│   │   └── sync.js              # /api/sync/*
│   ├── services/
│   │   ├── authService.js       # Lógica de autenticação
│   │   ├── syncService.js       # Lógica de sincronização
│   │   └── conflictResolver.js  # Resolução server-wins
│   ├── utils/
│   │   ├── logger.js
│   │   ├── errors.js
│   │   └── validators.js
│   └── app.js                   # Inicialização Express
├── tests/
│   ├── auth.test.js
│   └── sync.test.js
├── migrations/
│   ├── 001_create_users.sql
│   ├── 002_create_refresh_tokens.sql
│   └── ...
├── .env.example
├── package.json
└── README.md
```

---

## 🧪 Fluxo de Testes

### Teste 1: Registro e Login
1. POST `/api/auth/register` → Recebe tokens
2. Validar `accessToken` decodifica corretamente
3. POST `/api/auth/login` → Recebe novos tokens
4. POST `/api/auth/logout` → Revoga refresh token

### Teste 2: Sincronização Create
1. Cliente cria conta offline (local_id=42, server_id=null)
2. POST `/api/sync/push` com action="create"
3. Servidor retorna `serverId=150`
4. Cliente atualiza `server_id=150, sync_status='synced'`

### Teste 3: Sincronização Update
1. Cliente edita conta existente (server_id=98)
2. POST `/api/sync/push` com action="update"
3. Servidor atualiza registro
4. Cliente marca `sync_status='synced'`

### Teste 4: Conflito Server-Wins
1. Cliente edita conta offline (updated_at=09:00)
2. Outro dispositivo edita mesma conta (updated_at=09:30)
3. POST `/api/sync/push` → Servidor detecta conflito
4. Servidor retorna versão mais recente em `conflicts[]`
5. Cliente substitui local com versão do servidor

### Teste 5: Pull Incremental
1. Cliente faz sync inicial
2. Servidor cria/edita registros
3. GET `/api/sync/pull?since=lastSyncTimestamp`
4. Cliente recebe apenas mudanças recentes

---

## 🚀 Deploy e Infraestrutura

### Recomendações
- **PostgreSQL:** Amazon RDS, Google Cloud SQL, ou Supabase
- **Backend:** Railway, Render, Fly.io, ou AWS ECS
- **CDN/Edge:** Cloudflare para cache de endpoints GET
- **Monitoring:** Sentry (erros), DataDog (APM)
- **Logs:** Structured logging com Winston/Pino

### Variáveis de Ambiente
```env
# Database
DATABASE_URL=postgresql://user:pass@host:5432/contaslite
DATABASE_POOL_MIN=2
DATABASE_POOL_MAX=10

# JWT
JWT_ACCESS_SECRET=your-256-bit-secret
JWT_REFRESH_SECRET=your-256-bit-secret

# Server
PORT=3000
NODE_ENV=production

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100

# Logging
LOG_LEVEL=info
```

---

## 📊 Monitoramento e Métricas

### Endpoints de Health Check
```
GET /health
GET /health/db
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-01-12T10:30:00Z",
  "database": "connected",
  "uptime": 86400
}
```

### Métricas Importantes
- Taxa de conflitos (conflicts / total syncs)
- Latência média de sync
- Taxa de erros 401/403 (possível ataque)
- Tempo de resposta P95/P99
- Crescimento de usuários ativos

---

## 🎯 Próximos Passos

1. **Escolher stack do backend:**
   - Node.js/Express + Sequelize/TypeORM
   - Python/FastAPI + SQLAlchemy
   - Go/Gin + GORM

2. **Configurar ambiente de desenvolvimento:**
   - Docker Compose com PostgreSQL
   - Seed inicial de dados de teste
   - Scripts de migração

3. **Implementar endpoints de autenticação:**
   - Register, login, refresh, logout
   - Testes unitários

4. **Implementar endpoints de sincronização:**
   - Push, pull
   - Resolução de conflitos
   - Testes de integração

5. **Testes end-to-end:**
   - App Flutter + Backend real
   - Cenários de conflito
   - Validação offline-first

---

## 📝 Notas Finais

- Este documento serve como **especificação completa** para qualquer desenvolvedor backend implementar a API
- As tabelas PostgreSQL **replicam** a estrutura SQLite local com adição de `user_id` para multi-tenancy
- Todos os endpoints devem retornar timestamps em **UTC ISO 8601**
- O cliente Flutter já está 100% pronto para consumir esta API (Phases 1-5 completas)
- A resolução **server-wins** é crítica para evitar loops de conflito

**Autor:** GitHub Copilot  
**Data:** 12 de janeiro de 2026  
**Versão:** 1.0
