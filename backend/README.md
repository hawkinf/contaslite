# Contaslite Backend API

Backend Node.js/Express para o aplicativo Contaslite com suporte multi-usuário, autenticação JWT e sincronização bidirecional.

## 🚀 Quick Start

### Pré-requisitos
- Node.js >= 20.0.0 (LTS)
- PostgreSQL >= 14
- npm >= 10.0.0

### Instalação

1. **Instalar dependências:**
```bash
cd backend
npm install
```

2. **Configurar variáveis de ambiente:**
```bash
cp .env.example .env
```

Edite o arquivo `.env` e configure:
- `DATABASE_URL`: URL do PostgreSQL
- `JWT_ACCESS_SECRET`: Chave secreta para access tokens
- `JWT_REFRESH_SECRET`: Chave secreta para refresh tokens

3. **Criar banco de dados:**
```bash
createdb contaslite
```

4. **Rodar migrations:**
```sql
-- Execute os scripts SQL em migrations/ na ordem
psql -d contaslite -f migrations/001_create_users.sql
psql -d contaslite -f migrations/002_create_refresh_tokens.sql
# etc...
```

5. **Iniciar servidor:**
```bash
# Desenvolvimento
npm run dev

# Produção
npm start
```

O servidor estará rodando em `http://localhost:3000`

## 📚 Endpoints

### Autenticação

#### POST `/api/auth/register`
Registra novo usuário.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "name": "João Silva"
}
```

**Response (201):**
```json
{
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "João Silva",
    "createdAt": "2026-01-12T10:00:00Z"
  },
  "accessToken": "eyJhbGc...",
  "refreshToken": "eyJhbGc...",
  "expiresIn": 3600
}
```

#### POST `/api/auth/login`
Autentica usuário.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!"
}
```

**Response (200):**
```json
{
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "João Silva"
  },
  "accessToken": "eyJhbGc...",
  "refreshToken": "eyJhbGc...",
  "expiresIn": 3600
}
```

#### POST `/api/auth/refresh`
Renova access token.

**Request:**
```json
{
  "refreshToken": "eyJhbGc..."
}
```

**Response (200):**
```json
{
  "accessToken": "eyJhbGc...",
  "refreshToken": "eyJhbGc...",
  "expiresIn": 3600
}
```

#### POST `/api/auth/logout`
Revoga refresh token.

**Headers:**
```
Authorization: Bearer {accessToken}
```

**Request:**
```json
{
  "refreshToken": "eyJhbGc..."
}
```

**Response (200):**
```json
{
  "message": "Logout realizado com sucesso"
}
```

### Sincronização

#### POST `/api/sync/push`
Envia alterações locais para servidor.

**Headers:**
```
Authorization: Bearer {accessToken}
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
          "description": "Conta de luz",
          "amount": 150.50,
          "dueDate": "2026-01-20",
          "status": "pending"
        },
        "updatedAt": "2026-01-12T08:00:00Z"
      }
    ]
  }
}
```

**Response (200):**
```json
{
  "processed": {
    "accounts": [
      {
        "localId": 42,
        "serverId": 150,
        "action": "created",
        "serverTimestamp": "2026-01-12T10:30:05Z"
      }
    ]
  },
  "conflicts": [],
  "serverTimestamp": "2026-01-12T10:30:10Z"
}
```

#### GET `/api/sync/pull?since={timestamp}`
Baixa alterações do servidor.

**Headers:**
```
Authorization: Bearer {accessToken}
```

**Query Params:**
- `since` (opcional): ISO 8601 timestamp

**Response (200):**
```json
{
  "data": {
    "accounts": [
      {
        "id": 98,
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

## 🧪 Testes

```bash
# Rodar todos os testes
npm test

# Testes com coverage
npm test -- --coverage

# Testes específicos
npm test -- auth.test.js
```

## 📁 Estrutura

```
backend/
├── src/
│   ├── config/          # Configurações (DB, JWT)
│   ├── controllers/     # Lógica de negócio
│   ├── middleware/      # Autenticação, rate limiting
│   ├── models/          # Modelos Sequelize
│   ├── routes/          # Definição de rotas
│   ├── utils/           # Utilitários (logger, etc)
│   └── app.js           # App principal
├── tests/               # Testes
├── migrations/          # Scripts SQL
├── logs/                # Logs (gitignored)
├── .env.example         # Template de variáveis
├── package.json
└── README.md
```

## 🔒 Segurança

- **JWT**: Access tokens (1h) + Refresh tokens (30d)
- **Bcrypt**: Hash de senhas com salt rounds = 12
- **Rate Limiting**: 
  - Login: 5 tentativas / 15 min
  - Register: 3 tentativas / 1 hora
  - Sync: 100 requests / 15 min
- **Helmet**: Headers de segurança HTTP
- **CORS**: Configurável por ambiente

## 🚧 TODO

- [ ] Implementar endpoints para categories, payment_methods, etc.
- [ ] Adicionar migrations SQL
- [ ] Testes unitários e de integração
- [ ] Documentação Swagger/OpenAPI
- [ ] CI/CD pipeline
- [ ] Docker Compose para desenvolvimento
- [ ] Seed de dados de teste

## 📖 Documentação Completa

Veja [BACKEND_SPEC.md](../BACKEND_SPEC.md) para especificação completa da API.

## 📄 Licença

MIT
