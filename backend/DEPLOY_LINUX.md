# 🚀 Deploy do Backend no Servidor Linux

Guia completo para fazer deploy do backend Contaslite em servidor Linux com PostgreSQL.

## 📋 Pré-requisitos no Servidor

- Ubuntu/Debian ou similar
- Node.js 20.x ou superior (LTS)
- PostgreSQL 14+ instalado e rodando
- Acesso SSH (root ou sudo)
- Porta 3000 liberada (ou outra porta de sua escolha)

---

## 🔧 Passo 1: Instalar Node.js no Servidor

```bash
# Conectar via SSH
ssh usuario@seu-servidor.com

# Atualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar Node.js 20.x (LTS)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Verificar instalação
node --version  # Deve mostrar v20.x.x
npm --version   # Deve mostrar 10.x.x
```

---

## 📦 Passo 2: Transferir Código para o Servidor

### Opção A: Via Git (Recomendado)

```bash
# No servidor
cd /var/www  # ou outro diretório de sua escolha
sudo mkdir -p contaslite-backend
sudo chown $USER:$USER contaslite-backend
cd contaslite-backend

# Clonar apenas a pasta backend (sparse checkout)
git init
git remote add origin https://github.com/hawkinf/contaslite.git
git config core.sparseCheckout true
echo "backend/" >> .git/info/sparse-checkout
git pull origin main
cd backend
```

### Opção B: Via SCP (Upload Manual)

```bash
# No seu computador Windows (PowerShell)
cd C:\flutter\Contaslite
scp -r backend usuario@seu-servidor.com:/var/www/contaslite-backend/
```

---

## 🗄️ Passo 3: Configurar PostgreSQL

```bash
# No servidor, acessar PostgreSQL
sudo -u postgres psql

# Dentro do psql:
CREATE DATABASE contaslite;
CREATE USER contaslite_user WITH PASSWORD 'SuaSenhaSegura123!';
GRANT ALL PRIVILEGES ON DATABASE contaslite TO contaslite_user;
ALTER DATABASE contaslite OWNER TO contaslite_user;
\q

# Testar conexão
psql -U contaslite_user -d contaslite -h localhost
# Digite a senha quando solicitado
# Se conectar, está OK! Digite \q para sair
```

---

## 📝 Passo 4: Rodar Migrations SQL

```bash
# No diretório do backend
cd /var/www/contaslite-backend/backend

# Rodar migrations na ordem
psql -U contaslite_user -d contaslite -h localhost -f migrations/001_create_users.sql
psql -U contaslite_user -d contaslite -h localhost -f migrations/002_create_refresh_tokens.sql
# psql -U contaslite_user -d contaslite -h localhost -f migrations/003_create_accounts.sql

# Verificar tabelas criadas
psql -U contaslite_user -d contaslite -h localhost -c "\dt"
# Deve mostrar: users, refresh_tokens
```

**IMPORTANTE:** Antes de rodar `003_create_accounts.sql`, você precisa criar as tabelas:
- `account_types`
- `categories`
- `subcategories`
- `payment_methods`

Veja o arquivo [migrations/004_create_supporting_tables.sql] que vou criar abaixo.

---

## 🔐 Passo 5: Configurar Variáveis de Ambiente

```bash
# No servidor
cd /var/www/contaslite-backend/backend

# Copiar template
cp .env.example .env

# Editar com nano ou vim
nano .env
```

**Conteúdo do .env:**
```env
# Database
DATABASE_URL=postgresql://contaslite_user:SuaSenhaSegura123!@localhost:5432/contaslite
DATABASE_POOL_MIN=2
DATABASE_POOL_MAX=10

# JWT Secrets (GERE CHAVES ÚNICAS!)
JWT_ACCESS_SECRET=sua-chave-super-secreta-access-mude-isso-agora-$(openssl rand -hex 32)
JWT_REFRESH_SECRET=sua-chave-super-secreta-refresh-mude-isso-agora-$(openssl rand -hex 32)

# Server
PORT=3000
NODE_ENV=production

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
RATE_LIMIT_LOGIN_MAX=5
RATE_LIMIT_LOGIN_WINDOW_MS=900000

# Logging
LOG_LEVEL=info

# CORS (substitua pelo domínio/IP do seu app)
CORS_ORIGIN=*
```

**Gerar chaves seguras JWT:**
```bash
# Gerar chave aleatória
openssl rand -hex 32
# Copie o resultado e cole em JWT_ACCESS_SECRET

openssl rand -hex 32
# Copie o resultado e cole em JWT_REFRESH_SECRET
```

**Salvar e sair:** `Ctrl+O`, `Enter`, `Ctrl+X`

---

## 📥 Passo 6: Instalar Dependências

```bash
cd /var/www/contaslite-backend/backend

# Instalar dependências de produção
npm install --production

# Criar pasta de logs
mkdir -p logs
```

---

## ▶️ Passo 7: Testar o Servidor

```bash
# Rodar em modo teste
NODE_ENV=development npm start

# Deve mostrar:
# ✅ Database connection established successfully.
# 🚀 Server running on port 3000
# 📝 Environment: development
# 🔗 Health check: http://localhost:3000/health
```

**Em outro terminal SSH, testar:**
```bash
curl http://localhost:3000/health
# Resposta esperada:
# {"status":"healthy","timestamp":"2026-01-12T...","uptime":5}

curl http://localhost:3000/health/db
# Resposta esperada:
# {"status":"healthy","database":"connected","timestamp":"..."}
```

Se tudo funcionar, **pressione Ctrl+C** para parar o servidor.

---

## 🔄 Passo 8: Configurar PM2 (Process Manager)

PM2 mantém o servidor rodando em background e reinicia automaticamente em caso de crash.

```bash
# Instalar PM2 globalmente
sudo npm install -g pm2

# Iniciar servidor com PM2
cd /var/www/contaslite-backend/backend
pm2 start src/app.js --name contaslite-api --env production

# Verificar status
pm2 status

# Ver logs em tempo real
pm2 logs contaslite-api

# Configurar PM2 para iniciar no boot
pm2 startup
# Copie e execute o comando que aparecer

pm2 save
```

**Comandos úteis PM2:**
```bash
pm2 restart contaslite-api    # Reiniciar
pm2 stop contaslite-api        # Parar
pm2 delete contaslite-api      # Remover
pm2 logs contaslite-api        # Ver logs
pm2 monit                      # Monitor interativo
```

---

## 🌐 Passo 9: Configurar Nginx (Proxy Reverso - Opcional)

Se quiser expor a API na porta 80/443 com domínio:

```bash
# Instalar Nginx
sudo apt install -y nginx

# Criar configuração
sudo nano /etc/nginx/sites-available/contaslite-api
```

**Conteúdo:**
```nginx
server {
    listen 80;
    server_name api.seudominio.com;  # Substitua pelo seu domínio

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
    }
}
```

**Ativar configuração:**
```bash
sudo ln -s /etc/nginx/sites-available/contaslite-api /etc/nginx/sites-enabled/
sudo nginx -t  # Testar configuração
sudo systemctl restart nginx
```

---

## 🔥 Passo 10: Configurar Firewall

```bash
# Permitir SSH, HTTP, HTTPS
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https

# Se não usar Nginx, permitir porta 3000
sudo ufw allow 3000

# Ativar firewall
sudo ufw enable
sudo ufw status
```

---

## ✅ Passo 11: Testar API Externamente

**Do seu computador Windows (PowerShell):**

```powershell
# Substituir IP_DO_SERVIDOR pelo IP real
$baseUrl = "http://IP_DO_SERVIDOR:3000"

# Health check
Invoke-RestMethod -Uri "$baseUrl/health"

# Registrar usuário
$body = @{
    email = "teste@example.com"
    password = "Teste123!"
    name = "Usuario Teste"
} | ConvertTo-Json

Invoke-RestMethod -Uri "$baseUrl/api/auth/register" -Method Post -Body $body -ContentType "application/json"
```

Se retornar JSON com `accessToken`, está funcionando! 🎉

---

## 🔍 Troubleshooting

### Erro: "connect ECONNREFUSED"
```bash
# Verificar se PostgreSQL está rodando
sudo systemctl status postgresql

# Iniciar se não estiver
sudo systemctl start postgresql
```

### Erro: "role does not exist"
```bash
# Recriar usuário PostgreSQL
sudo -u postgres psql
CREATE USER contaslite_user WITH PASSWORD 'SuaSenha';
GRANT ALL PRIVILEGES ON DATABASE contaslite TO contaslite_user;
```

### Ver logs do PM2
```bash
pm2 logs contaslite-api --lines 100
```

### Ver logs do Nginx
```bash
sudo tail -f /var/log/nginx/error.log
```

### Porta 3000 já em uso
```bash
# Descobrir processo usando porta 3000
sudo lsof -i :3000

# Matar processo se necessário
sudo kill -9 PID
```

---

## 📊 Monitoramento

### Ver uso de recursos
```bash
pm2 monit
```

### Ver logs de produção
```bash
# Logs do app
tail -f /var/www/contaslite-backend/backend/logs/combined.log

# Logs de erro
tail -f /var/www/contaslite-backend/backend/logs/error.log
```

---

## 🔄 Atualizar o Backend

```bash
cd /var/www/contaslite-backend/backend

# Se usando Git
git pull origin main
npm install --production
pm2 restart contaslite-api

# Se usando SCP
# 1. Fazer backup
cp -r /var/www/contaslite-backend/backend /var/www/contaslite-backend/backend.backup

# 2. No Windows, fazer upload
scp -r backend usuario@servidor:/var/www/contaslite-backend/

# 3. No servidor
cd /var/www/contaslite-backend/backend
npm install --production
pm2 restart contaslite-api
```

---

## 📝 Checklist Final

- [ ] Node.js 18+ instalado
- [ ] PostgreSQL rodando
- [ ] Database `contaslite` criada
- [ ] Migrations executadas
- [ ] `.env` configurado com chaves JWT únicas
- [ ] Dependências instaladas (`npm install`)
- [ ] Servidor testado com `npm start`
- [ ] PM2 configurado e rodando
- [ ] Firewall configurado
- [ ] API acessível externamente
- [ ] Teste de registro/login funcionando

---

## 🎯 Próximos Passos

1. **Configurar SSL/HTTPS:**
   - Use Let's Encrypt com Certbot
   - `sudo certbot --nginx -d api.seudominio.com`

2. **Configurar backup automático:**
   - Script cron para backup do PostgreSQL
   - Exemplo em `scripts/backup.sh`

3. **Integrar com app Flutter:**
   - Atualizar `AuthService.baseUrl` no app
   - Testar login/sync do dispositivo real

4. **Monitorar erros:**
   - Integrar Sentry ou similar
   - Configurar alertas de erro

---

## 📞 Suporte

Se tiver problemas:
1. Verificar logs: `pm2 logs contaslite-api`
2. Testar health check: `curl http://localhost:3000/health`
3. Verificar PostgreSQL: `sudo systemctl status postgresql`
4. Revisar `.env` e `DATABASE_URL`

**Autor:** GitHub Copilot  
**Data:** 12 de janeiro de 2026
