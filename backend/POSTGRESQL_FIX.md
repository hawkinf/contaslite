# 🔧 Resolver Problemas de Autenticação PostgreSQL

## Problema: "Peer authentication failed"

Isso acontece porque o PostgreSQL está configurado para usar autenticação "peer" em vez de "password". Vamos corrigir:

---

## ✅ Solução Rápida

### 1. Conectar como root do sistema (sem senha)
```bash
# Como root, você pode entrar no PostgreSQL sem senha
sudo -u postgres psql
```

### 2. Resetar senha do usuário contaslite_user
```sql
-- Dentro do psql
ALTER USER contaslite_user WITH PASSWORD 'SuaNovaSenha123!';
```

### 3. Verificar se o usuário existe e tem permissões
```sql
-- Listar usuários
\du

-- Você deve ver contaslite_user na lista
-- Se não existir, criar:
-- CREATE USER contaslite_user WITH PASSWORD 'SuaNovaSenha123!';

-- Garantir permissões
GRANT ALL PRIVILEGES ON DATABASE contaslite TO contaslite_user;

-- Sair
\q
```

---

## 🔐 Configurar Autenticação por Senha

### 4. Editar arquivo pg_hba.conf

```bash
# Localizar arquivo de configuração
sudo find /etc/postgresql -name pg_hba.conf

# Geralmente está em:
# /etc/postgresql/14/main/pg_hba.conf (PostgreSQL 14)
# /etc/postgresql/15/main/pg_hba.conf (PostgreSQL 15)
# /etc/postgresql/16/main/pg_hba.conf (PostgreSQL 16)

# Editar o arquivo (substitua 14 pela sua versão)
sudo nano /etc/postgresql/14/main/pg_hba.conf
```

### 5. Modificar as linhas de autenticação

Procure por estas linhas:
```conf
# "local" is for Unix domain socket connections only
local   all             all                                     peer
# IPv4 local connections:
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256
```

**Altere "peer" para "md5" ou "scram-sha-256":**
```conf
# "local" is for Unix domain socket connections only
local   all             all                                     md5
# IPv4 local connections:
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256
```

**Salvar:** `Ctrl+O`, `Enter`, `Ctrl+X`

### 6. Reiniciar PostgreSQL

```bash
# Descobrir versão instalada
sudo systemctl list-units | grep postgresql

# Reiniciar (substitua 14 pela sua versão)
sudo systemctl restart postgresql@14-main

# Ou simplesmente:
sudo systemctl restart postgresql
```

---

## ✅ Testar Conexão

```bash
# Agora deve pedir senha
psql -U contaslite_user -d contaslite -h localhost

# Digite a senha quando solicitado
# Se conectar, sucesso! Digite \q para sair
```

---

## 📋 Comandos Úteis PostgreSQL

### Listar bancos de dados
```bash
sudo -u postgres psql -c "\l"
```

### Listar usuários
```bash
sudo -u postgres psql -c "\du"
```

### Resetar senha do postgres (usuário admin)
```bash
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'NovaSenhaAdmin123!';"
```

### Deletar e recriar tudo do zero
```bash
# Conectar como postgres
sudo -u postgres psql

# Deletar database e usuário
DROP DATABASE IF EXISTS contaslite;
DROP USER IF EXISTS contaslite_user;

# Recriar
CREATE DATABASE contaslite;
CREATE USER contaslite_user WITH PASSWORD 'SuaNovaSenha123!';
GRANT ALL PRIVILEGES ON DATABASE contaslite TO contaslite_user;
ALTER DATABASE contaslite OWNER TO contaslite_user;

# Sair
\q
```

---

## 🎯 Sequência Completa do Zero

Se quiser começar do zero:

```bash
# 1. Conectar como postgres (sem senha)
sudo -u postgres psql

# 2. Dentro do psql, deletar tudo
DROP DATABASE IF EXISTS contaslite;
DROP USER IF EXISTS contaslite_user;

# 3. Recriar database e usuário
CREATE DATABASE contaslite;
CREATE USER contaslite_user WITH PASSWORD 'FuckyouCom1!';
GRANT ALL PRIVILEGES ON DATABASE contaslite TO contaslite_user;
ALTER DATABASE contaslite OWNER TO contaslite_user;

# 4. Verificar
\l
\du
\q

# 5. Testar conexão (deve pedir senha)
psql -U contaslite_user -d contaslite -h localhost
# Digite a senha: FuckyouCom1!
# Se conectar, digite \q para sair
```

---

## 🔑 Credenciais para o .env

Depois que funcionar, use no arquivo `.env`:

```env
DATABASE_URL=postgresql://contaslite_user:FuckyouCom1!@localhost:5432/contaslite
```

**⚠️ IMPORTANTE:** A senha tem caracteres especiais, se der erro, use URL encoding:
- `!` → `%21`
- `.` → `.` (ponto não precisa codificar)

```env
DATABASE_URL=postgresql://contaslite_user:FuckyouCom1%21@localhost:5432/contaslite
```

---

## 🐛 Troubleshooting

### Erro: "database does not exist"
```bash
sudo -u postgres psql -c "CREATE DATABASE contaslite;"
```

### Erro: "role does not exist"
```bash
sudo -u postgres psql -c "CREATE USER contaslite_user WITH PASSWORD 'SuaSenha';"
```

### Esqueci qual versão do PostgreSQL está instalada
```bash
psql --version
# ou
sudo -u postgres psql -c "SELECT version();"
```

### PostgreSQL não está rodando
```bash
sudo systemctl status postgresql
sudo systemctl start postgresql
```

---

## ✅ Checklist Final

- [ ] Conectou com `sudo -u postgres psql` (sem senha)
- [ ] Database `contaslite` existe (`\l`)
- [ ] Usuário `contaslite_user` existe (`\du`)
- [ ] Senha resetada com `ALTER USER`
- [ ] Arquivo `pg_hba.conf` configurado com `md5`
- [ ] PostgreSQL reiniciado
- [ ] Conexão testada: `psql -U contaslite_user -d contaslite -h localhost`
- [ ] `.env` atualizado com DATABASE_URL correta

Se tudo isso funcionar, você está pronto para rodar as migrations!
