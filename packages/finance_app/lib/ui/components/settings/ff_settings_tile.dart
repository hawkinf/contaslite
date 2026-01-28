import 'package:flutter/material.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../cards/ff_card.dart';

/// Tile de configuração premium do FácilFin Design System.
///
/// Substituto do ListTile padrão com visual premium:
/// - Ícone dentro de container com fundo suave
/// - Título e subtítulo com hierarquia clara
/// - Chevron à direita (navegação)
/// - Feedback visual ao tocar
class FFSettingsTile extends StatelessWidget {
  /// Ícone do tile
  final IconData icon;

  /// Cor do ícone (padrão: primary)
  final Color? iconColor;

  /// Título principal
  final String title;

  /// Subtítulo/descrição
  final String? subtitle;

  /// Callback ao tocar
  final VoidCallback? onTap;

  /// Se deve mostrar o chevron
  final bool showChevron;

  /// Widget trailing customizado
  final Widget? trailing;

  /// Se o tile está habilitado
  final bool enabled;

  /// Padding interno
  final EdgeInsetsGeometry? padding;

  /// Se deve usar card wrapper (padrão true)
  /// Defina como false quando usado dentro de FFSettingsGroup
  final bool useCard;

  const FFSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor,
    this.subtitle,
    this.onTap,
    this.showChevron = true,
    this.trailing,
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
          _SettingsIconContainer(
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

    if (useCard) {
      return FFCard(
        onTap: enabled ? onTap : null,
        padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
        child: content,
      );
    }

    // Sem card wrapper (para uso dentro de FFSettingsGroup)
    if (onTap != null && enabled) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: padding ?? const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: content,
        ),
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

/// Container de ícone para FFSettingsTile
class _SettingsIconContainer extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _SettingsIconContainer({
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
