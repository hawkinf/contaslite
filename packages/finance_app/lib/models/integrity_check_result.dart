class IntegrityCheckResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final DateTime checkedAt;
  final Map<String, dynamic> details;

  IntegrityCheckResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    DateTime? checkedAt,
    Map<String, dynamic>? details,
  })  : checkedAt = checkedAt ?? DateTime.now(),
        details = details ?? {};

  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasIssues => hasErrors || hasWarnings;

  String get summary {
    if (isValid && !hasIssues) {
      return 'Banco de dados íntegro';
    } else if (hasErrors) {
      return 'Banco de dados corrompido (${errors.length} erros)';
    } else if (hasWarnings) {
      return 'Banco de dados com avisos (${warnings.length} avisos)';
    }
    return 'Status desconhecido';
  }

  @override
  String toString() {
    final sb = StringBuffer();
    sb.writeln('IntegrityCheckResult:');
    sb.writeln('  isValid: $isValid');
    sb.writeln('  checkedAt: ${checkedAt.toIso8601String()}');
    if (errors.isNotEmpty) {
      sb.writeln('  Erros (${errors.length}):');
      for (final error in errors) {
        sb.writeln('    - $error');
      }
    }
    if (warnings.isNotEmpty) {
      sb.writeln('  Avisos (${warnings.length}):');
      for (final warning in warnings) {
        sb.writeln('    - $warning');
      }
    }
    return sb.toString();
  }
}
