import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// Tipo de cor semântica do chip
enum FFChipColorType { neutral, success, error, primary }

/// Mini chip de status do FácilFin Design System.
///
/// Exibe labels compactos para status de conta.
/// Suporta dark mode com contraste adequado.
///
/// Exemplo de uso:
/// ```dart
/// FFMiniChip(label: 'Recorrência')
/// FFMiniChip(label: 'Pago', icon: Icons.check_circle)
/// ```
class FFMiniChip extends StatelessWidget {
  /// Texto do chip
  final String label;

  /// Ícone opcional
  final IconData? icon;

  /// Cor do ícone (adapta ao tema se não fornecida)
  final Color? iconColor;

  /// Cor do texto (adapta ao tema se não fornecida)
  final Color? textColor;

  /// Cor de fundo (adapta ao tema se não fornecida)
  final Color? backgroundColor;

  /// Cor da borda
  final Color? borderColor;

  /// Modo compacto (menor altura e padding)
  final bool compact;

  /// Tipo de cor semântica (para adaptação ao dark mode)
  final FFChipColorType colorType;

  const FFMiniChip({
    super.key,
    required this.label,
    this.icon,
    this.iconColor,
    this.textColor,
    this.backgroundColor,
    this.borderColor,
    this.compact = false,
    this.colorType = FFChipColorType.neutral,
  });

  /// Factory para chip de status pago
  factory FFMiniChip.pago({Key? key, bool isRecebimento = false}) {
    return FFMiniChip(
      key: key,
      label: isRecebimento ? 'Recebido' : 'Pago',
      icon: Icons.check_circle,
      colorType: FFChipColorType.success,
    );
  }

  /// Factory para chip de recorrência
  factory FFMiniChip.recorrencia({Key? key}) {
    return FFMiniChip(
      key: key,
      label: 'Recorrência',
      icon: Icons.loop,
    );
  }

  /// Factory para chip de parcela única
  factory FFMiniChip.parcelaUnica({Key? key}) {
    return FFMiniChip(
      key: key,
      label: 'Parcela única',
    );
  }

  /// Factory para chip de parcela (ex: '3/12')
  factory FFMiniChip.parcela({
    Key? key,
    required int current,
    required int total,
    bool isRecebimento = false,
  }) {
    return FFMiniChip(
      key: key,
      label: '$current/$total',
      colorType: isRecebimento ? FFChipColorType.success : FFChipColorType.error,
    );
  }

  /// Factory para chip de sucesso (verde)
  factory FFMiniChip.success({Key? key, required String label, IconData? icon}) {
    return FFMiniChip(
      key: key,
      label: label,
      icon: icon,
      colorType: FFChipColorType.success,
    );
  }

  /// Factory para chip de erro (vermelho)
  factory FFMiniChip.error({Key? key, required String label, IconData? icon}) {
    return FFMiniChip(
      key: key,
      label: label,
      icon: icon,
      colorType: FFChipColorType.error,
    );
  }

  /// Factory para chip de cartão (azul)
  factory FFMiniChip.cartao({Key? key, required String label}) {
    return FFMiniChip(
      key: key,
      label: label,
      icon: Icons.credit_card,
      colorType: FFChipColorType.primary,
    );
  }

  double get _height => compact ? 22 : 26;
  double get _horizontalPadding => compact ? 8 : 12;
  double get _iconSize => compact ? 12 : 14;
  double get _fontSize => compact ? 10 : 12;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Resolver cores baseado no tipo semântico e tema
    final colors = _resolveColors(context, isDark, colorScheme);

    return Container(
      height: _height,
      padding: EdgeInsets.symmetric(horizontal: _horizontalPadding, vertical: 3),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: colors.border != null ? Border.all(color: colors.border!) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: _iconSize, color: colors.foreground),
            SizedBox(width: compact ? 3 : AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTextStyles.chip.copyWith(
              color: colors.foreground,
              fontSize: _fontSize,
              fontWeight: colorType != FFChipColorType.neutral
                  ? FontWeight.w700
                  : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  _ChipColors _resolveColors(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    // Se cores customizadas foram fornecidas, usar elas
    if (textColor != null || backgroundColor != null) {
      return _ChipColors(
        foreground: textColor ?? colorScheme.onSurfaceVariant,
        background: backgroundColor ?? colorScheme.surfaceContainerHighest,
        border: borderColor ??
            (isDark ? colorScheme.outlineVariant.withValues(alpha: 0.3) : null),
      );
    }

    // Cores baseadas no tipo semântico
    switch (colorType) {
      case FFChipColorType.success:
        return _ChipColors(
          foreground: isDark ? AppColors.success : Colors.green.shade700,
          background: isDark
              ? colorScheme.surfaceContainerHighest
              : Colors.green.shade50,
          border: isDark
              ? colorScheme.outlineVariant.withValues(alpha: 0.3)
              : null,
        );

      case FFChipColorType.error:
        return _ChipColors(
          foreground: isDark ? const Color(0xFFEF9A9A) : Colors.red.shade700,
          background: isDark
              ? colorScheme.surfaceContainerHighest
              : Colors.red.shade50,
          border: isDark
              ? colorScheme.outlineVariant.withValues(alpha: 0.3)
              : null,
        );

      case FFChipColorType.primary:
        return _ChipColors(
          foreground: isDark ? colorScheme.primary : AppColors.primary,
          background: isDark
              ? colorScheme.surfaceContainerHighest
              : Colors.blue.shade50,
          border: isDark
              ? colorScheme.outlineVariant.withValues(alpha: 0.3)
              : null,
        );

      case FFChipColorType.neutral:
        return _ChipColors(
          foreground: colorScheme.onSurfaceVariant,
          background: colorScheme.surfaceContainerHighest,
          border: isDark
              ? colorScheme.outlineVariant.withValues(alpha: 0.3)
              : borderColor,
        );
    }
  }
}

/// Helper class para cores do chip
class _ChipColors {
  final Color foreground;
  final Color background;
  final Color? border;

  const _ChipColors({
    required this.foreground,
    required this.background,
    this.border,
  });
}
