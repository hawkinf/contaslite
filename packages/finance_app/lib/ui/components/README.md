# FácilFin Design System (FF*)

Sistema de design unificado para o FácilFin. Todos os novos componentes devem usar exclusivamente widgets FF* e tokens do tema.

## Instalação

```dart
import 'package:finance_app/ui/components/ff_design_system.dart';
```

Este import único dá acesso a todos os componentes FF*.

---

## Tokens do Tema

### AppRadius
Raios de borda padronizados:

| Token | Valor | Uso |
|-------|-------|-----|
| `AppRadius.sm` | 8 | Badges, chips, inputs |
| `AppRadius.md` | 12 | Botões, containers pequenos |
| `AppRadius.lg` | 16 | Cards, modais (padrão) |
| `AppRadius.xl` | 20 | Cards destacados |
| `AppRadius.xxl` | 24 | Containers especiais |

```dart
// ❌ Evitar
BorderRadius.circular(16)

// ✅ Preferir
BorderRadius.circular(AppRadius.lg)
```

### AppSpacing
Espaçamentos padronizados:

| Token | Valor | Uso |
|-------|-------|-----|
| `AppSpacing.xs` | 4 | Micro espaçamentos |
| `AppSpacing.sm` | 8 | Entre elementos relacionados |
| `AppSpacing.md` | 12 | Padding de botões, badges |
| `AppSpacing.lg` | 16 | Padding de cards (padrão) |
| `AppSpacing.xl` | 24 | Entre seções |
| `AppSpacing.xxl` | 32 | Separação de grupos |

```dart
// ❌ Evitar
EdgeInsets.all(16)
SizedBox(height: 32)

// ✅ Preferir
EdgeInsets.all(AppSpacing.lg)
SizedBox(height: AppSpacing.xxl)
```

### AppColors
Cores semânticas:

| Token | Uso |
|-------|-----|
| `AppColors.success` | Valores positivos, confirmações |
| `AppColors.error` | Erros, valores negativos, ações destrutivas |
| `AppColors.border` | Bordas de cards (modo claro) |

```dart
// ❌ Evitar
Color(0xFF16A34A)
Colors.red

// ✅ Preferir
AppColors.success
AppColors.error
```

---

## Componentes FF*

### Layout

#### FFScreenScaffold
Scaffold padrão com AppBar, padding e scroll automáticos.

```dart
FFScreenScaffold(
  title: 'Título da Tela',
  appBarActions: [...],
  child: Column(...),
)
```

**Quando usar:** Sempre que criar uma nova tela completa.

#### FFAppBar
AppBar padronizada (título centralizado, elevation 0).

```dart
FFAppBar(
  title: 'Título',
  actions: [...],
)
```

**Quando usar:** Quando precisar de AppBar customizada fora do FFScreenScaffold.

#### FFSection
Agrupa conteúdo com título de seção.

```dart
FFSection(
  title: 'Configurações',  // Será uppercase automaticamente
  icon: Icons.settings,
  subtitle: 'Descrição opcional',
  child: Column(...),
)
```

**Quando usar:** Para organizar conteúdo em grupos lógicos com títulos.

---

### Cards

#### FFCard
Container base com estilo premium.

```dart
FFCard(
  child: Text('Conteúdo'),
  onTap: () => print('Clicado'),  // Opcional
)
```

**Quando usar:** Container genérico para qualquer conteúdo.

**Características:**
- Radius: lg (16)
- Padding: lg (16)
- Borda: 1px
- Sombra: suave (apenas modo claro)

#### FFInfoCard
Card informativo com layout horizontal.

```dart
FFInfoCard(
  leading: FFInfoCardLeading(child: Icon(...)),
  title: 'Título',
  subtitle: 'Subtítulo',
  secondarySubtitle: 'Info adicional',
)

// Factory para "Sobre o App"
FFInfoCard.about(
  logo: FFInfoCardLeading(child: Image.asset('...')),
  appName: 'FácilFin',
  version: 'v1.0.0',
  developer: 'Nome',
)
```

**Quando usar:** Exibir informações com ícone/logo + textos.

#### FFActionCard
Card clicável com chevron de navegação.

```dart
FFActionCard(
  icon: Icons.settings,
  iconColor: AppColors.success,  // Opcional
  title: 'Configurações',
  subtitle: 'Descrição da ação',
  onTap: () => Navigator.push(...),
)
```

**Quando usar:** Navegação para outras telas ou ações.

---

### Settings

#### FFSettingsTile
Tile individual para configurações.

```dart
FFSettingsTile(
  icon: Icons.notifications,
  title: 'Notificações',
  subtitle: 'Ativar alertas',
  onTap: () => ...,
)
```

#### FFSettingsSwitchTile
Tile com Switch para preferências booleanas.

```dart
FFSettingsSwitchTile(
  icon: Icons.dark_mode,
  title: 'Modo Escuro',
  subtitle: 'Usar tema escuro',
  value: isDarkMode,
  onChanged: (value) => setState(() => isDarkMode = value),
)
```

#### FFSettingsDropdownTile
Tile com Dropdown para seleção.

```dart
FFSettingsDropdownTile<String>(
  icon: Icons.language,
  title: 'Idioma',
  value: selectedLanguage,
  items: [
    DropdownMenuItem(value: 'pt', child: Text('Português')),
    DropdownMenuItem(value: 'en', child: Text('English')),
  ],
  onChanged: (value) => ...,
)
```

#### FFSettingsGroup
Agrupa múltiplos tiles em um card único.

```dart
FFSettingsGroup(
  tiles: [
    FFSettingsTile(icon: Icons.person, title: 'Perfil', onTap: () {}),
    FFSettingsTile(icon: Icons.security, title: 'Segurança', onTap: () {}),
    FFSettingsTile(icon: Icons.help, title: 'Ajuda', onTap: () {}),
  ],
)
```

**Quando usar:** Agrupar configurações relacionadas.

---

### Buttons

#### FFPrimaryButton
Botão principal (ação primária).

```dart
FFPrimaryButton(
  label: 'Salvar',
  icon: Icons.save,
  onPressed: () => ...,
  isLoading: isSaving,
)

// Variante danger
FFPrimaryButton.danger(
  label: 'Excluir',
  icon: Icons.delete,
  onPressed: () => ...,
)
```

**Quando usar:** Ação principal da tela (salvar, confirmar, enviar).

#### FFSecondaryButton
Botão secundário (outlined ou tonal).

```dart
FFSecondaryButton(
  label: 'Cancelar',
  onPressed: () => Navigator.pop(context),
)

// Variante tonal
FFSecondaryButton(
  label: 'Editar',
  tonal: true,
  onPressed: () => ...,
)
```

**Quando usar:** Ações secundárias, cancelar, voltar.

#### FFIconActionButton
Botão de ícone circular com tooltip.

```dart
FFIconActionButton(
  icon: Icons.edit,
  tooltip: 'Editar',  // Obrigatório!
  onPressed: () => ...,
)

// Variantes
FFIconActionButton.danger(icon: Icons.delete, tooltip: 'Excluir', ...)
FFIconActionButton.success(icon: Icons.check, tooltip: 'Confirmar', ...)
```

**Quando usar:** Ações rápidas em listas, headers, cards.

---

### Badges

#### FFBadge
Indicador de status.

```dart
FFBadge(
  label: 'Ativo',
  type: FFBadgeType.success,
  icon: Icons.check,
)

// Tipos disponíveis:
// FFBadgeType.success  - verde
// FFBadgeType.error    - vermelho
// FFBadgeType.warning  - amarelo
// FFBadgeType.info     - azul (primary)
// FFBadgeType.neutral  - cinza
```

#### FFBadge.syncStatus
Badge específico para status de sincronização.

```dart
FFBadge.syncStatus(
  label: 'Sincronizado',
  isSynced: true,
)
```

---

### Typography

#### FFMoneyText
Exibe valores monetários formatados.

```dart
FFMoneyText(value: 1500.00)  // Colorido por sinal

// Factories
FFMoneyText.income(value: 1500.00)   // Sempre verde
FFMoneyText.expense(value: -750.50)  // Sempre vermelho
FFMoneyText.neutral(value: 0.00)     // Cor do tema

// Ocultar valor
FFMoneyText(value: 999.99, hidden: true)  // R$ ••••••
```

---

## Regras de Migração

### Widgets Proibidos (uso direto)
| Antes | Depois |
|-------|--------|
| `Card` | `FFCard` |
| `ListTile` | `FFSettingsTile` ou `FFActionCard` |
| `ElevatedButton` | `FFPrimaryButton` |
| `OutlinedButton` | `FFSecondaryButton` |
| `IconButton` | `FFIconActionButton` |

### Valores para Migrar

```dart
// BorderRadius
BorderRadius.circular(8)  → BorderRadius.circular(AppRadius.sm)
BorderRadius.circular(12) → BorderRadius.circular(AppRadius.md)
BorderRadius.circular(16) → BorderRadius.circular(AppRadius.lg)
BorderRadius.circular(20) → BorderRadius.circular(AppRadius.xl)
BorderRadius.circular(24) → BorderRadius.circular(AppRadius.xxl)

// EdgeInsets
EdgeInsets.all(8)  → EdgeInsets.all(AppSpacing.sm)
EdgeInsets.all(12) → EdgeInsets.all(AppSpacing.md)
EdgeInsets.all(16) → EdgeInsets.all(AppSpacing.lg)
EdgeInsets.all(24) → EdgeInsets.all(AppSpacing.xl)
EdgeInsets.all(32) → EdgeInsets.all(AppSpacing.xxl)

// SizedBox
SizedBox(height: 8)  → SizedBox(height: AppSpacing.sm)
SizedBox(height: 16) → SizedBox(height: AppSpacing.lg)
SizedBox(height: 32) → SizedBox(height: AppSpacing.xxl)

// Cores
Color(0xFF16A34A) → AppColors.success
Color(0xFFDC2626) → AppColors.error
```

---

## Preview do Design System

Para visualizar todos os componentes:

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const DesignSystemPreview()),
);
```

Arquivo: `lib/screens/design_system_preview.dart`

---

## Checklist para Novas Telas

- [ ] Usar `FFScreenScaffold` como wrapper
- [ ] Usar `FFSection` para agrupar conteúdo
- [ ] Usar `FFCard` para containers
- [ ] Usar `FFPrimaryButton`/`FFSecondaryButton` para botões
- [ ] Usar `FFBadge` para status
- [ ] Usar `FFMoneyText` para valores monetários
- [ ] Usar `AppRadius.*` para todos os borderRadius
- [ ] Usar `AppSpacing.*` para todos os paddings/margins
- [ ] Usar `AppColors.*` para cores semânticas
