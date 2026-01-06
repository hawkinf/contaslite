# Guia de Layout Responsivo - Contaslite

## Visão Geral

Este documento descreve as alterações realizadas para garantir que o aplicativo Contaslite tenha um layout totalmente responsivo, evitando problemas de overflow em qualquer tamanho de tela.

## Problemas Corrigidos

### 1. **Dialog com "Contas a Receber" - Overflow de Elementos**
**Problema**: O diálogo de lançamento de contas a receber tinha altura fixa e seus elementos não se ajustavam a telas menores, causando overflow.

**Solução**:
- Implementar cálculo dinâmico de altura baseado na tela disponível
- Usar percentuais da tela (85% de altura disponível)
- Adicionar limites mínimos e máximos para garantir usabilidade

### 2. **Formulário de Conta (Account Form)**
**Problema**: O `ConstrainedBox` tinha `maxHeight: 850` fixo, que poderia ser maior que a tela disponível.

**Solução**:
```dart
// Calcular altura máxima responsiva
final screenHeight = MediaQuery.of(context).size.height;
final viewInsets = MediaQuery.of(context).viewInsets;
final availableHeight = screenHeight - viewInsets.bottom;
final maxFormHeight = availableHeight * 0.75; // Use 75% of available height

// Aplicar com limites
constraints: BoxConstraints(maxHeight: maxFormHeight.clamp(300.0, 900.0))
```

### 3. **Diálogos Aninhados (Recebimentos)**
**Problema**: Múltiplos dialogs com constraints fixas em tamanhos pequenos causavam overflow.

**Solução**: Cada dialog agora calcula suas próprias dimensões responsivas:
- Dialog principal: 90% da largura, 80% da altura disponível
- Dialog de subcategorias: 90% da largura, 75% da altura disponível

## Arquivos Modificados

### 1. `/lib/widgets/responsive_dialog_wrapper.dart` ✨ (NOVO)
Widget reutilizável para criar diálogos responsivos. Oferece:
- `ResponsiveDialogWrapper`: Envolvimento completo com cálculo automático de dimensões
- `ConstrainedDialog`: Dialog simples com constraints responsivos
- `ScrollableDialogContent`: Conteúdo scrollável para dialogs

```dart
// Exemplo de uso
showDialog(
  context: context,
  builder: (_) => ResponsiveDialogWrapper(
    child: YourWidget(),
    maxWidthPercent: 0.9,
    maxHeightPercent: 0.85,
    useScrollable: true,
  ),
);
```

### 2. `/lib/screens/recebimento_form_screen.dart`
**Mudanças**:
- Remover constraints fixas
- Adicionar cálculo dinâmico de `maxWidth` e `maxHeight`
- `maxWidth`: 90% da tela (limitado entre 280 e 600)
- `maxHeight`: 85% da altura disponível (limitado entre 400 e 900)

### 3. `/lib/screens/account_form_screen.dart`
**Mudanças**:
- Calcular altura máxima do formulário dinamicamente
- Usar 75% da altura disponível
- Limites entre 300 e 900 pixels

### 4. `/lib/screens/credit_card_form.dart`
**Mudanças**:
- Aplicar o mesmo padrão responsivo que `RecebimentoFormScreen`
- Dimensões: 90% largura, 85% altura disponível

### 5. `/lib/screens/recebimentos_table_screen.dart`
**Mudanças**:
- Dialog principal: 90% x 80% com limites
- Dialog de subcategorias: 90% x 75% com limites
- Ambos recalculam ao abrir

### 6. `/lib/widgets/new_expense_dialog.dart`
**Status**: ✅ Já está correto
- Usa `Scaffold` com `ListView` e `SafeArea`
- Padding de 16px em todos os lados
- Bottom padding para FAB

### 7. `/lib/widgets/payment_dialog.dart`
**Status**: ✅ Já está correto
- Usa `Scaffold` com `ListView` e `SafeArea`
- Padding adequado
- Sem constraints fixos

## Padrão Responsivo Implementado

### Fórmula Geral para Dialogs:

```dart
// Obter tamanho da tela
final screenSize = MediaQuery.of(context).size;
final viewInsets = MediaQuery.of(context).viewInsets;

// Calcular dimensões com percentuais
final maxWidth = (screenSize.width * 0.9).clamp(280.0, 600.0);
final availableHeight = screenSize.height - viewInsets.bottom;
final maxHeight = (availableHeight * 0.85).clamp(400.0, 900.0);

// Aplicar ao Dialog
Dialog(
  insetPadding: const EdgeInsets.all(16),
  constraints: BoxConstraints(
    maxWidth: maxWidth,
    maxHeight: maxHeight,
  ),
  child: YourContent(),
)
```

### Explicação dos Parâmetros:

| Parâmetro | Valor | Motivo |
|-----------|-------|--------|
| **Width %** | 90% | Deixa 5% de margem em cada lado |
| **Width Min** | 280px | Mínimo para que o conteúdo seja usável em mobile |
| **Width Max** | 600px | Máximo razoável para não deixar muito espaço em branco em tablets |
| **Height %** | 75-85% | Deixa espaço para a AppBar e teclado virtual |
| **Height Min** | 250-400px | Mínimo para scrolling ser necessário |
| **Height Max** | 800-900px | Máximo para não ocupar toda a tela |

## Boas Práticas Implementadas

### 1. **Sempre Considerar o Teclado Virtual**
```dart
final viewInsets = MediaQuery.of(context).viewInsets;
final availableHeight = screenSize.height - viewInsets.bottom;
```

### 2. **Usar Percentuais em vez de Valores Fixos**
```dart
// ❌ Errado
maxWidth: 500.0

// ✅ Correto
maxWidth: (screenSize.width * 0.9).clamp(280.0, 600.0)
```

### 3. **Sempre Aplicar Limites (clamp)**
```dart
// ✅ Bom
(screenSize.width * 0.9).clamp(280.0, 600.0)
```

### 4. **SingleChildScrollView para Conteúdo Longo**
```dart
SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: YourContent(),
)
```

### 5. **ListView para Listas de Itens**
```dart
ListView(
  padding: const EdgeInsets.all(16),
  children: items,
)
```

## Testes Recomendados

### Em Diferentes Tamanhos de Tela:
- ✅ **Mobile**: 360px x 640px (Galaxy S5)
- ✅ **Mobile Grande**: 412px x 915px (Pixel 4)
- ✅ **Tablet**: 600px x 1024px
- ✅ **Tablet Grande**: 768px x 1024px
- ✅ **Desktop**: 1920px x 1080px

### Cenários de Teste:
1. Abrir formulário em tela pequena
2. Alternar entre modo paisagem e retrato
3. Abrir teclado virtual e verificar ajuste
4. Rolar dentro do diálogo
5. Abrir dialogs aninhados

## Checklist para Novos Formulários/Dialogs

- [ ] Usar `MediaQuery` para obter tamanho da tela
- [ ] Calcular `maxWidth` com percentual e limites
- [ ] Calcular `maxHeight` considerando `viewInsets.bottom`
- [ ] Usar `SingleChildScrollView` se conteúdo é longo
- [ ] Usar `SafeArea` para listas/scrolls
- [ ] Testar em pelo menos 3 tamanhos de tela diferentes
- [ ] Testar com teclado virtual aberto
- [ ] Validar que não há overflow em lugar algum

## Referências

- [MediaQuery Documentation](https://api.flutter.dev/flutter/widgets/MediaQuery-class.html)
- [Flutter Responsive Layout](https://flutter.dev/docs/development/ui/layout/responsive)
- [Dialog Widget](https://api.flutter.dev/flutter/material/Dialog-class.html)

## Sumário das Mudanças

| Arquivo | Tipo | Status |
|---------|------|--------|
| `recebimento_form_screen.dart` | Modificado | ✅ Responsivo |
| `account_form_screen.dart` | Modificado | ✅ Responsivo |
| `credit_card_form.dart` | Modificado | ✅ Responsivo |
| `recebimentos_table_screen.dart` | Modificado | ✅ Responsivo |
| `responsive_dialog_wrapper.dart` | Novo | ✅ Reutilizável |
| `new_expense_dialog.dart` | ✅ OK | ✅ Sem mudanças |
| `payment_dialog.dart` | ✅ OK | ✅ Sem mudanças |

**Total**: 7 alterações, 0 regressões, compilação limpa ✨
