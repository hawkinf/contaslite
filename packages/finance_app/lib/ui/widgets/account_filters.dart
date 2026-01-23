import 'package:flutter/material.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

enum AccountFilterType { all, pagar, receber, cartoes }

class AccountFilters extends StatelessWidget {
  final AccountFilterType selected;
  final ValueChanged<AccountFilterType> onSelected;
  final bool showPaid;
  final ValueChanged<bool> onShowPaidChanged;
  final String periodValue;
  final ValueChanged<String> onPeriodChanged;

  const AccountFilters({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.showPaid,
    required this.onShowPaidChanged,
    required this.periodValue,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChip(context, 'Todos', AccountFilterType.all),
                  const SizedBox(width: AppSpacing.sm),
                  _buildChip(context, 'Pagar', AccountFilterType.pagar),
                  const SizedBox(width: AppSpacing.sm),
                  _buildChip(context, 'Receber', AccountFilterType.receber),
                  const SizedBox(width: AppSpacing.sm),
                  _buildChip(context, 'Cartões', AccountFilterType.cartoes),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPaidChip(context),
                const SizedBox(width: AppSpacing.sm),
                _buildPeriodDropdown(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label, AccountFilterType type) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isSelected = selected == type;
    final Color textColor =
        isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant;
    return SizedBox(
      height: 30,
      child: ChoiceChip(
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        label: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
        ),
        selected: isSelected,
        showCheckmark: false,
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.primaryContainer,
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
        shape: const StadiumBorder(),
        onSelected: (_) => onSelected(type),
      ),
    );
  }

  Widget _buildPaidChip(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color textColor =
        showPaid ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant;
    return SizedBox(
      height: 30,
      child: ChoiceChip(
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off_outlined, size: 16, color: textColor),
            const SizedBox(width: 6),
            Text(
              'Contas Pagas',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
            ),
          ],
        ),
        selected: showPaid,
        showCheckmark: false,
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.primaryContainer,
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
        shape: const StadiumBorder(),
        onSelected: (value) => onShowPaidChanged(value),
      ),
    );
  }

  Widget _buildPeriodDropdown(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 32,
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: periodValue,
          isDense: true,
          isExpanded: true,
          onChanged: (value) {
            if (value != null) onPeriodChanged(value);
          },
          icon: Icon(Icons.arrow_drop_down, size: 18, color: colorScheme.onSurfaceVariant),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
          items: const [
            DropdownMenuItem(value: 'month', child: Text('Mês Atual')),
            DropdownMenuItem(value: 'currentWeek', child: Text('Semana Atual')),
            DropdownMenuItem(value: 'nextWeek', child: Text('Próx. Semana')),
          ],
        ),
      ),
    );
  }
}
