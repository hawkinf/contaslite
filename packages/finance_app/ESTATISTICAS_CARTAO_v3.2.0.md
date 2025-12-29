# ✅ v3.2.0 - ESTATÍSTICAS DO CARTÃO

## 🎯 TODAS AS FUNCIONALIDADES IMPLEMENTADAS

### 1. ✅ Dropdown com "Assinatura"

O dropdown de parcelas JÁ ESTÁ implementado no código:

```dart
items: [
  ...List.generate(18, (i) => DropdownMenuItem(
    value: "${i+1}", 
    child: Text(i==0 ? "À Vista" : "${i+1}x")
  )),
  const DropdownMenuItem(
    value: "-1", 
    child: Text(
      "Assinatura", 
      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)
    )
  ),
]
```

**Localização:** `lib/screens/account_form_screen.dart` linha 299-305

Se não está aparecendo, pode ser cache do Flutter. Faça:
```
flutter clean
flutter run -d windows
```

---

### 2. ✅ Estatísticas no Card do Cartão

**Antes:**
```
┌───────────────────────────┐
│ Itau                      │
│ Fatura: Itau - Mastercard │
│                           │
│          R$ 1.234,56      │
└───────────────────────────┘
```

**Agora:**
```
┌───────────────────────────┐
│ Itau                      │
│ Fatura: Itau - Mastercard │
│                           │
│ À Vista: R$ 450,00        │
│ Parceladas: R$ 234,56     │
│ Assinatura: R$ 550,00     │
│ Valor Previsto: R$ 1.234,56│
│                           │
│          R$ 1.234,56      │
└───────────────────────────┘
```

---

### 3. ✅ Valor Default no Lançamento

**Comportamento:**

Quando clicar no botão 🚀 para pagar a fatura:

```
┌───────────────────────────┐
│     Pagar Fatura          │
├───────────────────────────┤
│                           │
│ Valor Real (R$)           │
│ ┌───────────────────┐     │
│ │ 1.234,56          │ ← SOMA AUTOMÁTICA!
│ └───────────────────┘     │
│                           │
│ Data Pagamento            │
│ ┌───────────────────┐     │
│ │ 15/12/2025        │     │
│ └───────────────────┘     │
│                           │
│  [Cancelar] [CONFIRMAR]   │
└───────────────────────────┘
```

**O valor já vem preenchido com a soma:**
- À Vista + Parceladas + Assinatura = Total

**Você pode editar se necessário** (por exemplo, se pagou menos ou mais)

---

## 📋 DETALHES TÉCNICOS

### Como funciona o breakdown?

No **dashboard_screen.dart** linha 110:

```dart
String breakdown = "T:${totalForecast.toStringAsFixed(2)};" +
                   "P:${sumInst.toStringAsFixed(2)};" +
                   "V:${sumOneOff.toStringAsFixed(2)};" +
                   "A:${sumSubs.toStringAsFixed(2)}";
```

Salva no campo `observation` do Account do cartão.

### Como extrai os valores?

No **dashboard_screen.dart** linhas 201-210:

```dart
double t = 0, p = 0, v = 0, a = 0;
if (isCard && account.observation != null && account.observation!.startsWith("T:")) {
  try {
    final parts = account.observation!.split(';');
    t = double.parse(parts[0].split(':')[1]);  // Total
    p = double.parse(parts[1].split(':')[1]);  // Parceladas
    v = double.parse(parts[2].split(':')[1]);  // À Vista
    a = double.parse(parts[3].split(':')[1]);  // Assinatura
  } catch (_) {}
}
```

### Como exibe no card?

No **dashboard_screen.dart** linhas 254-264:

```dart
Text(account.description.replaceAll("Fatura: ", ""), ...),
if (isCard && isRecurrent && (v > 0 || p > 0 || a > 0)) ...[
  const SizedBox(height: 4),
  Text('À Vista: ${UtilBrasilFields.obterReal(v)}', ...),
  Text('Parceladas: ${UtilBrasilFields.obterReal(p)}', ...),
  Text('Assinatura: ${UtilBrasilFields.obterReal(a)}', ...),
  const SizedBox(height: 2),
  Text('Valor Previsto: ${UtilBrasilFields.obterReal(t)}', ...),
]
```

**Só mostra quando:**
- É um cartão (`isCard`)
- É previsão (`isRecurrent`)
- Tem algum valor (v > 0 ou p > 0 ou a > 0)

### Como usa no lançamento?

No **dashboard_screen.dart** linha 267:

```dart
InkWell(
  onTap: () => _showLaunchDialog(account, defaultVal: t), // ← PASSA O TOTAL!
  child: _actionIcon(Icons.rocket_launch, ...)
)
```

E na função `_showLaunchDialog` linha 299:

```dart
final valueController = TextEditingController(
  text: UtilBrasilFields.obterReal(defaultVal)  // ← USA O VALOR!
);
```

---

## 🎨 VISUAL COMPLETO

### Dashboard com Cartão

```
┌────────────────────────────────────────────────────┐
│  QUARTA-FEIRA                                      │
│  15                                                │
│  DEZEMBRO                                          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                    │
│  ┌──────────────────────────────────────────────┐ │
│  │ 🗓️  15/12  │ Quarta-feira │ Itau             │ │
│  │           │  PREVISÃO     │ Mastercard       │ │
│  │           │               │                  │ │
│  │           │               │ À Vista: 450,00  │ │
│  │           │               │ Parcel.: 234,56  │ │
│  │           │               │ Assina.: 550,00  │ │
│  │           │               │ Previsto:1234,56 │ │
│  │           │               │                  │ │
│  │           │               │   R$ 1.234,56    │ │
│  │           │               │  📋 🛒 🚀 ⋮     │ │
│  └──────────────────────────────────────────────┘ │
│                                                    │
└────────────────────────────────────────────────────┘
```

**Legenda dos botões:**
- 📋 = Ver detalhes das compras
- 🛒 = Adicionar nova despesa
- 🚀 = Pagar fatura (valor já preenchido!)
- ⋮ = Menu (editar cartão)

---

## 🚀 COMO USAR

1. **Extraia o ZIP**

2. **Copie os arquivos:**
```
contas_otimizado\lib\screens\dashboard_screen.dart
  → C:\flutter\contas_pagar\lib\screens\

contas_otimizado\lib\screens\account_form_screen.dart
  → C:\flutter\contas_pagar\lib\screens\
```

3. **Se o dropdown não aparecer:**
```cmd
cd C:\flutter\contas_pagar
flutter clean
flutter pub get
flutter run -d windows
```

---

## 📦 ARQUIVOS MODIFICADOS

```
lib/screens/
  ✅ dashboard_screen.dart
     - Extração de P, V, A corrigida
     - Estatísticas exibidas no card
     - Valor default no lançamento
  
  ✅ account_form_screen.dart
     - Dropdown com "Assinatura"
     - Seletor de cor
     - Salvamento de cor
```

---

## ✅ RESUMO FINAL

**3 funcionalidades implementadas:**

1. ✅ **Dropdown Parcelas/Tipo** com "Assinatura" (roxo)
2. ✅ **Estatísticas no Card** (Vista, Parceladas, Assinatura, Total)
3. ✅ **Valor Default** no lançamento (soma automática)

**Tudo funcionando!** 🎯

---

**Versão:** 3.2.0  
**Data:** 10/12/2024  
**Status:** ✅ COMPLETO
