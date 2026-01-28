import 'package:flutter/material.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'ff_card.dart';

/// Card clicável com chevron do FácilFin Design System.
///
/// Usado para navegação e ações.
/// - Ícone em container colorido à esquerda
/// - Título e subtítulo
/// - Chevron à direita (indicador de navegação)
/// - Feedback visual (InkWell)
class FFActionCard extends StatelessWidget {
  /// Ícone do card
  final IconData icon;

  /// Cor do ícone e seu container
  final Color? iconColor;

  /// Título principal
  final String title;

  /// Subtítulo/descrição
  final String? subtitle;

  /// Callback obrigatório ao tocar
  final VoidCallback onTap;

  /// Se deve mostrar o chevron
  final bool showChevron;

  /// Widget trailing customizado (substitui chevron)
  final Widget? trailing;

  /// Padding interno
  final EdgeInsetsGeometry? padding;

  const FFActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.subtitle,
    this.showChevron = true,
    this.trailing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.colorScheme.primary;

    return FFCard(
      onTap: onTap,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          // Icon container
          _FFIconContainer(
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
          // Trailing
          if (trailing != null)
            trailing!
          else if (showChevron)
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              size: 24,
            ),
        ],
      ),
    );
  }
}

/// Container interno para ícone do FFActionCard
class _FFIconContainer extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _FFIconContainer({
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
