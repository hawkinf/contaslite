import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';

/// Dados de totais do período
class FFPeriodTotals {
  final double totalPagar;
  final double totalReceber;
  final int countPagar;
  final int countReceber;

  const FFPeriodTotals({
    this.totalPagar = 0,
    this.totalReceber = 0,
    this.countPagar = 0,
    this.countReceber = 0,
  });

  double get saldo => totalReceber - totalPagar;
  bool get hasData => countPagar > 0 || countReceber > 0;

  static const empty = FFPeriodTotals();
}

/// Barra de totais do calendário do FácilFin Design System.
///
/// Exibe totais de "A Pagar" e "A Receber" do período selecionado
/// com ícones, valores formatados e contadores.
///
/// Exemplo de uso:
/// ```dart
/// FFCalendarTotalsBar(
///   totals: FFPeriodTotals(
///     totalPagar: 5000,
///     totalReceber: 8000,
///     countPagar: 10,
///     countReceber: 5,
///   ),
/// )
/// ```
class FFCalendarTotalsBar extends StatelessWidget {
  /// Totais do período
  final FFPeriodTotals totals;

  /// Padding interno
  final EdgeInsetsGeometry padding;

  /// Cor de fundo
  final Color? backgroundColor;

  /// Se deve mostrar borda inferior
  final bool showBottomBorder;

  /// Se deve usar layout compacto
  final bool compact;

  /// Formatador de moeda customizado
  final String Function(double)? currencyFormatter;

  const FFCalendarTotalsBar({
    super.key,
    required this.totals,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.backgroundColor,
    this.showBottomBorder = true,
    this.compact = false,
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

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.surface,
        border: showBottomBorder
            ? Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTotalChip(
              context: context,
              label: 'Pagar',
              value: totals.totalPagar,
              count: totals.countPagar,
              color: AppColors.error,
              icon: Icons.arrow_upward_rounded,
              colorScheme: colorScheme,
            ),
          ),
          SizedBox(width: compact ? 8 : 12),
          Expanded(
            child: _buildTotalChip(
              context: context,
              label: 'Receber',
              value: totals.totalReceber,
              count: totals.countReceber,
              color: AppColors.success,
              icon: Icons.arrow_downward_rounded,
              colorScheme: colorScheme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalChip({
    required BuildContext context,
    required String label,
    required double value,
    required int count,
    required Color color,
    required IconData icon,
    required ColorScheme colorScheme,
  }) {
    final fontSize = compact ? 11.0 : 12.0;
    final valueFontSize = compact ? 12.0 : 13.0;
    final iconSize = compact ? 14.0 : 16.0;
    final countFontSize = compact ? 8.0 : 9.0;
    final hPadding = compact ? 10.0 : 12.0;
    final vPadding = compact ? 6.0 : 8.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: iconSize),
              SizedBox(width: compact ? 4 : 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    _formatCurrency(value),
                    style: TextStyle(
                      fontSize: valueFontSize,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (count > 0) ...[
                  SizedBox(width: compact ? 4 : 6),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 4 : 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: countFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
