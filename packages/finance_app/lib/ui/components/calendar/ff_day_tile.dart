import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';
import '../../theme/app_radius.dart';
import 'ff_calendar_density.dart';

/// Dados de totais de um dia
class FFDayTotals {
  final double totalPagar;
  final double totalReceber;
  final int countPagar;
  final int countReceber;

  const FFDayTotals({
    this.totalPagar = 0,
    this.totalReceber = 0,
    this.countPagar = 0,
    this.countReceber = 0,
  });

  bool get hasEvents => countPagar > 0 || countReceber > 0;
  int get totalCount => countPagar + countReceber;

  static const empty = FFDayTotals();

  /// Cria cópia com alterações
  FFDayTotals copyWith({
    double? totalPagar,
    double? totalReceber,
    int? countPagar,
    int? countReceber,
  }) {
    return FFDayTotals(
      totalPagar: totalPagar ?? this.totalPagar,
      totalReceber: totalReceber ?? this.totalReceber,
      countPagar: countPagar ?? this.countPagar,
      countReceber: countReceber ?? this.countReceber,
    );
  }
}

/// Tile de dia do calendário do FácilFin Design System.
///
/// Exibe o número do dia, indicadores de feriado/hoje,
/// e badges de valores a pagar/receber.
///
/// Exemplo de uso:
/// ```dart
/// FFDayTile(
///   day: 15,
///   isToday: true,
///   totals: FFDayTotals(totalPagar: 1500, countPagar: 2),
///   onTap: () => _showDetails(),
/// )
/// ```
class FFDayTile extends StatelessWidget {
  /// Número do dia
  final int day;

  /// Se é o dia de hoje
  final bool isToday;

  /// Se está selecionado
  final bool isSelected;

  /// Se é fim de semana
  final bool isWeekend;

  /// Se é feriado
  final bool isHoliday;

  /// Nome do feriado (para tooltip)
  final String? holidayName;

  /// Se é de um mês diferente (fora do mês atual)
  final bool isOutsideMonth;

  /// Totais do dia
  final FFDayTotals totals;

  /// Callback ao tocar
  final VoidCallback? onTap;

  /// Se deve usar layout desktop (mais espaçoso)
  final bool isDesktop;

  /// Densidade do calendário (sobrescreve isDesktop se fornecido)
  final FFCalendarDensity? density;

  /// Tamanho da fonte do dia
  final double? dayFontSize;

  /// Margem externa do tile
  final EdgeInsetsGeometry? margin;

  const FFDayTile({
    super.key,
    required this.day,
    this.isToday = false,
    this.isSelected = false,
    this.isWeekend = false,
    this.isHoliday = false,
    this.holidayName,
    this.isOutsideMonth = false,
    this.totals = const FFDayTotals(),
    this.onTap,
    this.isDesktop = false,
    this.density,
    this.dayFontSize,
    this.margin,
  });

  /// Determina se é layout desktop baseado em density ou isDesktop
  bool get _isDesktopLayout =>
      density == FFCalendarDensity.desktop || (density == null && isDesktop);

  /// Determina se é layout compacto
  bool get _isCompactLayout => density == FFCalendarDensity.compact;

  Color _getDayTextColor(ColorScheme colorScheme, bool isDark) {
    if (isOutsideMonth) {
      return colorScheme.onSurfaceVariant.withValues(alpha: isDark ? 0.25 : 0.3);
    }
    if (isToday) {
      return colorScheme.primary;
    }
    if (isSelected) {
      return isDark ? AppColors.success : AppColors.successDark;
    }
    if (isHoliday) {
      return isDark ? Colors.purple.shade300 : Colors.purple.shade600;
    }
    if (isWeekend) {
      return AppColors.error.withValues(alpha: isDark ? 0.9 : 0.8);
    }
    return colorScheme.onSurface;
  }

  BoxDecoration? _getDayDecoration(ColorScheme colorScheme, bool isDark) {
    if (isToday) {
      return BoxDecoration(
        color: colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: isDark ? 0.5 : 0.6),
          width: 2,
        ),
        // Sem sombra no dark mode
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      );
    }
    if (isSelected) {
      return BoxDecoration(
        color: AppColors.success.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.success.withValues(alpha: isDark ? 0.4 : 0.5),
          width: 2,
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Usa density se fornecido, senão fallback para isDesktop
    final effectiveFontSize = dayFontSize ??
        (density?.dayFontSize ?? (_isDesktopLayout ? 24 : (_isCompactLayout ? 14 : 16)));
    final effectiveMargin = margin ??
        (density?.dayTileMargin ?? EdgeInsets.all(_isDesktopLayout ? 3 : 2));

    Widget content = Container(
      margin: effectiveMargin,
      decoration: _getDayDecoration(colorScheme, isDark),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(height: _isDesktopLayout ? 8 : 4),
          // Número do dia
          Text(
            '$day',
            style: TextStyle(
              fontSize: effectiveFontSize,
              fontWeight: isToday || isSelected ? FontWeight.w800 : FontWeight.w700,
              color: _getDayTextColor(colorScheme, isDark),
              height: 1.1,
            ),
          ),
          // Chip de HOJE (desktop only)
          if (isToday && _isDesktopLayout && !isOutsideMonth) ...[
            const SizedBox(height: 2),
            _buildTodayChip(colorScheme),
          ],
          // Indicador de feriado
          if (isHoliday && !isOutsideMonth) ...[
            const SizedBox(height: 2),
            _buildHolidayIndicator(isDark),
          ],
          // Badges de valores
          if (totals.hasEvents && !isOutsideMonth) ...[
            SizedBox(height: _isDesktopLayout ? 6 : 3),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  if (totals.countPagar > 0)
                    Tooltip(
                      message: 'A Pagar: ${_formatCurrency(totals.totalPagar)} (${totals.countPagar} ${totals.countPagar == 1 ? 'conta' : 'contas'})',
                      child: _buildValueBadge(totals.totalPagar, AppColors.error, totals.countReceber > 0, isDark),
                    ),
                  if (totals.countPagar > 0 && totals.countReceber > 0)
                    SizedBox(height: _isDesktopLayout ? 3 : 2),
                  if (totals.countReceber > 0)
                    Tooltip(
                      message: 'A Receber: ${_formatCurrency(totals.totalReceber)} (${totals.countReceber} ${totals.countReceber == 1 ? 'conta' : 'contas'})',
                      child: _buildValueBadge(totals.totalReceber, AppColors.success, totals.countPagar > 0, isDark),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null && totals.hasEvents) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }

  Widget _buildTodayChip(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'HOJE',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildHolidayIndicator(bool isDark) {
    return Tooltip(
      message: holidayName ?? 'Feriado',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: _isDesktopLayout ? 6 : 4,
          vertical: 1,
        ),
        decoration: BoxDecoration(
          color: isDark ? Colors.purple.shade800 : Colors.purple.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          _isDesktopLayout ? 'Feriado' : '🎉',
          style: TextStyle(
            fontSize: _isDesktopLayout ? 9 : 8,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.purple.shade200 : Colors.purple.shade700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildValueBadge(double value, Color color, bool isCompact, bool isDark) {
    final formattedValue = _formatCompactValue(value);
    final fontSize = _isDesktopLayout ? (isCompact ? 10.0 : 11.0) : (isCompact ? 7.0 : 8.0);
    final hPadding = _isDesktopLayout ? (isCompact ? 4.0 : 6.0) : (isCompact ? 2.0 : 3.0);
    final vPadding = _isDesktopLayout ? 2.0 : 1.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.85 : 0.9),
        borderRadius: BorderRadius.circular(_isDesktopLayout ? 6 : 4),
        // Sem sombra no dark mode
        boxShadow: (_isDesktopLayout && !isDark)
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Text(
        formattedValue,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: _isDesktopLayout ? 0.3 : 0,
        ),
      ),
    );
  }

  String _formatCompactValue(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(_isDesktopLayout ? 1 : 0)}K';
    } else {
      return _isDesktopLayout ? _formatCurrency(value) : value.toStringAsFixed(0);
    }
  }

  String _formatCurrency(double value) {
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
