import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';
import '../../theme/app_radius.dart';
import '../buttons/ff_icon_action_button.dart';
import 'ff_day_tile.dart';

/// Configuração do modal de detalhes do dia
class FFDayDetailsConfig {
  /// Tamanho inicial do sheet (0.0 a 1.0)
  final double initialChildSize;

  /// Tamanho mínimo do sheet
  final double minChildSize;

  /// Tamanho máximo do sheet
  final double maxChildSize;

  /// Se deve mostrar handle bar
  final bool showHandleBar;

  /// Raio das bordas superiores
  final double borderRadius;

  /// Se deve mostrar botão de fechar
  final bool showCloseButton;

  const FFDayDetailsConfig({
    this.initialChildSize = 0.6,
    this.minChildSize = 0.3,
    this.maxChildSize = 0.9,
    this.showHandleBar = true,
    this.borderRadius = 20,
    this.showCloseButton = true,
  });

  static const defaultConfig = FFDayDetailsConfig();
}

/// Modal de detalhes do dia do FácilFin Design System.
///
/// Exibe um modal com informações detalhadas de um dia,
/// incluindo data, totais e lista de eventos/contas.
///
/// Exemplo de uso:
/// ```dart
/// FFDayDetailsModal.show(
///   context: context,
///   date: DateTime.now(),
///   dateFormatted: '15 de Janeiro de 2024',
///   weekdayName: 'Segunda-feira',
///   totals: FFDayTotals(totalPagar: 1500, countPagar: 2),
///   eventsBuilder: (scrollController) => ListView.builder(...),
/// );
/// ```
class FFDayDetailsModal extends StatelessWidget {
  /// Data do dia
  final DateTime date;

  /// Data formatada para exibição (ex: '15 de Janeiro de 2024')
  final String dateFormatted;

  /// Nome do dia da semana (ex: 'Segunda-feira')
  final String weekdayName;

  /// Totais do dia
  final FFDayTotals totals;

  /// Builder para a lista de eventos/contas
  final Widget Function(ScrollController scrollController) eventsBuilder;

  /// Configuração do modal
  final FFDayDetailsConfig config;

  /// Formatador de moeda customizado
  final String Function(double)? currencyFormatter;

  const FFDayDetailsModal({
    super.key,
    required this.date,
    required this.dateFormatted,
    required this.weekdayName,
    required this.totals,
    required this.eventsBuilder,
    this.config = const FFDayDetailsConfig(),
    this.currencyFormatter,
  });

  /// Mostra o modal de detalhes do dia
  static Future<T?> show<T>({
    required BuildContext context,
    required DateTime date,
    required String dateFormatted,
    required String weekdayName,
    required FFDayTotals totals,
    required Widget Function(ScrollController scrollController) eventsBuilder,
    FFDayDetailsConfig config = const FFDayDetailsConfig(),
    String Function(double)? currencyFormatter,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FFDayDetailsModal(
        date: date,
        dateFormatted: dateFormatted,
        weekdayName: weekdayName,
        totals: totals,
        eventsBuilder: eventsBuilder,
        config: config,
        currencyFormatter: currencyFormatter,
      ),
    );
  }

  String _formatCurrency(double value) {
    if (currencyFormatter != null) {
      return currencyFormatter!(value);
    }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: config.initialChildSize,
      minChildSize: config.minChildSize,
      maxChildSize: config.maxChildSize,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(config.borderRadius),
          ),
          // Sem sombra no dark mode, apenas borda
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
          border: isDark
              ? Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                )
              : null,
        ),
        child: Column(
          children: [
            // Handle bar + close button
            Stack(
              alignment: Alignment.center,
              children: [
                if (config.showHandleBar)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                if (config.showCloseButton)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: FFIconActionButton(
                      icon: Icons.close,
                      tooltip: 'Fechar',
                      onPressed: () => Navigator.of(context).pop(),
                      size: 32,
                    ),
                  ),
              ],
            ),
            // Header com data e totais
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  Text(
                    dateFormatted,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    weekdayName,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Cards de totais compactos
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactTotalCard(
                          context: context,
                          title: 'A Pagar',
                          value: totals.totalPagar,
                          count: totals.countPagar,
                          color: AppColors.error,
                          icon: Icons.arrow_upward_rounded,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildCompactTotalCard(
                          context: context,
                          title: 'A Receber',
                          value: totals.totalReceber,
                          count: totals.countReceber,
                          color: AppColors.success,
                          icon: Icons.arrow_downward_rounded,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            // Lista de contas
            Expanded(
              child: eventsBuilder(scrollController),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactTotalCard({
    required BuildContext context,
    required String title,
    required double value,
    required int count,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.25 : 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  _formatCurrency(value),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
