Resumo das mudanças (branch `recupera-inicial`)

Principais pontos:

- Correções de comportamento de contas recorrentes:
  - Ajustes na remoção e salvamento de recorrências.
  - Exibição de diálogo de confirmação ao excluir recorrências.
  - Ao editar recorrência: opções de escopo de salvamento (3 opções) e não propagar `valor lançado`.
  - Navegação por mês desabilitada durante edição de recorrência.

- Preferência de backup ao iniciar:
  - Adicionada preferência "Perguntar backup ao iniciar" e obedecida na inicialização do app.

- Limpeza do histórico Git:
  - Removida a pasta `.snapshots` do histórico (files grandes), reflog expirado e `git gc` rodado.
  - Branch `recupera-inicial` foi forçada para o remoto após limpeza.

- Ajustes de UI solicitados:
  - Removidas barras decorativas laterais em diversas telas (cards/listas).
  - Removida coloração de cabeçalho de algumas `DataTable`.
  - `Tipo` em `Payment Methods` convertido para um `Dropdown` com opções padrão.

Status atual:

- `flutter analyze`: passou com 2 avisos (um `unused_local_variable` e um `deprecated_member_use` aviso). Veja saída completa no console.
- `flutter test`: todos os testes passaram.
- Branch remoto `recupera-inicial` está atualizado (push forçado após remoção de snapshots).
- Arquivo desta descrição criado em `PR_DESCRIPTION_recupera-inicial.md`.

Como criar o PR (local):

Se tiver o GitHub CLI (`gh`) instalado, rode:

```bash
# autentique se necessário
gh pr create --base main --head recupera-inicial --title "recupera-inicial: correções recorrentes, backup e UI" --body-file PR_DESCRIPTION_recupera-inicial.md --draft
```

Ou crie manualmente via web no repositório `hawkinf/contaslite` selecionando a branch `recupera-inicial` e abrindo um PR contra `main`.

Observações/Próximos passos sugeridos:

- Deseja que eu remova também as linhas separadoras finas (ex.: `Container(width: 1, ...)`) encontradas em `dashboard_screen.dart` e outras telas? Algumas são separadores funcionais — confirme se quer apagá-las.
- Posso abrir o PR automaticamente se você instalar/autorizar `gh` ou posso gerar o comando que você executa localmente.

---
(Automated summary gerado pelo assistente)