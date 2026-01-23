# ✅ GUIA DE VERIFICAÇÃO E TESTES

## 📋 CHECKLIST DE VERIFICAÇÃO PÓS-INSTALAÇÃO

### 1️⃣ Verificação da Estrutura
```bash
# Verifique se todos os arquivos estão presentes
ls -la

# Deve conter:
# - README.md
# - INICIO_RAPIDO.md
# - OTIMIZACOES.md
# - SUMARIO.md
# - pubspec.yaml
# - INSTALAR.bat (Windows)
# - instalar.sh (Linux)
# - lib/ (diretório)
```

### 2️⃣ Verificação das Dependências
```bash
flutter pub get
```

**Resultado esperado:** ✅ Todas as dependências instaladas sem erros

### 3️⃣ Análise do Código
```bash
flutter analyze
```

**Resultado esperado:** ✅ No issues found!

### 4️⃣ Formatação
```bash
flutter format lib/ --set-exit-if-changed
```

**Resultado esperado:** ✅ Código já formatado

---

## 🧪 TESTES FUNCIONAIS

### Teste 1: Inicialização do App
```bash
flutter run -d <sua_plataforma>
```

**Verificar:**
- [ ] App inicia em menos de 1 segundo
- [ ] Tema padrão (claro) carrega corretamente
- [ ] Nenhum erro no console
- [ ] Dashboard vazio aparece

**Status esperado:** ✅ PASSOU

---

### Teste 2: Configurações de Tema

**Passos:**
1. Abrir menu lateral
2. Clicar em "Configurações"
3. Alternar tema claro/escuro
4. Fechar e reabrir o app

**Verificar:**
- [ ] Tema alterna suavemente
- [ ] Tema é salvo (persiste após reiniciar)
- [ ] Cores estão corretas em ambos os temas
- [ ] Textos são legíveis

**Status esperado:** ✅ PASSOU

---

### Teste 3: Configuração de Localização

**Passos:**
1. Abrir "Configurações"
2. Selecionar região "Vale do Paraíba"
3. Selecionar cidade "São José dos Campos"
4. Salvar

**Verificar:**
- [ ] Regiões carregam corretamente
- [ ] Cidades filtram pela região
- [ ] Configuração é salva
- [ ] Notificação de sucesso aparece

**Status esperado:** ✅ PASSOU

---

### Teste 4: Tipos de Conta

**Passos:**
1. Menu lateral > "Tipos de Conta"
2. Clicar no botão "+"
3. Adicionar: "Condomínio"
4. Tentar adicionar "Condomínio" novamente

**Verificar:**
- [ ] Tipo é adicionado com sucesso
- [ ] Duplicatas são impedidas
- [ ] Lista é ordenada alfabeticamente
- [ ] Pode editar tipo existente
- [ ] Pode excluir tipo (se não usado)

**Status esperado:** ✅ PASSOU

---

### Teste 5: Categorias de Despesa

**Passos:**
1. Menu lateral > "Categorias de Despesa"
2. Adicionar: "Alimentação"
3. Adicionar: "Transporte"
4. Adicionar: "Lazer"

**Verificar:**
- [ ] Categorias são adicionadas
- [ ] Lista ordenada alfabeticamente
- [ ] Pode editar categoria
- [ ] Pode excluir categoria (se não usada)

**Status esperado:** ✅ PASSOU

---

### Teste 6: Cadastro de Cartão de Crédito

**Passos:**
1. Menu lateral > "Meus Cartões"
2. Clicar no "+"
3. Preencher:
   - Banco: "Nubank"
   - Dia vencimento: 15
   - Melhor dia compra: 8
   - Limite: 5000
   - Cor: Roxo

**Verificar:**
- [ ] Cartão é cadastrado
- [ ] Validação de campos obrigatórios
- [ ] Cores disponíveis
- [ ] Cartão aparece no dashboard
- [ ] Pode editar cartão
- [ ] Pode excluir cartão (se sem despesas)

**Status esperado:** ✅ PASSOU

---

### Teste 7: Lançamento de Conta Normal

**Passos:**
1. Dashboard > Botão "+"
2. Selecionar tipo "Condomínio"
3. Descrição: "Condomínio Dezembro"
4. Valor: R$ 350,00
5. Vencimento: 10
6. Salvar

**Verificar:**
- [ ] Conta aparece no dashboard
- [ ] Valor formatado corretamente
- [ ] Data de vencimento correta
- [ ] Total do período atualizado

**Status esperado:** ✅ PASSOU

---

### Teste 8: Conta Recorrente

**Passos:**
1. Dashboard > Botão "+"
2. Tipo: "Aluguel"
3. Descrição: "Aluguel Casa"
4. Valor: R$ 1.200,00
5. Vencimento: 5
6. ✅ Marcar "Recorrente"
7. Salvar

**Verificar:**
- [ ] Conta marcada como recorrente
- [ ] Aparece em todos os meses
- [ ] Botão "lançar" 🚀 disponível
- [ ] Ao lançar, cria conta específica
- [ ] Não pode excluir a regra se tem lançamentos

**Status esperado:** ✅ PASSOU

---

### Teste 9: Despesa no Cartão (À Vista)

**Passos:**
1. Dashboard > Card do Nubank > Ícone 🛒
2. Valor: R$ 150,00
3. Parcelas: À Vista
4. Categoria: "Alimentação"
5. Local: "Supermercado"
6. Lançar

**Verificar:**
- [ ] Despesa é adicionada
- [ ] Fatura do cartão atualizada
- [ ] Data calculada corretamente
- [ ] Aparece na lista de despesas do cartão

**Status esperado:** ✅ PASSOU

---

### Teste 10: Despesa Parcelada

**Passos:**
1. Dashboard > Card do Nubank > Ícone 🛒
2. Valor: R$ 1.200,00
3. Parcelas: 12x
4. Categoria: "Lazer"
5. Lançar

**Verificar:**
- [ ] 12 parcelas são criadas
- [ ] Valor de cada: R$ 100,00
- [ ] Distribuídas pelos próximos 12 meses
- [ ] Mesmo purchaseUuid
- [ ] Pode mover série completa
- [ ] Pode excluir série completa

**Status esperado:** ✅ PASSOU

---

### Teste 11: Assinatura/Mensalidade

**Passos:**
1. Dashboard > Card do Nubank > Ícone 🛒
2. Valor: R$ 39,90
3. Parcelas: "Assinatura"
4. Categoria: "Lazer"
5. Obs: "Netflix"
6. Lançar

**Verificar:**
- [ ] Assinatura é criada
- [ ] Aparece todo mês automaticamente
- [ ] Não cria múltiplas entradas
- [ ] Pode excluir assinatura
- [ ] Valor sempre o mesmo

**Status esperado:** ✅ PASSOU

---

### Teste 12: Navegação Entre Meses

**Passos:**
1. Dashboard
2. Clicar na seta ◀️ (mês anterior)
3. Clicar na seta ▶️ (próximo mês)

**Verificar:**
- [ ] Mês muda corretamente
- [ ] Contas do mês são exibidas
- [ ] Recorrentes aparecem em todos os meses
- [ ] Total é recalculado
- [ ] Performance é boa (< 200ms)

**Status esperado:** ✅ PASSOU

---

### Teste 13: Edição de Conta

**Passos:**
1. Clicar no ícone ✏️ de uma conta
2. Alterar descrição
3. Alterar valor
4. Alterar data
5. Salvar

**Verificar:**
- [ ] Alterações são salvas
- [ ] Dashboard atualiza
- [ ] Total recalculado
- [ ] Sem erros

**Status esperado:** ✅ PASSOU

---

### Teste 14: Exclusão de Conta

**Passos:**
1. Clicar no ícone 🗑️ de uma conta
2. Confirmar exclusão

**Verificar:**
- [ ] Diálogo de confirmação aparece
- [ ] Conta é removida
- [ ] Total recalculado
- [ ] Não afeta outras contas

**Status esperado:** ✅ PASSOU

---

### Teste 15: Fatura do Cartão

**Passos:**
1. Dashboard > Card do Nubank > Ícone 📋
2. Visualizar despesas do mês

**Verificar:**
- [ ] Todas as despesas aparecem
- [ ] Total da fatura correto
- [ ] Detalhes de cada compra visíveis
- [ ] Pode editar despesa individual
- [ ] Pode excluir despesa individual

**Status esperado:** ✅ PASSOU

---

## ⚡ TESTES DE PERFORMANCE

### Teste P1: Inicialização

**Método:**
```bash
time flutter run --release
```

**Meta:** < 1 segundo
**Status esperado:** ✅ PASSOU

---

### Teste P2: Carregamento de Dados

**Cenário:** 500+ contas no banco

**Método:** Medir tempo de load no dashboard

**Meta:** < 300ms
**Status esperado:** ✅ PASSOU

---

### Teste P3: Scroll Performance

**Método:** Scrollar lista de 100+ contas

**Verificar:**
- [ ] 60 FPS mantido
- [ ] Sem travamentos
- [ ] Animações suaves

**Status esperado:** ✅ PASSOU

---

## 🐛 TESTES DE CASOS EXTREMOS

### Teste E1: Banco de Dados Vazio

**Verificar:**
- [ ] App não crasha
- [ ] Mensagem apropriada exibida
- [ ] Pode adicionar primeira conta

---

### Teste E2: Valores Muito Grandes

**Cenário:** R$ 999.999.999,99

**Verificar:**
- [ ] Valor aceito
- [ ] Formatação correta
- [ ] Cálculos precisos

---

### Teste E3: Datas Especiais

**Cenários:**
- 29/02 (ano bissexto)
- 31/12 (fim de ano)
- Feriados nacionais

**Verificar:**
- [ ] Datas aceitas
- [ ] Ajustes corretos por feriados

---

### Teste E4: Conexão Perdida

**Verificar:**
- [ ] App funciona offline (é local)
- [ ] Sem erros de rede

---

## 📊 RELATÓRIO DE TESTES

### Modelo de Relatório

```
DATA: ___/___/______
TESTADOR: ___________________
PLATAFORMA: ___________________

TESTES FUNCIONAIS: __/15 PASSARAM
TESTES PERFORMANCE: __/3 PASSARAM
TESTES EXTREMOS: __/4 PASSARAM

TOTAL: __/22 PASSARAM

BUGS ENCONTRADOS:
1. ___________________
2. ___________________
3. ___________________

OBSERVAÇÕES:
_______________________
_______________________
```

---

## 🔧 TROUBLESHOOTING

### Problema: App não inicia
```bash
flutter clean
flutter pub get
flutter run
```

### Problema: Erro de banco
1. Feche o app
2. Delete: `finance_v62.db`
3. Reabra o app

### Problema: Tema não salva
```bash
flutter pub cache repair
flutter pub get
```

### Problema: Performance ruim
1. Verifique número de contas (> 1000?)
2. Execute: `flutter run --release`
3. Considere limpar dados antigos

---

## ✅ CERTIFICAÇÃO

Após completar todos os testes:

```
Certifico que o aplicativo "Contas a Pagar v2.0" 
foi testado e está funcionando conforme esperado.

Assinatura: _____________________
Data: ___/___/______
```

---

**Documento Versão:** 1.0  
**Última Atualização:** Dezembro 2024
