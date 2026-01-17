# Configuração do Google Sign-In para ContasLite

Este documento descreve como configurar a autenticação com Google para o aplicativo ContasLite.

## 1. Configuração no Google Cloud Console

### 1.1. Criar um Projeto

1. Acesse [Google Cloud Console](https://console.cloud.google.com/)
2. Crie um novo projeto ou selecione um existente
3. Anote o **Project ID**

### 1.2. Configurar a Tela de Consentimento OAuth

1. Vá para **APIs & Services** > **OAuth consent screen**
2. Escolha **External** (para usuários fora da organização)
3. Preencha:
   - **App name**: ContasLite
   - **User support email**: seu email
   - **Developer contact**: seu email
4. Em **Scopes**, adicione:
   - `email`
   - `profile`
   - `openid`
5. Salve e continue

### 1.3. Criar Credenciais OAuth 2.0

Vá para **APIs & Services** > **Credentials** > **Create Credentials** > **OAuth client ID**

#### Para Android:

1. Tipo: **Android**
2. Nome: `ContasLite Android`
3. **Package name**: `com.hawk.contaslite` (verifique em `android/app/build.gradle`)
4. **SHA-1 certificate fingerprint**:
   ```bash
   # Debug (desenvolvimento)
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

   # Release (produção)
   keytool -list -v -keystore your-release-key.keystore -alias your-alias
   ```
5. Anote o **Client ID** gerado

#### Para Web:

1. Tipo: **Web application**
2. Nome: `ContasLite Web`
3. **Authorized JavaScript origins**:
   - `http://localhost:8080` (desenvolvimento)
   - `https://contaslite.hawk.com.br` (produção)
4. **Authorized redirect URIs**:
   - `http://localhost:8080`
   - `https://contaslite.hawk.com.br`
5. Anote o **Client ID** gerado (será usado no Flutter Web e no Backend)

#### Para Windows/Desktop:

1. Use as mesmas credenciais **Web** para desktop
2. O Flutter google_sign_in usa OAuth web flow para desktop

## 2. Configuração no Backend (VPS)

### 2.1. Atualizar variáveis de ambiente

Edite o arquivo `.env` na VPS:

```bash
# Google OAuth
GOOGLE_CLIENT_ID=SEU_WEB_CLIENT_ID.apps.googleusercontent.com
```

### 2.2. Executar migração do banco

```bash
cd /path/to/backend
node scripts/migrate.js --file 006_add_google_auth_fields.sql
```

Ou execute manualmente:
```sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS google_id VARCHAR(255) UNIQUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS photo_url VARCHAR(500);
ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_google_id ON users(google_id);
```

### 2.3. Instalar dependências

```bash
npm install
```

### 2.4. Reiniciar o servidor

```bash
pm2 restart contaslite-backend
# ou
systemctl restart contaslite
```

## 3. Configuração no Flutter

### 3.1. Android

Edite `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        // ...
        manifestPlaceholders = [
            'appAuthRedirectScheme': 'com.hawk.contaslite'
        ]
    }
}
```

Nenhuma configuração adicional é necessária para Android. O `google_sign_in` usa automaticamente as credenciais do projeto.

### 3.2. Windows

Para Windows, o Google Sign-In usa o fluxo OAuth web. O Client ID web deve ser passado na inicialização:

```dart
await GoogleAuthService.instance.initialize(
  webClientId: 'SEU_WEB_CLIENT_ID.apps.googleusercontent.com',
);
```

### 3.3. Web

Adicione no `web/index.html` antes do `</head>`:

```html
<meta name="google-signin-client_id" content="SEU_WEB_CLIENT_ID.apps.googleusercontent.com">
```

## 4. Testando a Integração

### 4.1. Teste Local

1. Execute o app:
   ```bash
   flutter run -d windows
   ```

2. Clique em "Continuar com Google"

3. Uma janela do navegador abrirá para autenticação

4. Após autorizar, você será redirecionado de volta ao app

### 4.2. Verificar no Backend

Verifique os logs do servidor:
```bash
pm2 logs contaslite-backend
```

Você deve ver:
```
User logged in via Google: <user_id> - <email>
```

### 4.3. Verificar no Banco de Dados

```sql
SELECT id, email, name, google_id, photo_url
FROM users
WHERE google_id IS NOT NULL;
```

## 5. Troubleshooting

### Erro: "Token do Google inválido"

- Verifique se o `GOOGLE_CLIENT_ID` no backend corresponde ao Client ID usado no Flutter
- Verifique se o token não expirou (tokens do Google expiram em ~1 hora)

### Erro: "popup_closed_by_user"

- O usuário fechou a janela de login do Google antes de concluir
- Isso é tratado como cancelamento, não como erro

### Erro no Android: "DEVELOPER_ERROR"

- Verifique se o SHA-1 configurado no Google Console corresponde ao app
- Para debug, use o SHA-1 do debug keystore
- Para release, use o SHA-1 do release keystore

### Erro no Windows: "access_denied"

- Verifique se as origens JavaScript autorizadas incluem `http://localhost`
- Verifique se o Client ID é do tipo **Web application**

## 6. Segurança

### Boas Práticas

1. **Nunca** exponha o Client Secret no código do cliente
2. Use variáveis de ambiente para armazenar o Client ID no backend
3. Valide sempre o token do Google no backend antes de criar sessão
4. Use HTTPS em produção

### Verificação de Token

O backend valida o token do Google usando a biblioteca `google-auth-library`:

```javascript
const ticket = await googleClient.verifyIdToken({
  idToken: idToken,
  audience: process.env.GOOGLE_CLIENT_ID
});
```

Isso garante que:
- O token foi emitido pelo Google
- O token não foi modificado
- O token é para o seu aplicativo (audience)
- O token não expirou
