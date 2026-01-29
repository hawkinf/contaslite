import 'package:flutter/material.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../buttons/ff_icon_action_button.dart';

/// Densidade do item de lista
enum FFEntityListItemDensity {
  /// Regular (altura ~56px)
  regular,

  /// Compacto (altura ~48px)
  compact,
}

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
  final FFEntityListItemDensity density;

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
    this.density = FFEntityListItemDensity.regular,
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
    FFEntityListItemDensity density = FFEntityListItemDensity.regular,
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
    FFEntityListItemDensity density = FFEntityListItemDensity.regular,
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

  double get _height => density == FFEntityListItemDensity.compact ? 48.0 : 56.0;
  double get _fontSize => density == FFEntityListItemDensity.compact ? 14.0 : 15.0;
  double get _subtitleFontSize => density == FFEntityListItemDensity.compact ? 11.0 : 12.0;
  double get _iconSize => density == FFEntityListItemDensity.compact ? 18.0 : 20.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final content = Container(
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
                    fontSize: _fontSize,
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
                      fontSize: _subtitleFontSize,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onEdit != null)
          FFIconActionButton(
            icon: Icons.edit_outlined,
            onPressed: onEdit!,
            tooltip: 'Editar',
            size: _iconSize + 12,
            iconSize: _iconSize,
          ),
        if (onReorder != null)
          FFIconActionButton(
            icon: Icons.drag_handle,
            onPressed: onReorder!,
            tooltip: 'Reordenar',
            size: _iconSize + 12,
            iconSize: _iconSize,
          ),
        if (onDelete != null)
          FFIconActionButton.danger(
            icon: Icons.delete_outline,
            onPressed: onDelete!,
            tooltip: 'Excluir',
            size: _iconSize + 12,
            iconSize: _iconSize,
          ),
      ],
    );
  }
}

/// Container para o leading do item
class _LeadingContainer extends StatelessWidget {
  final Widget child;
  final FFEntityListItemDensity density;

  const _LeadingContainer({
    required this.child,
    required this.density,
  });

  double get _size => density == FFEntityListItemDensity.compact ? 32.0 : 40.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
