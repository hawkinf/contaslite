import 'package:flutter/material.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../cards/ff_card.dart';

/// Tile de configuração com Dropdown do FácilFin Design System.
///
/// Mesmo visual do FFSettingsTile mas com Dropdown à direita
/// para preferências selecionáveis.
class FFSettingsDropdownTile<T> extends StatelessWidget {
  /// Ícone do tile
  final IconData icon;

  /// Cor do ícone (padrão: primary)
  final Color? iconColor;

  /// Título principal
  final String title;

  /// Subtítulo/descrição
  final String? subtitle;

  /// Valor atual selecionado
  final T? value;

  /// Lista de itens disponíveis
  final List<DropdownMenuItem<T>> items;

  /// Callback ao mudar o valor
  final ValueChanged<T?>? onChanged;

  /// Hint quando nenhum valor selecionado
  final String? hint;

  /// Se o tile está habilitado
  final bool enabled;

  /// Padding interno
  final EdgeInsetsGeometry? padding;

  /// Se deve usar card wrapper
  final bool useCard;

  const FFSettingsDropdownTile({
    super.key,
    required this.icon,
    required this.title,
    required this.items,
    this.iconColor,
    this.subtitle,
    this.value,
    this.onChanged,
    this.hint,
    this.enabled = true,
    this.padding,
    this.useCard = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = enabled
        ? (iconColor ?? theme.colorScheme.primary)
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);

    final content = Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Row(
        children: [
          // Icon container
          _DropdownTileIconContainer(
            icon: icon,
            color: effectiveIconColor,
          ),
          const SizedBox(width: 14),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Dropdown
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: enabled ? onChanged : null,
              hint: hint != null ? Text(hint!) : null,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );

    if (useCard) {
      return FFCard(
        padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
        child: content,
      );
    }

    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: content,
    );
  }
}

/// Container de ícone para FFSettingsDropdownTile
class _DropdownTileIconContainer extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _DropdownTileIconContainer({
    required this.icon,
    required this.color,
  });

  static const double _size = 44;
  static const double _iconSize = 22;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(
        icon,
        color: color,
        size: _iconSize,
      ),
    );
  }
}
