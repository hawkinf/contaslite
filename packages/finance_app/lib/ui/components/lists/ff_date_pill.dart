import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Pill de data do FácilFin Design System.
///
/// Exibe dia e dia da semana em formato compacto.
///
/// Exemplo de uso:
/// ```dart
/// FFDatePill(
///   day: '15',
///   weekday: 'SEG',
///   accentColor: AppColors.error,
/// )
/// ```
class FFDatePill extends StatelessWidget {
  /// Dia do mês (ex: '15', '01')
  final String day;

  /// Dia da semana abreviado (ex: 'SEG', 'TER')
  final String weekday;

  /// Cor de destaque para o dia
  final Color accentColor;

  /// Largura do pill
  final double width;

  /// Altura do pill
  final double height;

  const FFDatePill({
    super.key,
    required this.day,
    required this.weekday,
    required this.accentColor,
    this.width = 56,
    this.height = 64,
  });

  /// Factory para data de pagamento (vermelho)
  factory FFDatePill.pagar({
    Key? key,
    required String day,
    required String weekday,
  }) {
    return FFDatePill(
      key: key,
      day: day,
      weekday: weekday,
      accentColor: AppColors.error,
    );
  }

  /// Factory para data de recebimento (verde)
  factory FFDatePill.receber({
    Key? key,
    required String day,
    required String weekday,
  }) {
    return FFDatePill(
      key: key,
      day: day,
      weekday: weekday,
      accentColor: AppColors.success,
    );
  }

  /// Factory para cartão (azul)
  factory FFDatePill.cartao({
    Key? key,
    required String day,
    required String weekday,
  }) {
    return FFDatePill(
      key: key,
      day: day,
      weekday: weekday,
      accentColor: AppColors.primary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            weekday,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
