import '../models/account.dart';

final RegExp installmentSuffixRegex = RegExp(r'\s*\((\d+)/(\d+)\)$');

String cleanInstallmentDescription(String description) {
  final match = installmentSuffixRegex.firstMatch(description);
  if (match != null) {
    return description.substring(0, match.start).trim();
  }
  return description;
}

String cleanAccountDescription(Account account) => cleanInstallmentDescription(account.description);

({int index, int total})? _parseLegacyInfo(String description) {
  final match = installmentSuffixRegex.firstMatch(description);
  if (match == null) return null;
  final index = int.tryParse(match.group(1)!);
  final total = int.tryParse(match.group(2)!);
  if (index == null || total == null || total <= 0) return null;
  return (index: index, total: total);
}

class InstallmentDisplay {
  final int index;
  final int total;
  final bool isRecurrent;

  const InstallmentDisplay({required this.index, required this.total, this.isRecurrent = false});

  bool get isInstallment => total > 1;

  String get badgeText {
    if (isRecurrent) return 'Recorrência';
    return isInstallment ? '$index/$total' : 'À vista';
  }

  String get labelText {
    if (isRecurrent) return 'Recorrência';
    return isInstallment ? 'Parcela $index/$total' : 'À vista';
  }
}

InstallmentDisplay resolveInstallmentDisplay(Account account) {
  final isRecurrent = account.isRecurrent || account.recurrenceId != null;
  
  final totalMeta = account.installmentTotal;
  final indexMeta = account.installmentIndex;
  if (totalMeta != null && totalMeta > 0) {
    final safeTotal = totalMeta;
    int safeIndex = indexMeta ?? 1;
    if (safeIndex < 1 || safeIndex > safeTotal) safeIndex = 1;
    return InstallmentDisplay(index: safeIndex, total: safeTotal, isRecurrent: isRecurrent);
  }

  final legacy = _parseLegacyInfo(account.description);
  if (legacy != null) {
    final idx = legacy.index < 1 ? 1 : legacy.index;
    final total = legacy.total < 1 ? 1 : legacy.total;
    return InstallmentDisplay(index: idx, total: total, isRecurrent: isRecurrent);
  }

  return InstallmentDisplay(index: 1, total: 1, isRecurrent: isRecurrent);
}

bool hasInstallmentMetadata(Account account) => account.installmentTotal != null && account.installmentTotal! > 1;

