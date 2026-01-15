# DOCUMENTACAO COMPLETA DO BACKEND - CONTASLITE

## Indice

1. [Visao Geral](#1-visao-geral)
2. [Infraestrutura do Servidor](#2-infraestrutura-do-servidor)
3. [Configuracao de Rede](#3-configuracao-de-rede)
4. [PostgreSQL - Banco de Dados](#4-postgresql---banco-de-dados)
5. [API REST - Endpoints](#5-api-rest---endpoints)
6. [Autenticacao JWT](#6-autenticacao-jwt)
7. [Seguranca e Rate Limiting](#7-seguranca-e-rate-limiting)
8. [Deploy e Configuracao](#8-deploy-e-configuracao)
9. [Manutencao e Backup](#9-manutencao-e-backup)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. VISAO GERAL

### Arquitetura do Sistema

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENTE (App Flutter)                     │
│                     Contaslite Mobile/Desktop                    │
└─────────────────────────────────────┬───────────────────────────┘
                                      │
                                      │ HTTPS (Porta 443)
                                      │ ou HTTP (Porta 3000)
                                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SERVIDOR LINUX (Ubuntu/Debian)                │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                 NGINX (Proxy Reverso)                    │   │
│   │                   Porta 80/443                           │   │
│   └─────────────────────────────────────┬───────────────────┘   │
│                                         │                        │
│                                         ▼                        │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │              NODE.JS / EXPRESS API                       │   │
│   │                    Porta 3000                            │   │
│   │                                                          │   │
│   │   - Autenticacao (JWT)                                   │   │
│   │   - Sincronizacao (Push/Pull)                            │   │
│   │   - Health Checks                                        │   │
│   │   - Rate Limiting                                        │   │
│   └─────────────────────────────────────┬───────────────────┘   │
│                                         │                        │
│                                         ▼                        │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                  POSTGRESQL 14+                          │   │
│   │                    Porta 5432                            │   │
│   │                                                          │   │
│   │   - Database: contaslite                                 │   │
│   │   - Usuario: contaslite_user                             │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Stack Tecnologica

| Componente | Tecnologia | Versao |
|------------|------------|--------|
| Runtime | Node.js | 20.x LTS |
| Framework Web | Express.js | 4.18.2 |
| Banco de Dados | PostgreSQL | 14+ |
| ORM | Sequelize | 6.35.2 |
| Autenticacao | JSON Web Token (JWT) | 9.0.2 |
| Hash de Senhas | Bcrypt | 5.1.1 |
| Process Manager | PM2 | Latest |
| Reverse Proxy | Nginx | Latest |

---

## 2. INFRAESTRUTURA DO SERVIDOR

### Informacoes do Servidor

```
╔══════════════════════════════════════════════════════════════════╗
║                    DADOS DO SERVIDOR                              ║
╠══════════════════════════════════════════════════════════════════╣
║  Dominio/Host:     contaslite.hawk.com.br                        ║
║  Porta API:        3000                                          ║
║  Porta HTTPS:      443 (via Nginx)                               ║
║  Porta HTTP:       80 (redireciona para HTTPS)                   ║
║  Porta PostgreSQL: 5432 (interno apenas)                         ║
╚══════════════════════════════════════════════════════════════════╝
```

### URLs de Acesso

| Servico | URL |
|---------|-----|
| **Health Check** | `http://contaslite.hawk.com.br:3000/health` |
| **Health Check DB** | `http://contaslite.hawk.com.br:3000/health/db` |
| **API Base** | `http://contaslite.hawk.com.br:3000/api` |
| **Autenticacao** | `http://contaslite.hawk.com.br:3000/api/auth/*` |
| **Sincronizacao** | `http://contaslite.hawk.com.br:3000/api/sync/*` |

### Estrutura de Diretorios no Servidor

```
/var/www/contaslite-backend/
└── backend/
    ├── src/
    │   ├── app.js                 # Ponto de entrada da aplicacao
    │   ├── config/
    │   │   ├── database.js        # Configuracao PostgreSQL/Sequelize
    │   │   └── jwt.js             # Configuracao JWT
    │   ├── controllers/
    │   │   ├── authController.js  # Logica de autenticacao
    │   │   └── syncController.js  # Logica de sincronizacao
    │   ├── middleware/
    │   │   ├── authenticate.js    # Middleware JWT
    │   │   └── rateLimiter.js     # Rate limiting
    │   ├── models/
    │   │   ├── User.js            # Modelo de usuario
    │   │   ├── RefreshToken.js    # Modelo de tokens
    │   │   └── Account.js         # Modelo de contas
    │   ├── routes/
    │   │   ├── auth.js            # Rotas de autenticacao
    │   │   └── sync.js            # Rotas de sincronizacao
    │   └── utils/
    │       └── logger.js          # Sistema de logs
    ├── migrations/                 # Scripts SQL
    │   ├── 001_create_users.sql
    │   ├── 002_create_refresh_tokens.sql
    │   ├── 003_create_accounts.sql
    │   └── 004_create_supporting_tables.sql
    ├── scripts/
    │   ├── backup.sh              # Script de backup
    │   └── restore.sh             # Script de restauracao
    ├── logs/                       # Logs da aplicacao
    │   ├── combined.log
    │   └── error.log
    ├── .env                        # Variaveis de ambiente
    ├── .env.example               # Template de configuracao
    └── package.json               # Dependencias Node.js
```

---

## 3. CONFIGURACAO DE REDE

### Portas Utilizadas

```
╔═══════════╦═══════════════════════════════╦══════════════════════╗
║   PORTA   ║          SERVICO               ║       ACESSO         ║
╠═══════════╬═══════════════════════════════╬══════════════════════╣
║    22     ║ SSH                            ║ Externo (Restrito)   ║
║    80     ║ HTTP (Nginx)                   ║ Externo              ║
║   443     ║ HTTPS (Nginx + SSL)            ║ Externo              ║
║   3000    ║ Node.js API                    ║ Externo ou Interno   ║
║   5432    ║ PostgreSQL                     ║ Interno apenas       ║
╚═══════════╩═══════════════════════════════╩══════════════════════╝
```

### Configuracao do Firewall (UFW)

```bash
# Comandos para configurar firewall
sudo ufw allow ssh          # Porta 22
sudo ufw allow http         # Porta 80
sudo ufw allow https        # Porta 443
sudo ufw allow 3000         # Porta da API (se acesso direto)
sudo ufw enable             # Ativar firewall

# Verificar status
sudo ufw status verbose
```

**Resultado esperado:**
```
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
80/tcp                     ALLOW       Anywhere
443/tcp                    ALLOW       Anywhere
3000                       ALLOW       Anywhere
```

### Configuracao Nginx (Proxy Reverso)

**Arquivo:** `/etc/nginx/sites-available/contaslite-api`

```nginx
server {
    listen 80;
    server_name api.contaslite.hawk.com.br contaslite.hawk.com.br;

    # Redirecionar HTTP para HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.contaslite.hawk.com.br contaslite.hawk.com.br;

    # Certificados SSL (Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/contaslite.hawk.com.br/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/contaslite.hawk.com.br/privkey.pem;

    # Configuracoes SSL recomendadas
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers off;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

**Ativar configuracao:**
```bash
sudo ln -s /etc/nginx/sites-available/contaslite-api /etc/nginx/sites-enabled/
sudo nginx -t                    # Testar configuracao
sudo systemctl restart nginx     # Reiniciar Nginx
```

---

## 4. POSTGRESQL - BANCO DE DADOS

### Informacoes de Conexao

```
╔══════════════════════════════════════════════════════════════════╗
║                    CREDENCIAIS POSTGRESQL                         ║
╠══════════════════════════════════════════════════════════════════╣
║  Host:             localhost                                      ║
║  Porta:            5432                                          ║
║  Database:         contaslite                                    ║
║  Usuario:          contaslite_user                               ║
║  Connection Pool:  Min: 2, Max: 10                               ║
╚══════════════════════════════════════════════════════════════════╝
```

### String de Conexao

```
DATABASE_URL=postgresql://contaslite_user:SENHA_AQUI@localhost:5432/contaslite
```

### Schema do Banco de Dados

#### Tabela: users
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

#### Tabela: refresh_tokens
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

#### Tabela: account_types
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

#### Tabela: categories
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

#### Tabela: subcategories
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

#### Tabela: payment_methods
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

#### Tabela: accounts
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

#### Tabela: sync_log (Auditoria)
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

### Diagrama ER (Entidade-Relacionamento)

```
┌───────────────┐       ┌────────────────────┐
│    users      │───┬──<│  refresh_tokens    │
├───────────────┤   │   ├────────────────────┤
│ id (PK)       │   │   │ id (PK)            │
│ email         │   │   │ user_id (FK)       │
│ password_hash │   │   │ token_hash         │
│ name          │   │   │ expires_at         │
│ is_active     │   │   │ revoked            │
│ last_login    │   │   │ device_info        │
└───────────────┘   │   └────────────────────┘
        │           │
        │           ├──<┌────────────────────┐
        │           │   │  account_types     │
        │           │   ├────────────────────┤
        │           │   │ id (PK)            │
        │           │   │ user_id (FK)       │
        │           │   │ name               │
        │           │   │ icon, color        │
        │           │   └────────────────────┘
        │           │
        │           ├──<┌────────────────────┐
        │           │   │  categories        │───────┐
        │           │   ├────────────────────┤       │
        │           │   │ id (PK)            │       │
        │           │   │ user_id (FK)       │       │
        │           │   │ name               │       │
        │           │   │ icon, color        │       │
        │           │   └────────────────────┘       │
        │           │                                │
        │           │   ┌────────────────────┐       │
        │           ├──<│  subcategories     │<──────┘
        │           │   ├────────────────────┤
        │           │   │ id (PK)            │
        │           │   │ user_id (FK)       │
        │           │   │ category_id (FK)   │
        │           │   │ name               │
        │           │   └────────────────────┘
        │           │
        │           ├──<┌────────────────────┐
        │           │   │  payment_methods   │
        │           │   ├────────────────────┤
        │           │   │ id (PK)            │
        │           │   │ user_id (FK)       │
        │           │   │ name               │
        │           │   │ icon, color        │
        │           │   └────────────────────┘
        │           │
        │           └──<┌────────────────────┐
        │               │  accounts          │
        │               ├────────────────────┤
        │               │ id (PK)            │
        │               │ user_id (FK)       │
        │               │ type_id (FK)       │
        │               │ category_id (FK)   │
        │               │ subcategory_id (FK)│
        │               │ payment_method_id  │
        │               │ description        │
        │               │ amount             │
        │               │ due_date           │
        │               │ payment_date       │
        │               │ status             │
        │               │ deleted_at         │
        │               └────────────────────┘
        │
        └───────────<┌────────────────────┐
                     │  sync_log          │
                     ├────────────────────┤
                     │ id (PK)            │
                     │ user_id (FK)       │
                     │ action             │
                     │ table_name         │
                     │ record_id          │
                     │ conflict_resolution│
                     └────────────────────┘
```

---

## 5. API REST - ENDPOINTS

### Base URL
```
http://contaslite.hawk.com.br:3000
```

### Resumo de Endpoints

| Metodo | Endpoint | Descricao | Autenticacao |
|--------|----------|-----------|--------------|
| GET | `/health` | Health check geral | Nao |
| GET | `/health/db` | Health check do banco | Nao |
| POST | `/api/auth/register` | Registrar usuario | Nao |
| POST | `/api/auth/login` | Login | Nao |
| POST | `/api/auth/refresh` | Renovar token | Nao |
| POST | `/api/auth/logout` | Logout | Sim |
| POST | `/api/sync/push` | Enviar dados | Sim |
| GET | `/api/sync/pull` | Receber dados | Sim |

---

### HEALTH CHECK

#### GET /health
Verifica se o servidor esta online.

**Request:**
```bash
curl http://contaslite.hawk.com.br:3000/health
```

**Response 200:**
```json
{
  "status": "healthy",
  "timestamp": "2026-01-15T10:30:00.000Z",
  "uptime": 86400
}
```

---

#### GET /health/db
Verifica conexao com o banco de dados.

**Request:**
```bash
curl http://contaslite.hawk.com.br:3000/health/db
```

**Response 200:**
```json
{
  "status": "healthy",
  "database": "connected",
  "timestamp": "2026-01-15T10:30:00.000Z"
}
```

**Response 503 (Erro):**
```json
{
  "status": "unhealthy",
  "database": "disconnected",
  "error": "Connection refused"
}
```

---

### AUTENTICACAO

#### POST /api/auth/register
Cria nova conta de usuario.

**Request:**
```bash
curl -X POST http://contaslite.hawk.com.br:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "usuario@example.com",
    "password": "MinhaSenh@123",
    "name": "Joao Silva"
  }'
```

**Validacoes:**
- Email: formato valido e unico no sistema
- Senha: minimo 8 caracteres, 1 maiuscula, 1 numero
- Nome: minimo 2 caracteres

**Response 201 (Sucesso):**
```json
{
  "user": {
    "id": 123,
    "email": "usuario@example.com",
    "name": "Joao Silva",
    "createdAt": "2026-01-15T10:30:00.000Z"
  },
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 3600
}
```

**Errors:**
- `400`: Email ja existe, senha fraca, dados invalidos
- `429`: Rate limit excedido (max 3 tentativas/hora)

---

#### POST /api/auth/login
Autentica usuario existente.

**Request:**
```bash
curl -X POST http://contaslite.hawk.com.br:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "usuario@example.com",
    "password": "MinhaSenh@123"
  }'
```

**Response 200:**
```json
{
  "user": {
    "id": 123,
    "email": "usuario@example.com",
    "name": "Joao Silva"
  },
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 3600
}
```

**Errors:**
- `401`: Email ou senha incorretos
- `403`: Conta desativada
- `429`: Rate limit (max 5 tentativas em 15 min)

---

#### POST /api/auth/refresh
Renova access token usando refresh token.

**Request:**
```bash
curl -X POST http://contaslite.hawk.com.br:3000/api/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }'
```

**Response 200:**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 3600
}
```

**Errors:**
- `401`: Refresh token invalido ou revogado
- `403`: Refresh token expirado

---

#### POST /api/auth/logout
Revoga refresh token do usuario.

**Request:**
```bash
curl -X POST http://contaslite.hawk.com.br:3000/api/auth/logout \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }'
```

**Response 200:**
```json
{
  "message": "Logout realizado com sucesso"
}
```

---

### SINCRONIZACAO

#### POST /api/sync/push
Envia alteracoes locais para o servidor.

**Headers:**
```
Authorization: Bearer {accessToken}
Content-Type: application/json
```

**Request:**
```bash
curl -X POST http://contaslite.hawk.com.br:3000/api/sync/push \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIs..." \
  -H "Content-Type: application/json" \
  -d '{
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
          "updatedAt": "2026-01-15T08:00:00Z"
        },
        {
          "localId": 15,
          "serverId": 98,
          "action": "update",
          "data": {
            "status": "paid",
            "paymentDate": "2026-01-15"
          },
          "updatedAt": "2026-01-15T09:15:00Z"
        },
        {
          "localId": 20,
          "serverId": 75,
          "action": "delete",
          "updatedAt": "2026-01-15T10:00:00Z"
        }
      ],
      "categories": [...],
      "paymentMethods": [...]
    }
  }'
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
        "serverTimestamp": "2026-01-15T10:30:05Z"
      },
      {
        "localId": 15,
        "serverId": 98,
        "action": "updated",
        "serverTimestamp": "2026-01-15T10:30:06Z"
      }
    ]
  },
  "conflicts": [
    {
      "localId": 15,
      "serverId": 98,
      "table": "accounts",
      "reason": "Server version is newer",
      "serverVersion": {...},
      "resolution": "server_wins"
    }
  ],
  "serverTimestamp": "2026-01-15T10:30:10Z"
}
```

**Resolucao de Conflitos:**
- Politica: **Server Wins** (versao do servidor sempre prevalece)
- Se `server.updated_at > client.updated_at`, servidor vence
- Cliente recebe versao do servidor em `conflicts[]`

---

#### GET /api/sync/pull
Baixa alteracoes do servidor desde ultimo sync.

**Headers:**
```
Authorization: Bearer {accessToken}
```

**Query Parameters:**
- `since` (opcional): ISO 8601 timestamp

**Request:**
```bash
curl -X GET "http://contaslite.hawk.com.br:3000/api/sync/pull?since=2026-01-15T08:00:00Z" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIs..."
```

**Response 200:**
```json
{
  "data": {
    "accountTypes": [...],
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
        "updatedAt": "2026-01-15T09:30:00Z",
        "deletedAt": null
      }
    ]
  },
  "serverTimestamp": "2026-01-15T10:30:15Z",
  "hasMore": false
}
```

---

## 6. AUTENTICACAO JWT

### Configuracao

```javascript
{
  "accessToken": {
    "secret": process.env.JWT_ACCESS_SECRET,
    "expiresIn": "1h",           // 1 hora
    "algorithm": "HS256"
  },
  "refreshToken": {
    "secret": process.env.JWT_REFRESH_SECRET,
    "expiresIn": "30d",          // 30 dias
    "algorithm": "HS256"
  }
}
```

### Payload do Access Token

```json
{
  "userId": 123,
  "email": "usuario@example.com",
  "iat": 1736935800,
  "exp": 1736939400
}
```

### Payload do Refresh Token

```json
{
  "userId": 123,
  "tokenId": "550e8400-e29b-41d4-a716-446655440000",
  "iat": 1736935800,
  "exp": 1739527800
}
```

### Fluxo de Autenticacao

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLUXO DE AUTENTICACAO                         │
└─────────────────────────────────────────────────────────────────┘

1. LOGIN
   Cliente ──POST /api/auth/login──> Servidor
           <──{accessToken, refreshToken}──

2. ACESSO A RECURSOS PROTEGIDOS
   Cliente ──GET /api/sync/pull + Header: Authorization: Bearer {accessToken}──> Servidor
           <──{data}──

3. TOKEN EXPIRADO (apos 1 hora)
   Cliente ──GET /api/sync/pull──> Servidor
           <──401 Unauthorized──

4. REFRESH TOKEN
   Cliente ──POST /api/auth/refresh + {refreshToken}──> Servidor
           <──{newAccessToken, newRefreshToken}──

5. LOGOUT
   Cliente ──POST /api/auth/logout + {refreshToken}──> Servidor
           <──200 OK (token revogado)──
```

### Seguranca de Senhas

- **Algoritmo:** Bcrypt
- **Salt Rounds:** 12
- **Armazenamento:** Apenas hash, nunca texto plano

---

## 7. SEGURANCA E RATE LIMITING

### Rate Limiting

| Endpoint | Limite | Janela de Tempo |
|----------|--------|-----------------|
| `/api/auth/login` | 5 tentativas | 15 minutos |
| `/api/auth/register` | 3 tentativas | 1 hora |
| `/api/sync/*` | 100 requests | 15 minutos |

### Headers de Seguranca (Helmet.js)

```
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
X-Download-Options: noopen
X-Permitted-Cross-Domain-Policies: none
```

### Configuracao CORS

```javascript
{
  origin: process.env.CORS_ORIGIN || '*',
  credentials: true
}
```

### Validacoes de Seguranca

1. **Email:** Formato valido
2. **Senha:**
   - Minimo 8 caracteres
   - 1 letra maiuscula
   - 1 numero
3. **Tokens:** Verificacao de expiracao e revogacao
4. **Input:** Sanitizacao de dados de entrada

---

## 8. DEPLOY E CONFIGURACAO

### Variaveis de Ambiente (.env)

```env
# ═══════════════════════════════════════════════════════════════
#                    BANCO DE DADOS
# ═══════════════════════════════════════════════════════════════
DATABASE_URL=postgresql://contaslite_user:SENHA_SEGURA@localhost:5432/contaslite
DATABASE_POOL_MIN=2
DATABASE_POOL_MAX=10

# ═══════════════════════════════════════════════════════════════
#                    JWT (ALTERAR EM PRODUCAO!)
# ═══════════════════════════════════════════════════════════════
# Gerar chaves: openssl rand -hex 32
JWT_ACCESS_SECRET=sua-chave-super-secreta-access-256-bits
JWT_REFRESH_SECRET=sua-chave-super-secreta-refresh-256-bits

# ═══════════════════════════════════════════════════════════════
#                    SERVIDOR
# ═══════════════════════════════════════════════════════════════
PORT=3000
NODE_ENV=production

# ═══════════════════════════════════════════════════════════════
#                    RATE LIMITING
# ═══════════════════════════════════════════════════════════════
RATE_LIMIT_WINDOW_MS=900000          # 15 minutos em ms
RATE_LIMIT_MAX_REQUESTS=100          # Requests por janela
RATE_LIMIT_LOGIN_MAX=5               # Tentativas de login
RATE_LIMIT_LOGIN_WINDOW_MS=900000    # 15 minutos

# ═══════════════════════════════════════════════════════════════
#                    LOGGING
# ═══════════════════════════════════════════════════════════════
LOG_LEVEL=info

# ═══════════════════════════════════════════════════════════════
#                    CORS
# ═══════════════════════════════════════════════════════════════
CORS_ORIGIN=*
```

### Gerar Chaves JWT Seguras

```bash
# No servidor Linux
openssl rand -hex 32
# Resultado exemplo: a7b9c3d5e7f9... (64 caracteres)

# Copie e cole no .env
JWT_ACCESS_SECRET=a7b9c3d5e7f9...
JWT_REFRESH_SECRET=outro_valor_gerado...
```

### PM2 - Process Manager

**Iniciar aplicacao:**
```bash
cd /var/www/contaslite-backend/backend
pm2 start src/app.js --name contaslite-api --env production
```

**Configurar inicio automatico:**
```bash
pm2 startup
# Copie e execute o comando gerado
pm2 save
```

**Comandos uteis:**
```bash
pm2 status                    # Ver status
pm2 logs contaslite-api       # Ver logs
pm2 restart contaslite-api    # Reiniciar
pm2 stop contaslite-api       # Parar
pm2 delete contaslite-api     # Remover
pm2 monit                     # Monitor interativo
```

### Checklist de Deploy

- [ ] Node.js 20+ instalado
- [ ] PostgreSQL 14+ instalado e rodando
- [ ] Database `contaslite` criada
- [ ] Usuario `contaslite_user` criado com permissoes
- [ ] Migrations SQL executadas (001 -> 004)
- [ ] Arquivo `.env` configurado com chaves JWT unicas
- [ ] Dependencias instaladas (`npm install --production`)
- [ ] Servidor testado (`npm start`)
- [ ] PM2 configurado e rodando
- [ ] Nginx configurado (opcional)
- [ ] SSL/HTTPS configurado (Let's Encrypt)
- [ ] Firewall configurado (UFW)
- [ ] Health check respondendo
- [ ] Teste de registro/login funcionando

---

## 9. MANUTENCAO E BACKUP

### Script de Backup

**Arquivo:** `/var/www/contaslite-backend/backend/scripts/backup.sh`

```bash
#!/bin/bash
# Script de backup automatico do PostgreSQL

# Configuracoes
DB_NAME="contaslite"
DB_USER="contaslite_user"
BACKUP_DIR="/var/backups/contaslite"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/contaslite_$DATE.sql"
RETENTION_DAYS=7

# Criar diretorio de backup se nao existir
mkdir -p $BACKUP_DIR

# Fazer backup
echo "Iniciando backup do banco de dados..."
pg_dump -U $DB_USER -h localhost $DB_NAME > $BACKUP_FILE

# Comprimir backup
gzip $BACKUP_FILE
echo "Backup criado: ${BACKUP_FILE}.gz"

# Remover backups antigos
echo "Removendo backups com mais de $RETENTION_DAYS dias..."
find $BACKUP_DIR -name "contaslite_*.sql.gz" -mtime +$RETENTION_DAYS -delete

# Listar backups disponiveis
echo "Backups disponiveis:"
ls -lh $BACKUP_DIR

echo "Backup concluido!"
```

**Agendar backup automatico (cron):**
```bash
# Editar crontab
crontab -e

# Adicionar linha para backup diario as 2h da manha
0 2 * * * /var/www/contaslite-backend/backend/scripts/backup.sh >> /var/log/contaslite-backup.log 2>&1
```

### Script de Restauracao

**Arquivo:** `/var/www/contaslite-backend/backend/scripts/restore.sh`

```bash
#!/bin/bash
# Script para restaurar backup do PostgreSQL
# Uso: ./restore.sh contaslite_20260115_020000.sql.gz

if [ -z "$1" ]; then
    echo "Erro: Especifique o arquivo de backup"
    echo "Uso: ./restore.sh <arquivo_backup.sql.gz>"
    echo ""
    echo "Backups disponiveis:"
    ls -1 /var/backups/contaslite/
    exit 1
fi

# Configuracoes
DB_NAME="contaslite"
DB_USER="contaslite_user"
BACKUP_FILE="$1"

# Verificar se arquivo existe
if [ ! -f "$BACKUP_FILE" ]; then
    BACKUP_FILE="/var/backups/contaslite/$1"
    if [ ! -f "$BACKUP_FILE" ]; then
        echo "Erro: Arquivo de backup nao encontrado: $1"
        exit 1
    fi
fi

# Confirmar restauracao
echo "ATENCAO: Esta operacao ira sobrescrever o banco de dados atual!"
echo "Banco: $DB_NAME"
echo "Backup: $BACKUP_FILE"
read -p "Deseja continuar? (sim/nao): " confirm

if [ "$confirm" != "sim" ]; then
    echo "Restauracao cancelada"
    exit 0
fi

# Fazer backup de seguranca antes de restaurar
echo "Criando backup de seguranca do estado atual..."
SAFETY_BACKUP="/var/backups/contaslite/pre-restore_$(date +%Y%m%d_%H%M%S).sql"
pg_dump -U $DB_USER -h localhost $DB_NAME > $SAFETY_BACKUP
gzip $SAFETY_BACKUP
echo "Backup de seguranca: ${SAFETY_BACKUP}.gz"

# Descomprimir e restaurar
if [[ $BACKUP_FILE == *.gz ]]; then
    echo "Descomprimindo backup..."
    gunzip -c $BACKUP_FILE > /tmp/restore.sql
    psql -U $DB_USER -h localhost $DB_NAME < /tmp/restore.sql
    rm /tmp/restore.sql
else
    psql -U $DB_USER -h localhost $DB_NAME < $BACKUP_FILE
fi

echo "Backup restaurado com sucesso!"
```

### Logs

**Localizacao dos logs:**
```
/var/www/contaslite-backend/backend/logs/
├── combined.log    # Todos os logs
└── error.log       # Apenas erros
```

**Comandos para visualizar:**
```bash
# Logs em tempo real
tail -f /var/www/contaslite-backend/backend/logs/combined.log

# Ultimas 100 linhas de erro
tail -100 /var/www/contaslite-backend/backend/logs/error.log

# Logs via PM2
pm2 logs contaslite-api --lines 100
```

---

## 10. TROUBLESHOOTING

### Problemas Comuns

#### 1. "connect ECONNREFUSED" (PostgreSQL)

```bash
# Verificar se PostgreSQL esta rodando
sudo systemctl status postgresql

# Iniciar se necessario
sudo systemctl start postgresql

# Verificar logs do PostgreSQL
sudo tail -f /var/log/postgresql/postgresql-14-main.log
```

#### 2. "Peer authentication failed" (PostgreSQL)

```bash
# Editar pg_hba.conf
sudo nano /etc/postgresql/14/main/pg_hba.conf

# Alterar "peer" para "md5" na linha:
# local   all   all   peer
# Para:
# local   all   all   md5

# Reiniciar PostgreSQL
sudo systemctl restart postgresql
```

#### 3. "role does not exist" (PostgreSQL)

```bash
# Conectar como postgres
sudo -u postgres psql

# Criar usuario
CREATE USER contaslite_user WITH PASSWORD 'SuaSenha';
GRANT ALL PRIVILEGES ON DATABASE contaslite TO contaslite_user;
\q
```

#### 4. Porta 3000 ja em uso

```bash
# Descobrir processo usando porta 3000
sudo lsof -i :3000

# Matar processo
sudo kill -9 PID

# Ou mudar porta no .env
PORT=3001
```

#### 5. API nao responde externamente

```bash
# Verificar firewall
sudo ufw status

# Permitir porta 3000
sudo ufw allow 3000

# Verificar se PM2 esta rodando
pm2 status
```

#### 6. Erro de SSL/HTTPS

```bash
# Instalar certbot (Let's Encrypt)
sudo apt install certbot python3-certbot-nginx

# Gerar certificado
sudo certbot --nginx -d contaslite.hawk.com.br

# Renovar automaticamente (ja configurado)
sudo certbot renew --dry-run
```

### Comandos de Diagnostico

```bash
# Status geral do servidor
pm2 status
sudo systemctl status postgresql
sudo systemctl status nginx

# Testar API
curl http://localhost:3000/health
curl http://localhost:3000/health/db

# Ver logs
pm2 logs contaslite-api --lines 50

# Uso de recursos
pm2 monit

# Conexoes PostgreSQL ativas
sudo -u postgres psql -c "SELECT * FROM pg_stat_activity WHERE datname='contaslite';"
```

---

## RESUMO RAPIDO

### Dados Essenciais

| Item | Valor |
|------|-------|
| **Dominio** | contaslite.hawk.com.br |
| **Porta API** | 3000 |
| **Database** | contaslite |
| **Usuario DB** | contaslite_user |
| **Health Check** | /health |
| **Base URL API** | /api |

### Testar Conexao

```bash
# Health check
curl http://contaslite.hawk.com.br:3000/health

# Registrar usuario
curl -X POST http://contaslite.hawk.com.br:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"teste@email.com","password":"Teste123!","name":"Usuario Teste"}'
```

---

**Documento criado em:** 15 de Janeiro de 2026
**Versao:** 1.0
**Mantido por:** Equipe Contaslite
