import 'package:flutter/material.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Botão principal do FácilFin Design System.
///
/// Características:
/// - Altura padronizada (48)
/// - Radius padrão (md = 12)
/// - Fonte padronizada
/// - Suporte a loading state
/// - Suporte a ícone
class FFPrimaryButton extends StatelessWidget {
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

  /// Cor de fundo customizada
  final Color? backgroundColor;

  /// Cor do texto customizada
  final Color? foregroundColor;

  const FFPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.expanded = true,
    this.height,
    this.horizontalPadding,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final button = FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size(0, height ?? 48),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding ?? AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        disabledBackgroundColor: theme.colorScheme.primary.withValues(alpha: 0.5),
      ),
      child: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  foregroundColor ?? theme.colorScheme.onPrimary,
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
            ),
    );

    if (expanded) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    return button;
  }

  /// Factory para botão de perigo (ação destrutiva)
  factory FFPrimaryButton.danger({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    bool isLoading = false,
    IconData? icon,
    bool expanded = true,
  }) {
    return FFPrimaryButton(
      key: key,
      label: label,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      expanded: expanded,
      backgroundColor: const Color(0xFFDC2626), // AppColors.error
      foregroundColor: Colors.white,
    );
  }
}
