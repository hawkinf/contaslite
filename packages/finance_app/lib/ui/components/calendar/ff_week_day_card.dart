import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';
import '../../theme/app_radius.dart';
import 'ff_day_tile.dart';

/// Card de dia para visualização semanal do FácilFin Design System.
///
/// Exibe informações de um dia da semana com nome do dia,
/// número, indicadores e totais de valores.
///
/// Exemplo de uso:
/// ```dart
/// FFWeekDayCard(
///   day: 15,
///   dayName: 'SEG',
///   isToday: true,
///   isWeekend: false,
///   totals: FFDayTotals(totalPagar: 1500, countPagar: 2),
///   onTap: () => _showDayDetails(),
/// )
/// ```
class FFWeekDayCard extends StatelessWidget {
  /// Número do dia
  final int day;

  /// Nome do dia da semana abreviado (ex: 'SEG', 'TER')
  final String dayName;

  /// Se é o dia de hoje
  final bool isToday;

  /// Se é fim de semana
  final bool isWeekend;

  /// Totais do dia
  final FFDayTotals totals;

  /// Callback ao tocar no card
  final VoidCallback? onTap;

  /// Cor de fundo customizada
  final Color? backgroundColor;

  /// Cor da borda customizada
  final Color? borderColor;

  /// Margem externa
  final EdgeInsetsGeometry margin;

  /// Formatador de moeda customizado
  final String Function(double)? currencyFormatter;

  const FFWeekDayCard({
    super.key,
    required this.day,
    required this.dayName,
    this.isToday = false,
    this.isWeekend = false,
    this.totals = const FFDayTotals(),
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.margin = const EdgeInsets.only(bottom: 8),
    this.currencyFormatter,
  });

  String _formatCurrency(double value) {
    if (currencyFormatter != null) {
      return currencyFormatter!(value);
    }
    // Formatação básica de moeda brasileira
    final intPart = value.truncate();
    final decPart = ((value - intPart) * 100).round();
    final formattedInt = intPart.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return 'R\$ $formattedInt,${decPart.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final effectiveBgColor = backgroundColor ??
        (isToday
            ? colorScheme.primary.withValues(alpha: 0.08)
            : colorScheme.surfaceContainerLowest);

    final effectiveBorderColor = borderColor ??
        (isToday
            ? colorScheme.primary.withValues(alpha: 0.3)
            : colorScheme.outlineVariant.withValues(alpha: 0.3));

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: effectiveBorderColor),
      ),
      child: InkWell(
        onTap: totals.hasEvents ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Data
              SizedBox(
                width: 50,
                child: Column(
                  children: [
                    Text(
                      dayName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isWeekend
                            ? AppColors.error
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isToday
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              // Chip de HOJE
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'HOJE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // Valores
              if (totals.hasEvents) ...[
                if (totals.countPagar > 0)
                  _buildValueBadge(
                    totals.totalPagar,
                    totals.countPagar,
                    AppColors.error,
                    Icons.arrow_upward_rounded,
                  ),
                if (totals.countPagar > 0 && totals.countReceber > 0)
                  const SizedBox(width: 8),
                if (totals.countReceber > 0)
                  _buildValueBadge(
                    totals.totalReceber,
                    totals.countReceber,
                    AppColors.success,
                    Icons.arrow_downward_rounded,
                  ),
              ] else
                Text(
                  'Sem lançamentos',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValueBadge(double value, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            _formatCurrency(value),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
