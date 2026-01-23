import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
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
    final bool isSelected = selected == type;
    final Color textColor = isSelected ? Colors.white : AppColors.textSecondary;
    return SizedBox(
      height: 34,
      child: ChoiceChip(
        labelPadding: const EdgeInsets.symmetric(horizontal: 10),
        label: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
        ),
        selected: isSelected,
        showCheckmark: false,
        backgroundColor: Colors.white,
        selectedColor: AppColors.primary,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        onSelected: (_) => onSelected(type),
      ),
    );
  }

  Widget _buildPaidChip(BuildContext context) {
    final Color textColor = showPaid ? Colors.white : AppColors.textSecondary;
    return SizedBox(
      height: 34,
      child: ChoiceChip(
        labelPadding: const EdgeInsets.symmetric(horizontal: 10),
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
        backgroundColor: Colors.white,
        selectedColor: AppColors.primary,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        onSelected: (value) => onShowPaidChanged(value),
      ),
    );
  }

  Widget _buildPeriodDropdown(BuildContext context) {
    return Container(
      height: 36,
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: periodValue,
          isDense: true,
          isExpanded: true,
          onChanged: (value) {
            if (value != null) onPeriodChanged(value);
          },
          icon: const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.textSecondary),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
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
