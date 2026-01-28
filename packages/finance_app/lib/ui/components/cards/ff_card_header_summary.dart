import 'package:flutter/material.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:intl/intl.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../lists/ff_mini_chip.dart';

/// Dados do resumo de fatura do cartão
class FFCardInvoiceSummary {
  /// Total lançado (confirmado)
  final double launchedTotal;

  /// Total previsto (incluindo não lançadas)
  final double forecastTotal;

  /// Total de assinaturas/recorrências
  final double subscriptionsTotal;

  /// Total de compras à vista
  final double spotTotal;

  /// Total de compras parceladas
  final double installmentsTotal;

  const FFCardInvoiceSummary({
    required this.launchedTotal,
    required this.forecastTotal,
    this.subscriptionsTotal = 0,
    this.spotTotal = 0,
    this.installmentsTotal = 0,
  });

  /// Se há diferença significativa entre lançado e previsto
  bool get hasForecastDifference => (forecastTotal - launchedTotal).abs() > 0.50;
}

/// Header de resumo do cartão de crédito do FácilFin Design System.
///
/// Exibe informações do cartão com totais da fatura, datas de
/// fechamento/vencimento e breakdown por tipo de despesa.
///
/// Suporta modo expandido (detalhado) e compacto.
///
/// Exemplo de uso:
/// ```dart
/// FFCardHeaderSummary(
///   cardTitle: 'Nubank • Mastercard',
///   cardColor: Colors.purple,
///   cardBrand: 'Mastercard',
///   closingDate: DateTime(2024, 1, 25),
///   dueDate: DateTime(2024, 2, 1),
///   summary: FFCardInvoiceSummary(
///     launchedTotal: 1500.00,
///     forecastTotal: 2000.00,
///     subscriptionsTotal: 200.00,
///     spotTotal: 800.00,
///     installmentsTotal: 500.00,
///   ),
///   compact: false,
/// )
/// ```
class FFCardHeaderSummary extends StatelessWidget {
  /// Título do cartão (ex: "Nubank • Mastercard")
  final String cardTitle;

  /// Cor do cartão
  final Color cardColor;

  /// Bandeira do cartão (ex: "Mastercard", "Visa")
  final String? cardBrand;

  /// Data de fechamento da fatura
  final DateTime closingDate;

  /// Data de vencimento da fatura
  final DateTime dueDate;

  /// Resumo dos valores da fatura
  final FFCardInvoiceSummary summary;

  /// Se deve exibir em modo compacto
  final bool compact;

  /// Padding externo
  final EdgeInsetsGeometry? padding;

  /// Callback ao tocar no header (para expandir/colapsar)
  final VoidCallback? onTap;

  const FFCardHeaderSummary({
    super.key,
    required this.cardTitle,
    required this.cardColor,
    this.cardBrand,
    required this.closingDate,
    required this.dueDate,
    required this.summary,
    this.compact = false,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ??
        EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: compact ? 4 : 2,
        );

    return Padding(
      padding: effectivePadding,
      child: compact ? _buildCompact(context) : _buildExpanded(context),
    );
  }

  Widget _buildExpanded(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brandIcon = _buildBrandIcon(height: 14);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Color bar indicator
          Container(
            height: 2,
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              2,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card title row
                Row(
                  children: [
                    if (brandIcon != null) ...[
                      brandIcon,
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: Text(
                        cardTitle.isEmpty ? 'Cartão' : cardTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.credit_card, color: cardColor, size: 20),
                  ],
                ),
                const SizedBox(height: 6),
                // Main total
                Text(
                  UtilBrasilFields.obterReal(summary.launchedTotal),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 2),
                // Forecast
                Text(
                  'Previsto: ${UtilBrasilFields.obterReal(summary.forecastTotal)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 6),
                // Breakdown chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildBreakdownChip(
                      context,
                      label: 'Assinaturas',
                      value: summary.subscriptionsTotal,
                      icon: Icons.loop,
                    ),
                    _buildBreakdownChip(
                      context,
                      label: 'À vista',
                      value: summary.spotTotal,
                    ),
                    _buildBreakdownChip(
                      context,
                      label: 'Parcelado',
                      value: summary.installmentsTotal,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // Dates row
                _buildDatesRow(context, expanded: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brandIcon = _buildBrandIcon(height: 12);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            // Color indicator bar
            Container(
              width: 3,
              height: 32,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Brand logo
            if (brandIcon != null) ...[
              brandIcon,
              const SizedBox(width: AppSpacing.sm),
            ],
            // Card name
            Expanded(
              child: Text(
                cardTitle.isEmpty ? 'Cartão' : cardTitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Compact dates
            Text(
              'Fech. ${DateFormat('dd').format(closingDate)} • Venc. ${DateFormat('dd').format(dueDate)}',
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            // Compact totals
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  UtilBrasilFields.obterReal(summary.launchedTotal),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (summary.hasForecastDifference)
                  Text(
                    'Prev: ${UtilBrasilFields.obterReal(summary.forecastTotal)}',
                    style: TextStyle(
                      fontSize: 9,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownChip(
    BuildContext context, {
    required String label,
    required double value,
    IconData? icon,
  }) {
    return Transform.scale(
      scale: 0.92,
      alignment: Alignment.centerLeft,
      child: FFMiniChip(
        label: '$label: ${UtilBrasilFields.obterReal(value)}',
        icon: icon,
        compact: true,
      ),
    );
  }

  Widget _buildDatesRow(BuildContext context, {required bool expanded}) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd/MM');

    return Row(
      children: [
        Icon(
          Icons.calendar_today_outlined,
          size: 14,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          'Fecha: ${dateFormat.format(closingDate)}',
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Icon(
          Icons.event_outlined,
          size: 14,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          'Vence: ${dateFormat.format(dueDate)}',
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget? _buildBrandIcon({double height = 14}) {
    final normalized = (cardBrand ?? '').trim().toUpperCase();
    if (normalized.isEmpty) return null;

    String? assetPath;
    if (normalized == 'VISA') {
      assetPath = 'assets/icons/cc_visa.png';
    } else if (normalized == 'AMEX' || normalized == 'AMERICAN EXPRESS') {
      assetPath = 'assets/icons/cc_amex.png';
    } else if (normalized == 'MASTER' || normalized == 'MASTERCARD') {
      assetPath = 'assets/icons/cc_mc.png';
    } else if (normalized == 'ELO') {
      assetPath = 'assets/icons/cc_elo.png';
    }

    if (assetPath != null) {
      return Image.asset(
        assetPath,
        package: 'finance_app',
        height: height,
        fit: BoxFit.contain,
      );
    }
    return null;
  }
}
