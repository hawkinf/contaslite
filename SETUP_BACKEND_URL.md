# Como Configurar o Backend no App Flutter

## 1. Abrir as Configurações
1. Execute o app Flutter (`flutter run`)
2. Toque no ícone de **Configurações** (engrenagem) no canto superior direito
3. Role até a seção **"Banco de Dados"** e toque

## 2. Configurar a URL da API
Na tela "Configurações do Banco de Dados", preencha:

- **URL da API**: `http://contaslite.hawk.com.br:3000`
- **Habilitar sincronização**: ✅ Marcar este checkbox

### Campos opcionais (não precisam ser preenchidos):
- ~~Host PostgreSQL~~
- ~~Porta PostgreSQL~~
- ~~Nome do banco~~
- ~~Usuário~~
- ~~Senha~~

> **Nota:** Como você está usando a API REST (não conexão direta ao PostgreSQL), apenas a **URL da API** é necessária.

## 3. Salvar e Testar
1. Toque em **"Salvar Configurações"**
2. Volte para a tela principal
3. Toque em **"Entrar"** ou **"Registrar"** para testar a autenticação

## 4. Verificar Status de Sincronização
Depois de fazer login, o app mostrará:
- ✅ **Último sync**: data/hora da última sincronização
- 🔄 **Sincronizar agora**: botão para forçar sync manual

## Backend Endpoints Disponíveis
- **Health check**: `http://contaslite.hawk.com.br:3000/health`
- **Registro**: `POST /api/auth/register`
- **Login**: `POST /api/auth/login`
- **Refresh Token**: `POST /api/auth/refresh`
- **Logout**: `POST /api/auth/logout`
- **Push (enviar dados)**: `POST /api/sync/push`
- **Pull (receber dados)**: `GET /api/sync/pull?since=<timestamp>`

## Credenciais de Teste
Se você já registrou no PowerShell:
- **Email**: `meuemail@example.com`
- **Senha**: `Senha123!`

## Troubleshooting
### "Erro ao conectar com o servidor"
1. Verifique se a URL está correta: `http://contaslite.hawk.com.br:3000`
2. Teste no navegador: [http://contaslite.hawk.com.br:3000/health](http://contaslite.hawk.com.br:3000/health)
3. Certifique-se de que o PM2 está rodando no servidor: `pm2 status`

### "Credenciais inválidas"
- Use a senha correta (mínimo 8 caracteres, 1 maiúscula, 1 número)
- Ou registre um novo usuário pelo app

### "Sincronização falhou"
1. Verifique se você está logado
2. Verifique conexão de internet
3. Confira os logs do servidor: `pm2 logs contaslite-api`
