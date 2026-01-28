import 'package:flutter/material.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// Mini chip de status do FácilFin Design System.
///
/// Exibe labels compactos para status de conta.
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

  /// Cor do ícone
  final Color? iconColor;

  /// Cor do texto
  final Color? textColor;

  /// Cor de fundo
  final Color? backgroundColor;

  /// Cor da borda
  final Color? borderColor;

  const FFMiniChip({
    super.key,
    required this.label,
    this.icon,
    this.iconColor,
    this.textColor,
    this.backgroundColor,
    this.borderColor,
  });

  /// Factory para chip de status pago
  factory FFMiniChip.pago({Key? key, bool isRecebimento = false}) {
    return FFMiniChip(
      key: key,
      label: isRecebimento ? 'Recebido' : 'Pago',
      icon: Icons.check_circle,
    );
  }

  /// Factory para chip de recorrência
  factory FFMiniChip.recorrencia({Key? key}) {
    return FFMiniChip(
      key: key,
      label: 'Recorrência',
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
      textColor: isRecebimento ? Colors.green.shade600 : Colors.red.shade600,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color resolvedBackground =
        backgroundColor ?? colorScheme.surfaceContainerHighest;
    final Color? resolvedBorder = borderColor;
    final Color resolvedText = textColor ?? colorScheme.onSurfaceVariant;
    final Color resolvedIcon = iconColor ?? resolvedText;

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: resolvedBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: resolvedBorder == null ? null : Border.all(color: resolvedBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: resolvedIcon),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTextStyles.chip.copyWith(color: resolvedText),
          ),
        ],
      ),
    );
  }
}
