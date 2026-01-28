import 'package:flutter/material.dart';
import '../models/account.dart';
import '../ui/widgets/account_filters.dart';

class ContasDayGroupSnapshot {
  final DateTime date;
  final List<Account> items;

  const ContasDayGroupSnapshot({
    required this.date,
    required this.items,
  });
}

class ContasViewStateSnapshot {
  final DateTimeRange dateRange;
  final DateTime anchorDate;
  final String periodLabel;
  final String periodHeaderLabel;
  final String periodFilterValue;
  final String filterLabel;
  final AccountFilterType filterType;
  final bool isCombinedView;
  final bool compactModeEnabled;
  final bool useCompactSummaryCards;
  final bool hidePaidAccounts;
  final List<ContasDayGroupSnapshot> groups;
  final double totalPeriod;
  final double totalForecast;
  final double totalLancadoPagar;
  final double totalLancadoReceber;
  final double totalPrevistoPagar;
  final double totalPrevistoReceber;
  final String totalLabel;
  final Color totalColor;
  final Map<int, String> typeNames;
  final Map<int, String> categoryNames;
  final Map<int, String> categoryParentNames;
  final Map<int, String> categoryLogos;
  final Map<int, Map<String, dynamic>> paymentInfo;

  const ContasViewStateSnapshot({
    required this.dateRange,
    required this.anchorDate,
    required this.periodLabel,
    required this.periodHeaderLabel,
    required this.periodFilterValue,
    required this.filterLabel,
    required this.filterType,
    required this.isCombinedView,
    required this.compactModeEnabled,
    required this.useCompactSummaryCards,
    required this.hidePaidAccounts,
    required this.groups,
    required this.totalPeriod,
    required this.totalForecast,
    required this.totalLancadoPagar,
    required this.totalLancadoReceber,
    required this.totalPrevistoPagar,
    required this.totalPrevistoReceber,
    required this.totalLabel,
    required this.totalColor,
    required this.typeNames,
    required this.categoryNames,
    required this.categoryParentNames,
    required this.categoryLogos,
    required this.paymentInfo,
  });
}
