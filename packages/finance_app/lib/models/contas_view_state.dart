import 'package:flutter/material.dart';

import 'account.dart';

class ContasDayGroup {
  final DateTime date;
  final List<Account> items;

  const ContasDayGroup({
    required this.date,
    required this.items,
  });
}

class ContasViewState {
  final DateTimeRange dateRange;
  final DateTime anchorDate;
  final String periodLabel;
  final String periodFilterLabel;
  final String filterLabel;
  final bool hidePaidAccounts;
  final String? additionalFiltersLabel;
  final String? city;
  final List<ContasDayGroup> groups;
  final double totalLancadoPagar;
  final double totalLancadoReceber;
  final double totalPrevistoPagar;
  final double totalPrevistoReceber;
  final Map<int, String> typeNames;
  final Map<int, String> categoryNames;
  final Map<int, String> categoryParentNames;
  final Map<int, Map<String, dynamic>> paymentInfo;

  const ContasViewState({
    required this.dateRange,
    required this.anchorDate,
    required this.periodLabel,
    required this.periodFilterLabel,
    required this.filterLabel,
    required this.hidePaidAccounts,
    required this.additionalFiltersLabel,
    required this.city,
    required this.groups,
    required this.totalLancadoPagar,
    required this.totalLancadoReceber,
    required this.totalPrevistoPagar,
    required this.totalPrevistoReceber,
    required this.typeNames,
    required this.categoryNames,
    required this.categoryParentNames,
    required this.paymentInfo,
  });
}
