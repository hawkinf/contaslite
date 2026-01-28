import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/status_indicator.dart';

/// Card de item de conta/lançamento do FácilFin Design System.
///
/// Exibe informações de uma conta com data, título, subtítulo,
/// valor, chips de status e ações.
///
/// Exemplo de uso:
/// ```dart
/// FFAccountItemCard(
///   datePill: FFDatePill(day: '15', weekday: 'SEG', accentColor: Colors.red),
///   title: 'Aluguel',
///   subtitle: 'Pagamento mensal',
///   value: 'R$ 1.500,00',
///   valueColor: AppColors.error,
///   accentColor: AppColors.error,
///   chips: [FFMiniChip(label: 'Recorrência')],
///   onTap: () => _editAccount(),
/// )
/// ```
class FFAccountItemCard extends StatelessWidget {
  /// Widget de data (FFDatePill)
  final Widget datePill;

  /// Título principal (categoria/tipo)
  final String title;

  /// Subtítulo (descrição da conta)
  final String subtitle;

  /// Valor formatado
  final String value;

  /// Cor do valor
  final Color valueColor;

  /// Lista de chips de status
  final List<Widget> chips;

  /// Cor de destaque (linha superior)
  final Color accentColor;

  /// Callback ao tocar no card
  final VoidCallback? onTap;

  /// Widget trailing (ex: botões de ação)
  final Widget? trailing;

  /// Cor de fundo customizada
  final Color? backgroundColor;

  /// Cor da borda customizada
  final Color? borderColor;

  /// Sombras customizadas
  final List<BoxShadow> boxShadow;

  /// Padding interno
  final EdgeInsetsGeometry padding;

  /// Emoji opcional antes do título
  final String? titleEmoji;

  /// Emoji opcional antes do subtítulo
  final String? subtitleEmoji;

  /// Widget de ícone do subtítulo (prioridade sobre emoji)
  final Widget? subtitleIcon;

  /// Valor previsto/estimado
  final String? estimatedValue;

  /// Opacidade do card (útil para contas pagas)
  final double opacity;

  /// Margem externa
  final EdgeInsetsGeometry? margin;

  const FFAccountItemCard({
    super.key,
    required this.datePill,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.valueColor,
    required this.chips,
    required this.accentColor,
    this.onTap,
    this.trailing,
    this.backgroundColor,
    this.borderColor,
    this.boxShadow = const [],
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.titleEmoji,
    this.subtitleEmoji,
    this.subtitleIcon,
    this.estimatedValue,
    this.opacity = 1.0,
    this.margin,
  });

  /// Factory para conta a pagar
  factory FFAccountItemCard.pagar({
    Key? key,
    required Widget datePill,
    required String title,
    required String subtitle,
    required String value,
    required List<Widget> chips,
    VoidCallback? onTap,
    Widget? trailing,
    String? titleEmoji,
    String? subtitleEmoji,
    Widget? subtitleIcon,
    String? estimatedValue,
    bool isPaid = false,
    EdgeInsetsGeometry? margin,
  }) {
    return FFAccountItemCard(
      key: key,
      datePill: datePill,
      title: title,
      subtitle: subtitle,
      value: value,
      valueColor: AppColors.error,
      chips: chips,
      accentColor: AppColors.error,
      onTap: onTap,
      trailing: trailing,
      titleEmoji: titleEmoji,
      subtitleEmoji: subtitleEmoji,
      subtitleIcon: subtitleIcon,
      estimatedValue: estimatedValue,
      opacity: isPaid ? 0.6 : 1.0,
      margin: margin,
    );
  }

  /// Factory para conta a receber
  factory FFAccountItemCard.receber({
    Key? key,
    required Widget datePill,
    required String title,
    required String subtitle,
    required String value,
    required List<Widget> chips,
    VoidCallback? onTap,
    Widget? trailing,
    String? titleEmoji,
    String? subtitleEmoji,
    Widget? subtitleIcon,
    String? estimatedValue,
    bool isPaid = false,
    EdgeInsetsGeometry? margin,
  }) {
    return FFAccountItemCard(
      key: key,
      datePill: datePill,
      title: title,
      subtitle: subtitle,
      value: value,
      valueColor: AppColors.success,
      chips: chips,
      accentColor: AppColors.success,
      onTap: onTap,
      trailing: trailing,
      titleEmoji: titleEmoji,
      subtitleEmoji: subtitleEmoji,
      subtitleIcon: subtitleIcon,
      estimatedValue: estimatedValue,
      opacity: isPaid ? 0.6 : 1.0,
      margin: margin,
    );
  }

  /// Factory para despesa de cartão
  factory FFAccountItemCard.cartao({
    Key? key,
    required Widget datePill,
    required String title,
    required String subtitle,
    required String value,
    required List<Widget> chips,
    VoidCallback? onTap,
    Widget? trailing,
    String? titleEmoji,
    Widget? subtitleIcon,
    String? estimatedValue,
    bool isPaid = false,
    EdgeInsetsGeometry? margin,
  }) {
    return FFAccountItemCard(
      key: key,
      datePill: datePill,
      title: title,
      subtitle: subtitle,
      value: value,
      valueColor: AppColors.primary,
      chips: chips,
      accentColor: AppColors.primary,
      onTap: onTap,
      trailing: trailing,
      titleEmoji: titleEmoji ?? '💳',
      subtitleIcon: subtitleIcon,
      estimatedValue: estimatedValue,
      opacity: isPaid ? 0.6 : 1.0,
      margin: margin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color resolvedBackground = backgroundColor ?? colorScheme.surface;
    final Color resolvedBorder =
        (borderColor ?? colorScheme.outlineVariant).withValues(alpha: 0.6);

    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: resolvedBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: resolvedBorder),
        boxShadow: boxShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha de destaque superior
            Container(
              height: 2,
              color: accentColor.withValues(alpha: 0.8),
            ),
            Padding(
              padding: padding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  datePill,
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título com emoji
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (titleEmoji != null && titleEmoji!.isNotEmpty) ...[
                              Text(
                                titleEmoji!,
                                style: const TextStyle(fontSize: 14, height: 1),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                title,
                                style: AppTextStyles.title.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Subtítulo com ícone/emoji
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (subtitleIcon != null) ...[
                              SizedBox(
                                width: 20,
                                height: 14,
                                child: subtitleIcon,
                              ),
                              const SizedBox(width: 6),
                            ] else if (subtitleEmoji != null &&
                                subtitleEmoji!.isNotEmpty) ...[
                              Text(
                                subtitleEmoji!,
                                style: const TextStyle(fontSize: 13, height: 1),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                subtitle,
                                style: AppTextStyles.subtitle.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        // Chips
                        if (chips.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: chips,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // Coluna de valor
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StatusIndicator.dot(color: valueColor, size: 6),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            value,
                            style: AppTextStyles.value.copyWith(
                              fontSize: 16,
                              color: valueColor,
                            ),
                          ),
                        ],
                      ),
                      if (estimatedValue != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Prev: $estimatedValue',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                      if (trailing != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        trailing!,
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Aplicar opacidade se necessário
    if (opacity < 1.0) {
      card = Opacity(opacity: opacity, child: card);
    }

    // Tornar clicável se onTap fornecido
    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: card,
        ),
      );
    }

    return card;
  }
}
