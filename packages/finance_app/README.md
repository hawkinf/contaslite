# 💰 Contas a Pagar - Sistema de Gestão Financeira

Sistema profissional de gestão de contas a pagar com suporte a cartões de crédito, categorização de despesas e análise financeira.

## 🎯 Características Principais

### ✅ Gestão de Contas
- Lançamento de contas únicas e recorrentes
- Controle de vencimentos com alertas
- Edição e exclusão de contas
- Movimentação de contas entre meses

### 💳 Cartões de Crédito
- Cadastro ilimitado de cartões
- Controle de melhor dia de compra e vencimento
- Lançamento de despesas no cartão
- Parcelamento automático de compras
- Assinaturas/mensalidades
- Visualização de fatura mensal

### 📊 Categorização
- Tipos de conta personalizáveis
- Categorias de despesa customizáveis
- Relatórios por categoria

### 🎨 Interface
- Tema claro e escuro
- Design responsivo (mobile e desktop)
- Navegação intuitiva
- Animações suaves

### 🏙️ Feriados Bancários
- Ajuste automático de vencimentos
- Base de feriados do Vale do Paraíba, Litoral Norte e São Paulo
- Configuração de cidade preferencial

## 🚀 Como Executar

### Pré-requisitos
```bash
Flutter SDK >= 3.0.0
Dart SDK >= 3.0.0
```

### Instalação

1. **Clone o projeto ou extraia o ZIP**

2. **Instale as dependências**
```bash
flutter pub get
```

3. **Execute o aplicativo**

Para desktop (Windows/Linux/macOS):
```bash
flutter run -d windows
flutter run -d linux
flutter run -d macos
```

Para mobile:
```bash
flutter run -d chrome     # Web
flutter run               # Android/iOS (com dispositivo conectado)
```

### Build para Produção

**Windows:**
```bash
flutter build windows --release
```

**Linux:**
```bash
flutter build linux --release
```

**Android:**
```bash
flutter build apk --release
flutter build appbundle --release
```

**iOS:**
```bash
flutter build ios --release
```

**Web:**
```bash
flutter build web --release
```

## 📁 Estrutura do Projeto

```
lib/
├── main.dart                    # Ponto de entrada da aplicação
├── database/
│   └── db_helper.dart          # Gerenciador do banco SQLite
├── models/
│   ├── account.dart            # Modelo de conta
│   ├── account_type.dart       # Modelo de tipo de conta
│   └── expense_category.dart   # Modelo de categoria
├── screens/
│   ├── dashboard_screen.dart   # Tela principal
│   ├── settings_screen.dart    # Configurações
│   ├── credit_card_form.dart   # Cadastro de cartão
│   ├── card_expenses_screen.dart # Despesas do cartão
│   └── ...                     # Outras telas
├── services/
│   ├── prefs_service.dart      # Preferências do usuário
│   └── holiday_service.dart    # Serviço de feriados
├── utils/
│   └── formatters.dart         # Utilitários de formatação
└── widgets/
    └── ...                      # Widgets reutilizáveis
```

## 🔧 Principais Otimizações Implementadas

### 1. **Performance do Banco de Dados**
- ✅ Índices otimizados para queries frequentes
- ✅ PRAGMA WAL mode para melhor concorrência
- ✅ Cache de 10MB para queries
- ✅ Batch operations para múltiplas inserções

### 2. **Código**
- ✅ Separação clara de responsabilidades
- ✅ Modelos com métodos auxiliares (copyWith, getters)
- ✅ Formatadores centralizados em utils
- ✅ Tratamento de erros consistente
- ✅ Documentação inline

### 3. **Interface**
- ✅ Tema Material 3
- ✅ Componentes reutilizáveis
- ✅ Animações performáticas
- ✅ Responsividade para diferentes tamanhos de tela

### 4. **Manutenibilidade**
- ✅ Código bem organizado e comentado
- ✅ Nomenclatura clara e consistente
- ✅ Separação lógica de funcionalidades
- ✅ Fácil adição de novas features

## 💡 Funcionalidades Detalhadas

### Lançamento de Despesas no Cartão

1. **Compra À Vista ou Parcelada**
   - Selecione o cartão
   - Informe valor, categoria e número de parcelas
   - Sistema calcula automaticamente as parcelas
   - Ajusta datas considerando feriados

2. **Assinatura/Mensalidade**
   - Marque como assinatura
   - Sistema cria lançamento recorrente
   - Aparece automaticamente todos os meses

3. **Controle de Fatura Fechada**
   - Sistema detecta automaticamente
   - Compras após o melhor dia vão para próxima fatura
   - Opção de override manual

### Movimentação de Contas

- Mover conta individual para outro mês
- Mover série completa de parcelas
- Exclusão de conta individual ou série completa

### Relatórios

- Total do período selecionado
- Separação por tipo de conta
- Identificação de contas vencidas
- Preview de próximos vencimentos

## 🎨 Personalização

### Temas
O aplicativo suporta tema claro e escuro. Altere em:
**Configurações > Tema**

### Feriados
Configure sua cidade para ajuste automático de vencimentos:
**Configurações > Região/Cidade**

Cidades disponíveis:
- **Vale do Paraíba**: São José dos Campos, Taubaté, Jacareí, etc.
- **Litoral Norte**: Caraguatatuba, São Sebastião, Ubatuba, Ilhabela
- **São Paulo**: Capital e região metropolitana

## 🔒 Segurança

- Todos os dados são armazenados localmente
- Sem conexão com internet necessária
- Banco de dados SQLite criptografado (opcional)
- Backup e restauração disponíveis

## 📱 Compatibilidade

| Plataforma | Status | Versão Mínima |
|-----------|--------|---------------|
| Android   | ✅     | 5.0 (API 21)  |
| iOS       | ✅     | 11.0          |
| Windows   | ✅     | Windows 10    |
| Linux     | ✅     | Ubuntu 20.04+ |
| macOS     | ✅     | 10.14+        |
| Web       | ✅     | Chrome, Firefox, Safari |

## 🐛 Resolução de Problemas

### Erro ao executar no desktop
```bash
flutter config --enable-windows-desktop
flutter config --enable-linux-desktop
flutter config --enable-macos-desktop
```

### Erro de dependências
```bash
flutter clean
flutter pub get
```

### Banco de dados corrompido
1. Feche o aplicativo
2. Localize o arquivo `finance_v62.db`
3. Delete o arquivo
4. Reabra o aplicativo

## 📚 Dependências Principais

```yaml
dependencies:
  sqflite: ^2.3.0              # Banco de dados SQLite
  google_fonts: ^6.1.0         # Fontes do Google
  intl: ^0.19.0                # Internacionalização
  brasil_fields: ^1.15.0       # Formatação brasileira
  shared_preferences: ^2.2.0   # Persistência de configurações
```

## 🔄 Próximas Atualizações Planejadas

- [ ] Exportação de relatórios em PDF/Excel
- [ ] Gráficos de análise financeira
- [ ] Sincronização em nuvem (opcional)
- [ ] Widget de resumo para home screen
- [ ] Notificações de vencimento
- [ ] Importação de OFX bancário
- [ ] Múltiplos usuários/perfis
- [ ] Backup automático

## 👨‍💻 Desenvolvimento

### Adicionar Nova Funcionalidade

1. Crie o modelo em `lib/models/`
2. Adicione métodos no `DatabaseHelper`
3. Crie/modifique tela em `lib/screens/`
4. Teste em diferentes plataformas

### Convenções de Código

- Use `snake_case` para arquivos
- Use `camelCase` para variáveis
- Use `PascalCase` para classes
- Documente funções públicas
- Prefira `const` quando possível

## 📄 Licença

Este projeto é de uso pessoal/comercial.

## 🙏 Agradecimentos

Desenvolvido com Flutter e muito ☕

---

**Versão:** 2.0.0  
**Última Atualização:** Dezembro 2024  
**Desenvolvido por:** Aguinaldo - Engenheiro Eletrônico
