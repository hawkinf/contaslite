import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';
import '../../theme/app_radius.dart';
import 'ff_calendar_totals_bar.dart';

/// Card de mês mini para visualização anual do FácilFin Design System.
///
/// Exibe o nome do mês, indicador de mês atual e totais resumidos.
///
/// Exemplo de uso:
/// ```dart
/// FFMiniMonthCard(
///   monthName: 'JAN',
///   isCurrentMonth: true,
///   totals: FFPeriodTotals(totalPagar: 5000, countPagar: 10),
///   onTap: () => _navigateToMonth(1),
/// )
/// ```
class FFMiniMonthCard extends StatelessWidget {
  /// Nome do mês abreviado (ex: 'JAN', 'FEV')
  final String monthName;

  /// Se é o mês atual
  final bool isCurrentMonth;

  /// Totais do mês
  final FFPeriodTotals totals;

  /// Callback ao tocar no card
  final VoidCallback? onTap;

  /// Cor de fundo customizada
  final Color? backgroundColor;

  /// Cor da borda customizada
  final Color? borderColor;

  /// Se deve mostrar chip "ATUAL" quando for mês atual
  final bool showCurrentChip;

  const FFMiniMonthCard({
    super.key,
    required this.monthName,
    this.isCurrentMonth = false,
    this.totals = const FFPeriodTotals(),
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.showCurrentChip = true,
  });

  String _formatCompactValue(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    } else {
      // Formatação básica de moeda brasileira
      final intPart = value.truncate();
      final decPart = ((value - intPart) * 100).round();
      final formattedInt = intPart.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
      return 'R\$ $formattedInt,${decPart.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final effectiveBgColor = backgroundColor ??
        (isCurrentMonth
            ? colorScheme.primary.withValues(alpha: 0.08)
            : colorScheme.surfaceContainerLowest);

    final effectiveBorderColor = borderColor ??
        (isCurrentMonth
            ? colorScheme.primary.withValues(alpha: 0.3)
            : colorScheme.outlineVariant.withValues(alpha: 0.3));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: effectiveBgColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: effectiveBorderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Nome do mês
            Text(
              monthName.toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isCurrentMonth
                    ? colorScheme.primary
                    : colorScheme.onSurface,
              ),
            ),
            // Chip "ATUAL"
            if (isCurrentMonth && showCurrentChip) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'ATUAL',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            // Mini totais
            if (totals.hasData) ...[
              if (totals.countPagar > 0)
                _buildMiniTotalRow(
                  totals.totalPagar,
                  AppColors.error,
                  Icons.arrow_upward_rounded,
                ),
              if (totals.countReceber > 0)
                _buildMiniTotalRow(
                  totals.totalReceber,
                  AppColors.success,
                  Icons.arrow_downward_rounded,
                ),
            ] else
              Text(
                'Sem lançamentos',
                style: TextStyle(
                  fontSize: 9,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniTotalRow(double value, Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 10),
        const SizedBox(width: 2),
        Text(
          _formatCompactValue(value),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
