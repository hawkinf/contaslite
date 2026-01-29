import 'package:flutter/material.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../buttons/ff_icon_action_button.dart';
import 'ff_entity_density.dart';

/// Item de lista de entidades do FácilFin Design System.
///
/// Usado para exibir itens em listas de cadastro (categorias, formas de pagamento, etc.)
/// com ações de editar, reordenar e excluir.
///
/// Exemplo:
/// ```dart
/// FFEntityListItem(
///   leading: Text('🍔', style: TextStyle(fontSize: 24)),
///   title: 'Alimentação',
///   subtitle: 'Categoria de despesas',
///   onEdit: () => _editCategory(item),
///   onDelete: () => _deleteCategory(item),
/// )
/// ```
class FFEntityListItem extends StatelessWidget {
  /// Widget leading (ícone/emoji em container)
  final Widget? leading;

  /// Título principal
  final String title;

  /// Subtítulo opcional
  final String? subtitle;

  /// Callback ao editar
  final VoidCallback? onEdit;

  /// Callback ao reordenar (se null, não mostra botão)
  final VoidCallback? onReorder;

  /// Callback ao excluir
  final VoidCallback? onDelete;

  /// Callback ao tocar no item
  final VoidCallback? onTap;

  /// Densidade do item
  final FFEntityDensity density;

  /// Se deve mostrar borda inferior
  final bool showDivider;

  /// Widget trailing customizado (substitui ações padrão)
  final Widget? trailing;

  /// Cor de fundo
  final Color? backgroundColor;

  const FFEntityListItem({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.onEdit,
    this.onReorder,
    this.onDelete,
    this.onTap,
    this.density = FFEntityDensity.regular,
    this.showDivider = true,
    this.trailing,
    this.backgroundColor,
  });

  /// Factory para item de categoria
  factory FFEntityListItem.category({
    Key? key,
    String? emoji,
    required String name,
    String? description,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onTap,
    FFEntityDensity density = FFEntityDensity.regular,
    bool showDivider = true,
  }) {
    return FFEntityListItem(
      key: key,
      leading: emoji != null && emoji.isNotEmpty
          ? Text(emoji, style: const TextStyle(fontSize: 22))
          : null,
      title: name,
      subtitle: description,
      onEdit: onEdit,
      onDelete: onDelete,
      onTap: onTap,
      density: density,
      showDivider: showDivider,
    );
  }

  /// Factory para item de forma de pagamento
  factory FFEntityListItem.paymentMethod({
    Key? key,
    String? emoji,
    IconData? icon,
    required String name,
    String? type,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onTap,
    FFEntityDensity density = FFEntityDensity.regular,
    bool showDivider = true,
  }) {
    Widget? leadingWidget;
    if (emoji != null && emoji.isNotEmpty) {
      leadingWidget = Text(emoji, style: const TextStyle(fontSize: 22));
    } else if (icon != null) {
      leadingWidget = Icon(icon, size: 22);
    }

    return FFEntityListItem(
      key: key,
      leading: leadingWidget,
      title: name,
      subtitle: type,
      onEdit: onEdit,
      onDelete: onDelete,
      onTap: onTap,
      density: density,
      showDivider: showDivider,
    );
  }

  /// Factory para item de conta bancária
  factory FFEntityListItem.bankAccount({
    Key? key,
    String? emoji,
    IconData? icon,
    required String name,
    String? bankName,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onTap,
    FFEntityDensity density = FFEntityDensity.regular,
    bool showDivider = true,
  }) {
    Widget? leadingWidget;
    if (emoji != null && emoji.isNotEmpty) {
      leadingWidget = Text(emoji, style: const TextStyle(fontSize: 22));
    } else if (icon != null) {
      leadingWidget = Icon(icon, size: 22);
    }

    return FFEntityListItem(
      key: key,
      leading: leadingWidget,
      title: name,
      subtitle: bankName,
      onEdit: onEdit,
      onDelete: onDelete,
      onTap: onTap,
      density: density,
      showDivider: showDivider,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final content = Container(
      height: density.listItemHeight,
      padding: EdgeInsets.symmetric(horizontal: density.horizontalPadding),
      decoration: BoxDecoration(
        color: backgroundColor ?? (isDark ? colorScheme.surface : Colors.white),
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: 1,
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          // Leading
          if (leading != null) ...[
            _LeadingContainer(
              density: density,
              child: leading!,
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          // Title and subtitle
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: density.titleFontSize,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: density.subtitleFontSize,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Trailing / Actions
          if (trailing != null)
            trailing!
          else
            _buildActions(colorScheme),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: content,
        ),
      );
    }

    return content;
  }

  Widget _buildActions(ColorScheme colorScheme) {
    final actionSize = density.iconSize + 12;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onEdit != null)
          FFIconActionButton(
            icon: Icons.edit_outlined,
            onPressed: onEdit!,
            tooltip: 'Editar',
            size: actionSize,
            iconSize: density.iconSize,
          ),
        if (onReorder != null)
          FFIconActionButton(
            icon: Icons.drag_handle,
            onPressed: onReorder!,
            tooltip: 'Reordenar',
            size: actionSize,
            iconSize: density.iconSize,
          ),
        if (onDelete != null)
          FFIconActionButton.danger(
            icon: Icons.delete_outline,
            onPressed: onDelete!,
            tooltip: 'Excluir',
            size: actionSize,
            iconSize: density.iconSize,
          ),
      ],
    );
  }
}

/// Container para o leading do item
class _LeadingContainer extends StatelessWidget {
  final Widget child;
  final FFEntityDensity density;

  const _LeadingContainer({
    required this.density,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: density.leadingSize,
      height: density.leadingSize,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
