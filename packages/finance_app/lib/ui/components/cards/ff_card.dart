import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';

/// Card base do FácilFin Design System.
///
/// Características:
/// - Radius padrão (lg = 16)
/// - Borda 1px suave
/// - Sombra leve apenas no modo claro
/// - Padding interno padrão (16)
/// - Suporte a onTap com feedback visual
class FFCard extends StatelessWidget {
  /// Conteúdo do card
  final Widget child;

  /// Callback ao tocar no card (torna clicável)
  final VoidCallback? onTap;

  /// Padding interno customizado
  final EdgeInsetsGeometry? padding;

  /// Border radius customizado
  final double? borderRadius;

  /// Cor de fundo customizada
  final Color? backgroundColor;

  /// Se deve mostrar borda
  final bool showBorder;

  /// Se deve mostrar sombra
  final bool showShadow;

  /// Margem externa
  final EdgeInsetsGeometry? margin;

  const FFCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.borderRadius,
    this.backgroundColor,
    this.showBorder = true,
    this.showShadow = true,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    final effectiveBackgroundColor = backgroundColor ??
        (isDark
            ? theme.colorScheme.surfaceContainerHighest
            : Colors.white);

    final effectiveBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : AppColors.border;

    final effectiveRadius = borderRadius ?? AppRadius.lg;

    Widget cardContent = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: showBorder
            ? Border.all(color: effectiveBorderColor, width: 1)
            : null,
        boxShadow: (showShadow && !isDark) ? AppShadows.soft : null,
      ),
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(effectiveRadius),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
