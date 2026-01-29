import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import '../buttons/ff_primary_button.dart';
import '../buttons/ff_secondary_button.dart';

/// Barra de ações do FácilFin Design System.
///
/// Usado para exibir ações primárias e secundárias no topo de páginas de cadastro.
/// Alinhada à direita no desktop, com suporte a search field opcional.
///
/// Exemplo:
/// ```dart
/// FFActionsBar(
///   primaryAction: FFActionsBarAction(
///     label: 'Novo Item',
///     icon: Icons.add,
///     onPressed: _addItem,
///   ),
///   secondaryAction: FFActionsBarAction(
///     label: 'Popular',
///     icon: Icons.auto_awesome,
///     onPressed: _populate,
///   ),
/// )
/// ```
class FFActionsBar extends StatelessWidget {
  /// Ação primária (botão azul/primary)
  final FFActionsBarAction? primaryAction;

  /// Ação secundária (botão outline/amber)
  final FFActionsBarAction? secondaryAction;

  /// Widget de busca opcional (trailing slot para futuro)
  final Widget? searchWidget;

  /// Espaçamento entre botões
  final double spacing;

  /// Padding externo
  final EdgeInsetsGeometry padding;

  /// Se deve usar Wrap para responsividade em telas pequenas
  final bool useWrap;

  const FFActionsBar({
    super.key,
    this.primaryAction,
    this.secondaryAction,
    this.searchWidget,
    this.spacing = AppSpacing.sm,
    this.padding = EdgeInsets.zero,
    this.useWrap = true,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (searchWidget != null) ...[
        Expanded(child: searchWidget!),
        SizedBox(width: spacing),
      ],
      if (secondaryAction != null)
        FFSecondaryButton(
          label: secondaryAction!.label,
          icon: secondaryAction!.icon,
          onPressed: secondaryAction!.onPressed,
          isLoading: secondaryAction!.isLoading,
          tonal: secondaryAction!.useTonal,
          expanded: false,
        ),
      if (secondaryAction != null && primaryAction != null)
        SizedBox(width: spacing),
      if (primaryAction != null)
        FFPrimaryButton(
          label: primaryAction!.label,
          icon: primaryAction!.icon,
          onPressed: primaryAction!.onPressed,
          isLoading: primaryAction!.isLoading,
          expanded: false,
        ),
    ];

    if (useWrap) {
      return Padding(
        padding: padding,
        child: Wrap(
          spacing: spacing,
          runSpacing: AppSpacing.xs,
          alignment: WrapAlignment.end,
          children: children.where((w) => w is! SizedBox || w.key != null).toList(),
        ),
      );
    }

    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: children,
      ),
    );
  }
}

/// Configuração de uma ação da barra
class FFActionsBarAction {
  /// Label do botão
  final String label;

  /// Ícone do botão
  final IconData? icon;

  /// Callback ao pressionar
  final VoidCallback? onPressed;

  /// Se está carregando
  final bool isLoading;

  /// Se deve usar estilo tonal (para secondary)
  final bool useTonal;

  const FFActionsBarAction({
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.useTonal = true,
  });
}
