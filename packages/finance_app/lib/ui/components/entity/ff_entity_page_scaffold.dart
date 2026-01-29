import 'package:flutter/material.dart';
import '../../theme/app_radius.dart';
import '../cards/ff_card.dart';
import '../layout/ff_screen_scaffold.dart';
import '../states/ff_empty_state.dart';
import 'ff_entity_density.dart';
import 'ff_entity_actions_bar.dart';

/// Scaffold padrão para páginas de cadastro/entidades do FácilFin.
///
/// Estrutura unificada:
/// - [Header compacto] (opcional)
/// - [Barra de ações] (FFEntityActionsBar)
/// - [Lista/grade de itens] ou [Empty State]
///
/// Exemplo:
/// ```dart
/// FFEntityPageScaffold(
///   title: 'Categorias',
///   primaryAction: FFEntityAction(
///     label: 'Nova Categoria',
///     icon: Icons.add,
///     onPressed: _addCategory,
///   ),
///   isEmpty: _categories.isEmpty,
///   emptyState: FFEmptyState.categorias(onAction: _addCategory),
///   child: _buildCategoriesList(),
/// )
/// ```
class FFEntityPageScaffold extends StatelessWidget {
  /// Título da página (exibido no app bar)
  final String title;

  /// Se deve mostrar o app bar
  final bool showAppBar;

  /// Ação primária (botão principal na barra de ações)
  final FFEntityAction? primaryAction;

  /// Ação secundária (botão secundário na barra de ações)
  final FFEntityAction? secondaryAction;

  /// Widget de busca opcional
  final Widget? searchWidget;

  /// Se a lista está vazia
  final bool isEmpty;

  /// Widget de estado vazio
  final FFEmptyState? emptyState;

  /// Conteúdo principal (lista/grade de itens)
  final Widget child;

  /// Densidade dos componentes
  final FFEntityDensity? density;

  /// Se deve usar scroll view
  final bool useScrollView;

  /// Header customizado (acima da barra de ações)
  final Widget? header;

  /// Se deve mostrar card em volta da lista
  final bool wrapInCard;

  /// Títulos das colunas do header da lista (se aplicável)
  final List<String>? columnHeaders;

  const FFEntityPageScaffold({
    super.key,
    required this.title,
    this.showAppBar = false,
    this.primaryAction,
    this.secondaryAction,
    this.searchWidget,
    this.isEmpty = false,
    this.emptyState,
    required this.child,
    this.density,
    this.useScrollView = false,
    this.header,
    this.wrapInCard = true,
    this.columnHeaders,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveDensity = density ?? FFEntityDensityHelper.fromContext(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget content;

    if (isEmpty && emptyState != null) {
      content = emptyState!;
    } else {
      Widget listContent = child;

      // Adiciona header de colunas se fornecido
      if (columnHeaders != null && columnHeaders!.isNotEmpty) {
        listContent = Column(
          children: [
            _buildColumnHeaders(colorScheme, effectiveDensity),
            Expanded(child: child),
          ],
        );
      }

      // Envolve em card se solicitado
      if (wrapInCard) {
        content = FFCard(
          padding: EdgeInsets.zero,
          child: listContent,
        );
      } else {
        content = listContent;
      }
    }

    return FFScreenScaffold(
      title: title,
      showAppBar: showAppBar,
      useScrollView: useScrollView,
      verticalPadding: 0,
      child: Column(
        children: [
          // Header customizado
          if (header != null) header!,
          // Barra de ações
          if (primaryAction != null || secondaryAction != null || searchWidget != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                0,
                effectiveDensity.verticalPadding,
                0,
                effectiveDensity.verticalPadding,
              ),
              child: FFEntityActionsBar(
                primaryAction: primaryAction,
                secondaryAction: secondaryAction,
                searchWidget: searchWidget,
                density: effectiveDensity,
              ),
            ),
          // Conteúdo principal
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildColumnHeaders(ColorScheme colorScheme, FFEntityDensity density) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: density.horizontalPadding,
        vertical: density.verticalPadding,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
      ),
      child: Row(
        children: columnHeaders!
            .asMap()
            .entries
            .map((entry) {
              final isLast = entry.key == columnHeaders!.length - 1;
              return isLast
                  ? Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: density.subtitleFontSize + 1,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  : Expanded(
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: density.subtitleFontSize + 1,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
            })
            .toList(),
      ),
    );
  }
}
