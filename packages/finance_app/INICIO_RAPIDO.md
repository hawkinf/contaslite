# 🚀 GUIA DE INÍCIO RÁPIDO

## ⚡ Instalação em 3 Passos

### Windows

1. **Extraia o projeto**
2. **Execute o instalador**
   ```
   Clique duas vezes em: INSTALAR.bat
   ```
3. **Escolha a opção desejada**
   - `1` para executar em modo desenvolvimento
   - `2` para compilar versão final

### Linux

1. **Extraia o projeto**
2. **Execute o instalador**
   ```bash
   chmod +x instalar.sh
   ./instalar.sh
   ```
3. **Escolha a opção desejada**

### Manual (Qualquer Plataforma)

```bash
# 1. Instale as dependências
flutter pub get

# 2. Execute o app
flutter run -d <plataforma>

# Plataformas disponíveis:
# - windows
# - linux
# - macos
# - chrome (web)
# - android
# - ios
```

---

## 📱 Primeiros Passos no App

### 1️⃣ Configure o Tema
- Menu lateral > **Configurações**
- Escolha entre tema Claro ou Escuro

### 2️⃣ Configure sua Cidade
- Menu lateral > **Configurações**
- Selecione sua região e cidade
- Isso ajusta automaticamente os feriados bancários

### 3️⃣ Crie Tipos de Conta
- Menu lateral > **Tipos de Conta**
- Adicione: Aluguel, Condomínio, Água, Luz, etc.

### 4️⃣ Crie Categorias de Despesa
- Menu lateral > **Categorias de Despesa**
- Adicione: Alimentação, Transporte, Lazer, etc.

### 5️⃣ Cadastre seus Cartões de Crédito
- Menu lateral > **Meus Cartões**
- Clique no `+` para adicionar
- Preencha:
  - Banco/Nome do cartão
  - Dia de vencimento
  - Melhor dia de compra
  - Limite (opcional)
  - Cor para identificação

### 6️⃣ Lance uma Conta
- Tela principal > Botão `+`
- Escolha o tipo
- Preencha os dados
- Marque se é recorrente (fixa todo mês)

### 7️⃣ Lance uma Despesa no Cartão
- Tela principal > Card do cartão > Ícone carrinho 🛒
- Preencha:
  - Valor
  - Número de parcelas (ou "Assinatura")
  - Categoria
  - Local (opcional)
  - Observações (opcional)

---

## 💡 Dicas Importantes

### ✅ Contas Recorrentes
Marque como recorrente contas que se repetem todo mês (aluguel, condomínio, etc).
Elas aparecem automaticamente e você só precisa "lançar" o pagamento.

### 💳 Melhor Dia de Compra
Configure corretamente o melhor dia de compra do cartão.
Compras após esse dia caem na fatura do mês seguinte.

### 📅 Feriados Bancários
O sistema ajusta automaticamente vencimentos que caem em feriados/fins de semana
para o próximo dia útil.

### 🔢 Parcelamento
Ao parcelar uma compra, o sistema:
- Divide o valor automaticamente
- Distribui pelas próximas faturas
- Ajusta datas por feriados
- Permite mover toda a série de uma vez

### 🔁 Assinaturas
Marque despesas recorrentes de cartão como "Assinatura".
Elas aparecem automaticamente todos os meses na fatura.

---

## 🎯 Funcionalidades Principais

| Ação | Como Fazer |
|------|------------|
| Nova conta | Tela principal > Botão `+` |
| Editar conta | Clique no ícone ✏️ na conta |
| Excluir conta | Clique no ícone 🗑️ na conta |
| Mover conta para outro mês | Menu ⋮ > Mover |
| Lançar fatura de cartão | Ícone 🚀 no card do cartão |
| Ver despesas do cartão | Ícone 📋 no card do cartão |
| Adicionar despesa no cartão | Ícone 🛒 no card do cartão |
| Mudar mês visualizado | Setas ◀️ ▶️ no topo |

---

## 🔧 Solução de Problemas

### App não inicia
```bash
flutter clean
flutter pub get
flutter run
```

### Banco de dados corrompido
1. Feche o app
2. Localize e delete: `finance_v62.db`
3. Reabra o app (cria novo banco)

### Erro de dependências
```bash
flutter pub upgrade --major-versions
```

### Erro no Windows
```bash
flutter config --enable-windows-desktop
flutter doctor
```

---

## 📊 Visualizando suas Finanças

### Dashboard Principal
- **Total do Período**: Soma de todas as contas do mês
- **Cartões Amarelos**: Faturas recorrentes (fixas)
- **Cartões Brancos/Cinza**: Faturas com despesas lançadas
- **Contas em Vermelho**: Vencidas ou próximas do vencimento

### Fatura do Cartão
- Acesse pelo ícone 📋
- Veja todas as despesas do mês
- Total da fatura
- Detalhes de cada compra

---

## 🎨 Personalizando

### Cores dos Cartões
Ao cadastrar um cartão, escolha uma cor.
Isso facilita identificação visual rápida.

### Temas
Experimente o tema escuro para:
- Economizar bateria (telas OLED)
- Reduzir cansaço visual noturno
- Visual mais moderno

---

## 💾 Backup (Importante!)

### Localização do Banco de Dados

**Windows:**
```
C:\Users\[SeuUsuario]\AppData\Roaming\finance_app\finance_v62.db
```

**Linux:**
```
~/.local/share/finance_app/finance_v62.db
```

**Android:**
```
/data/data/com.example.finance_app/databases/finance_v62.db
```

### Como Fazer Backup
1. Feche o aplicativo
2. Copie o arquivo `finance_v62.db`
3. Guarde em local seguro (nuvem, pendrive)

### Como Restaurar
1. Feche o aplicativo
2. Substitua o arquivo atual pelo backup
3. Reabra o aplicativo

---

## 🆘 Precisa de Ajuda?

1. Consulte o **README.md** completo
2. Leia o **OTIMIZACOES.md** para detalhes técnicos
3. Verifique os comentários no código-fonte

---

**Versão:** 2.0.0  
**Última Atualização:** Dezembro 2024

**Bom uso! 💰✅**
