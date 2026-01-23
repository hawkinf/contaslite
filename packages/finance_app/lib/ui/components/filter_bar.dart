import 'package:flutter/material.dart';
import '../widgets/account_filters.dart';

export '../widgets/account_filters.dart' show AccountFilterType;

class FilterBar extends StatelessWidget {
  final AccountFilterType selected;
  final ValueChanged<AccountFilterType> onSelected;
  final bool showPaid;
  final ValueChanged<bool> onShowPaidChanged;
  final String periodValue;
  final ValueChanged<String> onPeriodChanged;

  const FilterBar({
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
    return AccountFilters(
      selected: selected,
      onSelected: onSelected,
      showPaid: showPaid,
      onShowPaidChanged: onShowPaidChanged,
      periodValue: periodValue,
      onPeriodChanged: onPeriodChanged,
    );
  }
}
