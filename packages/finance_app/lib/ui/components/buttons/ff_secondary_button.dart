import 'package:flutter/material.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Botão secundário (outlined/tonal) do FácilFin Design System.
///
/// Características:
/// - Estilo outlined padrão
/// - Altura padronizada (48)
/// - Radius padrão (md = 12)
/// - Suporte a loading state
/// - Suporte a ícone
class FFSecondaryButton extends StatelessWidget {
  /// Texto do botão
  final String label;

  /// Callback ao pressionar
  final VoidCallback? onPressed;

  /// Se está em estado de loading
  final bool isLoading;

  /// Ícone opcional à esquerda
  final IconData? icon;

  /// Se o botão deve ocupar largura total
  final bool expanded;

  /// Altura customizada (padrão 48)
  final double? height;

  /// Padding horizontal customizado
  final double? horizontalPadding;

  /// Se deve usar estilo tonal ao invés de outlined
  final bool tonal;

  /// Cor da borda (para outlined)
  final Color? borderColor;

  const FFSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.expanded = true,
    this.height,
    this.horizontalPadding,
    this.tonal = false,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final buttonStyle = tonal
        ? FilledButton.styleFrom(
            minimumSize: Size(0, height ?? 48),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding ?? AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
          )
        : OutlinedButton.styleFrom(
            minimumSize: Size(0, height ?? 48),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding ?? AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            side: BorderSide(
              color: borderColor ?? theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
          );

    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(
                theme.colorScheme.primary,
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

    Widget button;
    if (tonal) {
      button = FilledButton.tonal(
        onPressed: isLoading ? null : onPressed,
        style: buttonStyle,
        child: child,
      );
    } else {
      button = OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: buttonStyle,
        child: child,
      );
    }

    if (expanded) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    return button;
  }
}
