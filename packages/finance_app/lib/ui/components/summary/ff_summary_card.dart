import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Card de resumo financeiro do FácilFin Design System.
///
/// Exibe um título, valor principal, valor previsto e ícone de status.
/// Suporta modo compacto para uso em headers colapsáveis.
///
/// Exemplo de uso:
/// ```dart
/// FFSummaryCard(
///   title: 'A RECEBER',
///   value: 'R$ 1.500,00',
///   forecast: 'R$ 2.000,00',
///   statusColor: AppColors.success,
///   icon: Icons.trending_up_rounded,
/// )
/// ```
class FFSummaryCard extends StatelessWidget {
  /// Título do card (ex: 'A RECEBER', 'A PAGAR')
  final String title;

  /// Valor principal formatado
  final String value;

  /// Valor previsto/estimado formatado
  final String forecast;

  /// Cor do status (verde para receber, vermelho para pagar)
  final Color statusColor;

  /// Ícone indicador de tendência
  final IconData icon;

  /// Modo compacto para headers colapsados
  final bool compact;

  /// Callback ao tocar no card
  final VoidCallback? onTap;

  const FFSummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.forecast,
    required this.statusColor,
    required this.icon,
    this.compact = false,
    this.onTap,
  });

  /// Factory para card de recebimentos
  factory FFSummaryCard.receber({
    Key? key,
    required String value,
    required String forecast,
    bool compact = false,
    VoidCallback? onTap,
  }) {
    return FFSummaryCard(
      key: key,
      title: 'A RECEBER',
      value: value,
      forecast: forecast,
      statusColor: AppColors.success,
      icon: Icons.trending_up_rounded,
      compact: compact,
      onTap: onTap,
    );
  }

  /// Factory para card de pagamentos
  factory FFSummaryCard.pagar({
    Key? key,
    required String value,
    required String forecast,
    bool compact = false,
    VoidCallback? onTap,
  }) {
    return FFSummaryCard(
      key: key,
      title: 'A PAGAR',
      value: value,
      forecast: forecast,
      statusColor: AppColors.error,
      icon: Icons.trending_down_rounded,
      compact: compact,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget content = compact
        ? _buildCompact(colorScheme)
        : _buildExpanded(colorScheme);

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(compact ? AppRadius.md : AppRadius.xl),
          child: content,
        ),
      );
    }

    return content;
  }

  Widget _buildCompact(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, size: 14, color: statusColor),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpanded(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 18, color: statusColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Previsto: $forecast',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
