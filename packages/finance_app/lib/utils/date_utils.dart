// Utilitários de data para o FácilFin
// Funções para normalizar datas e calcular início de semana/mês/ano

class AppDateUtils {
  /// Retorna a data de hoje normalizada para 00:00:00
  static DateTime today0() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Retorna o início da semana para uma data
  /// [mondayStart] se true, semana começa na segunda; se false, no domingo
  static DateTime startOfWeek(DateTime date, {bool mondayStart = true}) {
    final d = DateTime(date.year, date.month, date.day);
    if (mondayStart) {
      // Segunda = 1, então subtraímos (weekday - 1) dias
      return d.subtract(Duration(days: d.weekday - 1));
    } else {
      // Domingo = 7, então subtraímos weekday % 7 dias
      return d.subtract(Duration(days: d.weekday % 7));
    }
  }

  /// Retorna o fim da semana para uma data (6 dias após o início)
  static DateTime endOfWeek(DateTime date, {bool mondayStart = true}) {
    return startOfWeek(date, mondayStart: mondayStart).add(const Duration(days: 6));
  }

  /// Retorna o primeiro dia do mês
  static DateTime startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// Retorna o último dia do mês
  static DateTime endOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  /// Retorna o primeiro dia do ano
  static DateTime startOfYear(DateTime date) {
    return DateTime(date.year, 1, 1);
  }

  /// Retorna o último dia do ano
  static DateTime endOfYear(DateTime date) {
    return DateTime(date.year, 12, 31);
  }

  /// Retorna os ranges padrão para hoje
  static ({
    DateTime today,
    DateTime weekStart,
    DateTime weekEnd,
    DateTime monthStart,
    DateTime monthEnd,
    DateTime yearStart,
    DateTime yearEnd,
  }) getDefaultRanges({bool mondayStart = true}) {
    final t = today0();
    return (
      today: t,
      weekStart: startOfWeek(t, mondayStart: mondayStart),
      weekEnd: endOfWeek(t, mondayStart: mondayStart),
      monthStart: startOfMonth(t),
      monthEnd: endOfMonth(t),
      yearStart: startOfYear(t),
      yearEnd: endOfYear(t),
    );
  }
}
