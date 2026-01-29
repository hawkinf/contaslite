import 'package:flutter/material.dart';
import '../../theme/app_radius.dart';
import 'ff_entity_density.dart';

/// Card de menu/ação premium do FácilFin Design System.
///
/// Usado para criar menus de navegação estilo Settings com ícone,
/// título, subtítulo e chevron.
///
/// Exemplo:
/// ```dart
/// FFMenuActionCard(
///   icon: Icons.category_outlined,
///   iconColor: Colors.blue,
///   title: 'Categorias',
///   subtitle: 'Organize suas contas por categorias',
///   onTap: () => Navigator.push(...),
/// )
/// ```
class FFMenuActionCard extends StatelessWidget {
  /// Ícone do card
  final IconData icon;

  /// Cor do ícone (opcional, usa primary se não especificado)
  final Color? iconColor;

  /// Título principal
  final String title;

  /// Subtítulo opcional
  final String? subtitle;

  /// Callback ao tocar
  final VoidCallback? onTap;

  /// Se deve mostrar chevron à direita
  final bool showChevron;

  /// Widget trailing customizado (substitui chevron)
  final Widget? trailing;

  /// Densidade do componente
  final FFEntityDensity density;

  /// Se deve usar borda em vez de elevação
  final bool useBorder;

  const FFMenuActionCard({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.onTap,
    this.showChevron = true,
    this.trailing,
    this.density = FFEntityDensity.regular,
    this.useBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final effectiveIconColor = iconColor ?? colorScheme.primary;

    // Tamanhos baseados na densidade
    final iconContainerSize = density == FFEntityDensity.compact
        ? 40.0
        : density == FFEntityDensity.desktop
            ? 56.0
            : 48.0;

    final iconSize = density == FFEntityDensity.compact
        ? 20.0
        : density == FFEntityDensity.desktop
            ? 28.0
            : 24.0;

    final titleSize = density.titleFontSize;
    final subtitleSize = density.subtitleFontSize;
    final verticalPadding = density.verticalPadding;
    final horizontalPadding = density.horizontalPadding;

    return Material(
      color: isDark ? colorScheme.surfaceContainer : Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      elevation: isDark || useBorder ? 0 : 1,
      child: Container(
        decoration: useBorder
            ? BoxDecoration(
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              )
            : null,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: iconContainerSize,
                  height: iconContainerSize,
                  decoration: BoxDecoration(
                    color: effectiveIconColor.withValues(alpha: isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    icon,
                    size: iconSize,
                    color: effectiveIconColor,
                  ),
                ),
                SizedBox(width: horizontalPadding),
                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: subtitleSize,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Trailing
                if (trailing != null)
                  trailing!
                else if (showChevron)
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                    size: iconSize,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
