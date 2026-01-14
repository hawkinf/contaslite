import 'package:intl/intl.dart';
import 'package:brasil_fields/brasil_fields.dart';

class CurrencyFormatter {
  static final _formatter = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  /// Formata double para moeda brasileira
  static String format(double value) {
    return _formatter.format(value);
  }

  /// Converte string em formato brasileiro para double
  static double parse(String value) {
    try {
      return UtilBrasilFields.converterMoedaParaDouble(value);
    } catch (e) {
      return 0.0;
    }
  }

  /// Formata para exibição compacta (ex: 1.5K, 2.3M)
  static String formatCompact(double value) {
    if (value >= 1000000) {
      return 'R\$ ${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return 'R\$ ${(value / 1000).toStringAsFixed(1)}K';
    }
    return format(value);
  }
}

class DateFormatter {
  static final _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  static final _monthYearFormat = DateFormat('MMMM yyyy', 'pt_BR');

  /// Formata data no formato dd/MM/yyyy
  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  /// Formata data e hora
  static String formatDateTime(DateTime date) {
    return _dateTimeFormat.format(date);
  }

  /// Formata mês e ano por extenso
  static String formatMonthYear(DateTime date) {
    String formatted = _monthYearFormat.format(date);
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  /// Converte string dd/MM/yyyy ou dd/MM para DateTime
  /// Se apenas dd/MM for fornecido, usa o ano corrente
  static DateTime? parseDate(String dateStr) {
    try {
      final trimmed = dateStr.trim();
      // Se tem menos de 10 caracteres, pode ser dd/MM
      if (trimmed.length <= 5) {
        final parts = trimmed.split('/');
        if (parts.length == 2) {
          final day = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          if (day != null && month != null) {
            final currentYear = DateTime.now().year;
            return DateTime(currentYear, month, day);
          }
        }
      }
      return UtilData.obterDateTime(dateStr);
    } catch (e) {
      return null;
    }
  }
  
  /// Normaliza string de data para dd/MM/yyyy, completando com ano corrente se necessário
  static String normalizeDate(String dateStr) {
    final trimmed = dateStr.trim();
    final parts = trimmed.split('/');
    
    if (parts.length == 2) {
      // dd/MM -> dd/MM/yyyy (ano corrente)
      final day = parts[0].padLeft(2, '0');
      final month = parts[1].padLeft(2, '0');
      final currentYear = DateTime.now().year;
      return '$day/$month/$currentYear';
    } else if (parts.length == 3 && parts[2].length == 2) {
      // dd/MM/yy -> dd/MM/20yy
      final day = parts[0].padLeft(2, '0');
      final month = parts[1].padLeft(2, '0');
      final year = '20${parts[2]}';
      return '$day/$month/$year';
    }
    
    return trimmed;
  }

  /// Retorna o primeiro dia do mês
  static DateTime firstDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// Retorna o último dia do mês
  static DateTime lastDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  /// Adiciona meses a uma data
  static DateTime addMonths(DateTime date, int months) {
    return DateTime(date.year, date.month + months, date.day);
  }

  /// Calcula dias entre duas datas
  static int daysBetween(DateTime from, DateTime to) {
    from = DateTime(from.year, from.month, from.day);
    to = DateTime(to.year, to.month, to.day);
    return to.difference(from).inDays;
  }
}

class ValidationHelper {
  /// Valida se o valor é um número válido
  static bool isValidNumber(String value) {
    if (value.isEmpty) return false;
    try {
      CurrencyFormatter.parse(value);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Valida se a data está no formato correto
  static bool isValidDate(String dateStr) {
    return DateFormatter.parseDate(dateStr) != null;
  }

  /// Valida se o texto não está vazio
  static bool isNotEmpty(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}
