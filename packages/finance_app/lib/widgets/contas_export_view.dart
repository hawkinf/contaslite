import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/account.dart';
import '../models/contas_view_state_snapshot.dart';
import '../services/default_account_categories_service.dart';
import '../ui/components/filter_bar.dart';
import '../ui/components/section_header.dart';
import '../ui/components/summary_card.dart';
import '../ui/theme/app_colors.dart' as app_tokens;
import '../ui/theme/app_spacing.dart';
import '../ui/widgets/date_pill.dart';
import '../ui/widgets/entry_card.dart';
import '../ui/widgets/mini_chip.dart';
import '../ui/components/period_header.dart';
import '../utils/card_utils.dart';
import '../utils/installment_utils.dart';

class ContasExportView extends StatelessWidget {
  final ContasViewStateSnapshot snapshot;
  final ScrollController? scrollController;

  const ContasExportView({
    super.key,
    required this.snapshot,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isSingleDay = DateUtils.isSameDay(
      snapshot.dateRange.start,
      snapshot.dateRange.end,
    );
    final bool useCompactCards = snapshot.useCompactSummaryCards;
    final EdgeInsets headerPadding = useCompactCards
        ? const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4)
        : const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs);

    return Material(
      color: colorScheme.surface,
      child: SingleChildScrollView(
        controller: scrollController,
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isSingleDay)
              AbsorbPointer(
                child: _buildMonthNavBar(context),
              ),
            AbsorbPointer(
              child: FilterBar(
                selected: snapshot.filterType,
                onSelected: (_) {},
                showPaid: snapshot.hidePaidAccounts,
                onShowPaidChanged: (_) {},
                periodValue: snapshot.periodFilterValue,
                onPeriodChanged: (_) {},
              ),
            ),
            Padding(
              padding: headerPadding,
              child: snapshot.isCombinedView
                  ? Row(
                      children: [
                        Expanded(
                          child: SummaryCard(
                            title: 'A RECEBER',
                            value: UtilBrasilFields.obterReal(snapshot.totalLancadoReceber),
                            forecast: UtilBrasilFields.obterReal(snapshot.totalPrevistoReceber),
                            statusColor: app_tokens.AppColors.success,
                            icon: Icons.trending_up_rounded,
                            compact: useCompactCards,
                          ),
                        ),
                        SizedBox(width: useCompactCards ? AppSpacing.sm : AppSpacing.md),
                        Expanded(
                          child: SummaryCard(
                            title: 'A PAGAR',
                            value: UtilBrasilFields.obterReal(snapshot.totalLancadoPagar),
                            forecast: UtilBrasilFields.obterReal(snapshot.totalPrevistoPagar),
                            statusColor: app_tokens.AppColors.error,
                            icon: Icons.trending_down_rounded,
                            compact: useCompactCards,
                          ),
                        ),
                      ],
                    )
                  : SummaryCard(
                      title: snapshot.totalLabel,
                      value: UtilBrasilFields.obterReal(snapshot.totalPeriod),
                      forecast: UtilBrasilFields.obterReal(snapshot.totalForecast),
                      statusColor: snapshot.totalColor,
                      icon: snapshot.filterType == AccountFilterType.receber
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      compact: useCompactCards,
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ..._buildGroups(context),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroups(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final widgets = <Widget>[];
    for (final group in snapshot.groups) {
      widgets.add(
        SectionHeader(
          icon: Icons.calendar_today,
          title: _formatGroupLabel(group.date),
          trailing: MiniChip(
            label: group.items.length == 1
                ? '1 item'
                : '${group.items.length} itens',
            backgroundColor: colorScheme.surfaceContainerHighest,
            textColor: colorScheme.onSurfaceVariant,
            borderColor: colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
      );
      for (final account in group.items) {
        widgets.add(_buildAccountCard(context, account, group.date));
      }
    }
    return widgets;
  }

  Widget _buildAccountCard(BuildContext context, Account account, DateTime effectiveDate) {
    final colorScheme = Theme.of(context).colorScheme;
    final String? typeName = snapshot.typeNames[account.typeId]?.toLowerCase();
    final bool isCard = account.cardBrand != null || (typeName?.contains('cart') ?? false);
    final bool isRecurrent = account.isRecurrent || account.recurrenceId != null;
    final bool isRecebimento = typeName != null && typeName.contains('receb');
    final breakdown = isCard
        ? CardBreakdown.parse(account.observation)
        : const CardBreakdown(total: 0, installments: 0, oneOff: 0, subscriptions: 0);

    final double previstoValue = isCard
        ? breakdown.total
        : (isRecurrent && account.recurrenceId != null
            ? (account.estimatedValue ?? account.value)
            : account.value);
    final double? lancadoValue = (!isCard && isRecurrent && account.recurrenceId == null)
        ? null
        : account.value;
    final String lancadoDisplay = UtilBrasilFields.obterReal(lancadoValue ?? previstoValue);

    final bool isParentRecurrence = !isCard && isRecurrent && account.recurrenceId == null;
    final double? valorPrevisto = isCard
        ? (breakdown.total > 0.009 ? breakdown.total : null)
        : (account.estimatedValue ??
            (isParentRecurrence && account.value.abs() > 0.009 ? account.value : null));
    final double valorExibido = lancadoValue ?? previstoValue;
    final bool showEstimatedInCard = valorPrevisto != null &&
        valorPrevisto.abs() > 0.009 &&
        (isParentRecurrence || isCard || (valorExibido - valorPrevisto).abs() > 0.50);
    final String? estimatedDisplayForCard = showEstimatedInCard
        ? UtilBrasilFields.obterReal(valorPrevisto)
        : null;

    final cleanedDescription =
        cleanAccountDescription(account).replaceAll('Fatura: ', '').trim();
    final rawCategory = (account.categoryId != null)
        ? snapshot.categoryNames[account.categoryId!]
        : null;

    final bool hasRecebimentosSeparator = rawCategory?.contains('||') ?? false;
    String? parsedParentName;
    String? parsedChildName;
    if (hasRecebimentosSeparator && rawCategory != null) {
      final parts = rawCategory.split('||');
      if (parts.length >= 2) {
        parsedParentName = parts[0].trim();
        parsedChildName = parts[1].trim();
      }
    }

    final String? parentCategoryName = hasRecebimentosSeparator
        ? parsedParentName
        : ((account.categoryId != null)
            ? snapshot.categoryParentNames[account.categoryId!]
            : null);
    final bool hasParent = parentCategoryName != null;

    final String? childCategoryName = hasRecebimentosSeparator
        ? parsedChildName
        : rawCategory;

    String? parentCategoryLogo;
    if (hasParent) {
      parentCategoryLogo = DefaultAccountCategoriesService.categoryLogos[parentCategoryName];
      if (parentCategoryLogo == null && hasRecebimentosSeparator) {
        parentCategoryLogo =
            DefaultAccountCategoriesService.getLogoForRecebimentosPai(parentCategoryName);
      }
    }

    String? childCategoryLogo = (account.categoryId != null)
        ? snapshot.categoryLogos[account.categoryId!]
        : null;
    if (childCategoryLogo == null &&
        hasRecebimentosSeparator &&
        parsedParentName != null &&
        parsedChildName != null) {
      childCategoryLogo = DefaultAccountCategoriesService.getLogoForRecebimentosFilho(
        parsedParentName,
        parsedChildName,
      );
    }

    final String? typeDisplayName = snapshot.typeNames[account.typeId];
    final String? typeEmoji = (typeDisplayName != null)
        ? DefaultAccountCategoriesService.categoryLogos[typeDisplayName]
        : null;

    final String? categoryParentForTitle = hasParent
        ? parentCategoryName
        : (hasRecebimentosSeparator ? parsedParentName : typeDisplayName);

    String? titleEmoji;
    if (hasParent && parentCategoryLogo != null) {
      titleEmoji = parentCategoryLogo;
    } else if (hasRecebimentosSeparator && parentCategoryLogo != null) {
      titleEmoji = parentCategoryLogo;
    } else if (!hasParent && !hasRecebimentosSeparator && typeEmoji != null) {
      titleEmoji = typeEmoji;
    } else if (isCard) {
      titleEmoji = '💳';
    }

    String? subtitleEmoji;
    if (account.logo?.trim().isNotEmpty == true) {
      subtitleEmoji = account.logo!.trim();
    } else if (childCategoryLogo != null) {
      subtitleEmoji = childCategoryLogo;
    } else if (isCard) {
      subtitleEmoji = '💳';
    }

    final sanitizedCategoryChild = (childCategoryName ?? rawCategory)
        ?.replaceAll(RegExp(r'^Fatura:\s*'), '')
        .trim();
    final fallbackDescription = (cleanedDescription.isNotEmpty
            ? cleanedDescription
            : account.description)
        .trim();
    final childLabel = sanitizedCategoryChild?.isNotEmpty == true
        ? sanitizedCategoryChild!
        : fallbackDescription;
    final String cardBankLabel = (account.cardBank ?? '').trim();
    final String cardBrandLabel = (account.cardBrand ?? '').trim();
    final String middleLineText = isCard
        ? (cardBankLabel.isNotEmpty && cardBrandLabel.isNotEmpty
            ? '$cardBankLabel - $cardBrandLabel'
            : (cardBankLabel.isNotEmpty
                ? cardBankLabel
                : (cardBrandLabel.isNotEmpty
                    ? cardBrandLabel
                    : fallbackDescription)))
        : (() {
            final desc = fallbackDescription;
            if (desc.isEmpty) return childLabel;
            final childLower = childLabel.toLowerCase();
            final descLower = desc.toLowerCase();
            if (childLower == descLower || childLower.contains(descLower)) {
              return childLabel;
            }
            return '$childLabel - $desc';
          })();
    final bool isPaid = account.id != null && snapshot.paymentInfo.containsKey(account.id!);

    DateTime cardNextDueDate = DateTime.now();
    if (isCard) {
      final currentYear = account.year ?? effectiveDate.year;
      final currentMonth = account.month ?? effectiveDate.month;
      int nextMonth = currentMonth + 1;
      int nextYear = currentYear;
      if (nextMonth > 12) {
        nextMonth = 1;
        nextYear += 1;
      }
      int day = account.dueDay;
      final maxDay = DateUtils.getDaysInMonth(nextYear, nextMonth);
      if (day > maxDay) day = maxDay;
      cardNextDueDate = DateTime(nextYear, nextMonth, day);
    }
    final String cardNextDueLabel = DateFormat('dd/MM').format(cardNextDueDate);
    final bool hasRecurrence = account.isRecurrent || account.recurrenceId != null;

    final installmentDisplay = resolveInstallmentDisplay(account);
    final Color parceladoFillColor =
        isRecebimento ? Colors.green.shade600 : Colors.red.shade600;
    final bool isSinglePayment =
        !hasRecurrence && !installmentDisplay.isInstallment && !isCard;
    final Widget installmentBadge = MiniChip(
      label: installmentDisplay.labelText,
      textColor: parceladoFillColor,
    );
    final Widget singlePaymentBadge = const MiniChip(label: 'Parcela única');

    final List<Widget> chips = [];
    final String? accountTypeName = snapshot.typeNames[account.typeId];
    final bool titleIsAccountType = categoryParentForTitle == null;
    if (accountTypeName != null && accountTypeName.isNotEmpty && !titleIsAccountType) {
      chips.add(MiniChip(
        label: accountTypeName,
        backgroundColor: colorScheme.surfaceContainerHighest,
        textColor: colorScheme.onSurfaceVariant,
        borderColor: colorScheme.outlineVariant.withValues(alpha: 0.6),
      ));
    }
    final bool categoryInSubtitle = sanitizedCategoryChild != null &&
        (middleLineText == sanitizedCategoryChild ||
            middleLineText.toLowerCase().contains(sanitizedCategoryChild.toLowerCase()));
    if (sanitizedCategoryChild != null && sanitizedCategoryChild.isNotEmpty && !categoryInSubtitle) {
      chips.add(MiniChip(
        label: sanitizedCategoryChild,
        backgroundColor: colorScheme.surfaceContainerHighest,
        textColor: colorScheme.onSurfaceVariant,
        borderColor: colorScheme.outlineVariant.withValues(alpha: 0.6),
      ));
    }
    final List<Widget> stateChips = [];
    if (isPaid) {
      stateChips.add(MiniChip(
        label: isRecebimento ? 'Recebido' : 'Pago',
        icon: Icons.check_circle,
        iconColor: app_tokens.AppColors.textSecondary,
      ));
    }
    if (isSinglePayment) {
      stateChips.add(singlePaymentBadge);
    }
    if (hasRecurrence && !isCard) {
      stateChips.add(const MiniChip(label: 'Recorrência'));
    }
    if (installmentDisplay.isInstallment) {
      stateChips.add(installmentBadge);
      if (account.month != null && account.year != null) {
        final int remainingInstallments = installmentDisplay.total - installmentDisplay.index;
        final DateTime endDate =
            DateTime(account.year!, account.month! + remainingInstallments, account.dueDay);
        stateChips.add(MiniChip(
          label: 'Término: ${DateFormat('MM/yy').format(endDate)}',
          backgroundColor: colorScheme.surfaceContainerHighest,
          textColor: colorScheme.onSurfaceVariant,
          borderColor: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ));
      }
    }
    if (isCard) {
      stateChips.add(MiniChip(label: 'Próx.: $cardNextDueLabel'));
    }
    final int remaining = 3 - chips.length;
    if (remaining > 0) {
      chips.addAll(stateChips.take(remaining));
    }

    final Color accentColor = isRecebimento
        ? app_tokens.AppColors.success
        : (isCard ? app_tokens.AppColors.primary : app_tokens.AppColors.error);
    final Color valueColor = accentColor;

    final Color borderColor = colorScheme.outlineVariant.withValues(alpha: 0.6);
    final Color baseTint = Color.alphaBlend(
      accentColor.withValues(alpha: 0.04),
      colorScheme.surface,
    );
    final Color effectiveCardColor = baseTint;
    final List<BoxShadow> boxShadows = const [
      BoxShadow(
        color: Colors.transparent,
        blurRadius: 0,
        offset: Offset(0, 0),
      ),
    ];

    final String dayLabel = effectiveDate.day.toString().padLeft(2, '0');
    final String weekdayLabel = DateFormat('EEE', 'pt_BR')
        .format(effectiveDate)
        .replaceAll('.', '')
        .toUpperCase();

    return Opacity(
      opacity: isPaid ? 0.6 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: AppSpacing.lg),
        child: EntryCard(
          datePill: DatePill(
            day: dayLabel,
            weekday: weekdayLabel,
            accentColor: accentColor,
          ),
          titleEmoji: titleEmoji,
          subtitleEmoji: subtitleEmoji,
          subtitleIcon: isCard ? _buildCardBrandIcon(account.cardBrand) : null,
          title: categoryParentForTitle ?? snapshot.typeNames[account.typeId] ?? 'Outro',
          subtitle: middleLineText,
          value: lancadoDisplay,
          valueColor: valueColor,
          chips: chips,
          accentColor: accentColor,
          backgroundColor: effectiveCardColor,
          borderColor: borderColor,
          boxShadow: boxShadows,
          padding: const EdgeInsets.all(AppSpacing.lg),
          estimatedValue: estimatedDisplayForCard,
        ),
      ),
    );
  }

  Widget? _buildCardBrandIcon(String? brand) {
    final normalized = (brand ?? '').trim().toUpperCase();
    if (normalized.isEmpty) return null;

    String? assetPath;
    if (normalized == 'VISA') {
      assetPath = 'assets/icons/cc_visa.png';
    } else if (normalized == 'AMEX' ||
        normalized == 'AMERICAN EXPRESS' ||
        normalized == 'AMERICANEXPRESS') {
      assetPath = 'assets/icons/cc_amex.png';
    } else if (normalized == 'MASTER' ||
        normalized == 'MASTERCARD' ||
        normalized == 'MASTER CARD') {
      assetPath = 'assets/icons/cc_mc.png';
    } else if (normalized == 'ELO') {
      assetPath = 'assets/icons/cc_elo.png';
    }

    if (assetPath != null) {
      return Image.asset(
        assetPath,
        package: 'finance_app',
        fit: BoxFit.contain,
      );
    }

    return null;
  }

  String _formatGroupLabel(DateTime date) {
    final dateLabel = DateFormat('dd/MM/yyyy').format(date);
    final dayOfWeek = DateFormat('EEEE', 'pt_BR').format(date).toUpperCase();
    return '$dateLabel • $dayOfWeek';
  }

  Widget _buildMonthNavBar(BuildContext context) {
    final isCompact = snapshot.compactModeEnabled;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: PeriodHeader(
            label: snapshot.periodHeaderLabel,
            onPrevious: () {},
            onNext: () {},
            onTap: () {},
          ),
        ),
        IconButton(
          icon: Icon(
            isCompact ? Icons.unfold_more_rounded : Icons.unfold_less_rounded,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
          onPressed: () {},
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
