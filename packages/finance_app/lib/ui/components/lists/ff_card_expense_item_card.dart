import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/status_indicator.dart';
import 'ff_date_pill.dart';
import 'ff_mini_chip.dart';

/// Tipo de despesa do cartão
enum FFCardExpenseType {
  /// Compra à vista
  spot,

  /// Compra parcelada
  installment,

  /// Assinatura/recorrência
  subscription,
}

/// Card de item de despesa de cartão do FácilFin Design System.
///
/// Exibe informações de uma despesa de cartão de crédito com
/// data, descrição, categoria, valor e chips de status.
///
/// Exemplo de uso:
/// ```dart
/// FFCardExpenseItemCard(
///   day: '15',
///   weekday: 'SEG',
///   description: 'Netflix',
///   category: 'Streaming',
///   categoryEmoji: '🎬',
///   value: 'R$ 39,90',
///   expenseType: FFCardExpenseType.subscription,
///   cardColor: Colors.purple,
///   onTap: () => _editExpense(),
/// )
/// ```
class FFCardExpenseItemCard extends StatelessWidget {
  /// Dia do mês
  final String day;

  /// Dia da semana (ex: "SEG")
  final String weekday;

  /// Descrição da despesa
  final String description;

  /// Categoria da despesa
  final String? category;

  /// Emoji da categoria
  final String? categoryEmoji;

  /// Valor formatado
  final String value;

  /// Tipo de despesa (à vista, parcelado, assinatura)
  final FFCardExpenseType expenseType;

  /// Cor do cartão (para a linha de destaque)
  final Color cardColor;

  /// Parcela atual (se parcelado)
  final int? currentInstallment;

  /// Total de parcelas (se parcelado)
  final int? totalInstallments;

  /// Data de término do parcelamento
  final String? installmentEndDate;

  /// Nome do tipo (ex: "Pagamento", "Lazer")
  final String? typeName;

  /// Valor total previsto (ex: para parcelados)
  final String? estimatedValue;

  /// Se o item está selecionado
  final bool isSelected;

  /// Callback ao tocar
  final VoidCallback? onTap;

  /// Callback ao pressionar longo
  final VoidCallback? onLongPress;

  /// Widget trailing (ex: menu popup)
  final Widget? trailing;

  /// Modo compacto
  final bool compact;

  /// Padding externo
  final EdgeInsetsGeometry? padding;

  /// Margem externa
  final EdgeInsetsGeometry? margin;

  const FFCardExpenseItemCard({
    super.key,
    required this.day,
    required this.weekday,
    required this.description,
    this.category,
    this.categoryEmoji,
    required this.value,
    required this.expenseType,
    required this.cardColor,
    this.currentInstallment,
    this.totalInstallments,
    this.installmentEndDate,
    this.typeName,
    this.estimatedValue,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.compact = false,
    this.padding,
    this.margin,
  });

  // Getters para valores baseados em modo compacto
  double get _titleFontSize => compact ? 14 : 16;
  double get _subtitleFontSize => compact ? 11 : 12;
  double get _valueFontSize => compact ? 14 : 16;
  double get _emojiSize => compact ? 12 : 14;
  double get _gapAfterTitle => compact ? 4 : 6;
  double get _chipSpacing => compact ? 4 : AppSpacing.sm;

  EdgeInsetsGeometry get _effectivePadding =>
      padding ??
      (compact
          ? const EdgeInsets.all(AppSpacing.md)
          : const EdgeInsets.all(AppSpacing.lg));

  String get _expenseTypeLabel {
    switch (expenseType) {
      case FFCardExpenseType.spot:
        return 'À vista';
      case FFCardExpenseType.installment:
        return 'Parcelado';
      case FFCardExpenseType.subscription:
        return 'Recorrência';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.5)
              : colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Linha de destaque com cor do cartão
            Container(
              height: 2,
              color: cardColor.withValues(alpha: 0.8),
            ),
            Padding(
              padding: _effectivePadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date pill
                  FFDatePill(
                    day: day,
                    weekday: weekday,
                    accentColor: cardColor,
                    width: compact ? 48 : 56,
                    height: compact ? 54 : 64,
                  ),
                  SizedBox(
                      width: compact ? AppSpacing.sm : AppSpacing.md),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title with emoji
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (categoryEmoji != null &&
                                categoryEmoji!.isNotEmpty) ...[
                              Text(
                                categoryEmoji!,
                                style: TextStyle(fontSize: _emojiSize, height: 1),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                description,
                                style: AppTextStyles.title.copyWith(
                                  fontSize: _titleFontSize,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: _gapAfterTitle),
                        // Subtitle (category if exists)
                        if (category != null && category!.isNotEmpty)
                          Text(
                            category!,
                            style: AppTextStyles.subtitle.copyWith(
                              fontSize: _subtitleFontSize,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        // Chips
                        SizedBox(height: _chipSpacing),
                        Wrap(
                          spacing: _chipSpacing,
                          runSpacing: _chipSpacing,
                          children: _buildChips(context),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: compact ? AppSpacing.sm : AppSpacing.md),
                  // Value column
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            StatusIndicator.dot(
                              color: AppColors.primary,
                              size: compact ? 5 : 6,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Flexible(
                              child: Text(
                                value,
                                style: AppTextStyles.value.copyWith(
                                  fontSize: _valueFontSize,
                                  color: AppColors.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                        if (estimatedValue != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Total: $estimatedValue',
                            style: TextStyle(
                              fontSize: compact ? 10 : 11,
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ],
                        if (trailing != null) ...[
                          SizedBox(height: compact ? 4 : AppSpacing.sm),
                          trailing!,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap != null || onLongPress != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: card,
        ),
      );
    }

    return card;
  }

  List<Widget> _buildChips(BuildContext context) {
    final chips = <Widget>[];

    // Type name chip
    if (typeName != null && typeName!.isNotEmpty) {
      chips.add(FFMiniChip(
        label: typeName!,
        compact: compact,
      ));
    }

    // Expense type chip
    if (expenseType == FFCardExpenseType.subscription) {
      chips.add(FFMiniChip.recorrencia());
    } else {
      chips.add(FFMiniChip(
        label: _expenseTypeLabel,
        compact: compact,
      ));
    }

    // Installment chip
    if (expenseType == FFCardExpenseType.installment &&
        currentInstallment != null &&
        totalInstallments != null) {
      chips.add(FFMiniChip.parcela(
        current: currentInstallment!,
        total: totalInstallments!,
      ));

      // End date chip
      if (installmentEndDate != null) {
        chips.add(FFMiniChip(
          label: 'Término: $installmentEndDate',
          compact: compact,
        ));
      }
    }

    return chips;
  }
}
