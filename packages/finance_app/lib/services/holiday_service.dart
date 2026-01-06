class HolidayService {
  static const Map<String, List<String>> regions = {
    'Vale do Paraíba': [
      'Aparecida',
      'Arapeí',
      'Areias',
      'Bananal',
      'Caçapava',
      'Cachoeira Paulista',
      'Campos do Jordão',
      'Canas',
      'Cruzeiro',
      'Cunha',
      'Guaratinguetá',
      'Igaratá',
      'Jacareí',
      'Jambeiro',
      'Lagoinha',
      'Lavrinhas',
      'Lorena',
      'Monteiro Lobato',
      'Natividade da Serra',
      'Paraibuna',
      'Pindamonhangaba',
      'Piquete',
      'Potim',
      'Queluz',
      'Redenção da Serra',
      'Roseira',
      'Santa Branca',
      'Santo Antônio do Pinhal',
      'São Bento do Sapucaí',
      'São José do Barreiro',
      'São José dos Campos',
      'São Luiz do Paraitinga',
      'Silveiras',
      'Taubaté',
      'Tremembé',
    ],
    'Litoral Norte': [
      'Caraguatatuba',
      'Ilhabela',
      'São Sebastião',
      'Ubatuba',
    ],
  };

  static bool isHoliday(DateTime date, String city) {
    if (date.day == 1 && date.month == 1) return true;
    if (date.day == 21 && date.month == 4) return true;
    if (date.day == 1 && date.month == 5) return true;
    if (date.day == 7 && date.month == 9) return true;
    if (date.day == 12 && date.month == 10) return true;
    if (date.day == 2 && date.month == 11) return true;
    if (date.day == 15 && date.month == 11) return true;
    if (date.day == 25 && date.month == 12) return true;

    // Exemplos simples de feriados municipais.
    if (city == 'São José dos Campos' && date.day == 27 && date.month == 7) return true;
    if (city == 'Taubaté' && date.day == 5 && date.month == 12) return true;

    return false;
  }

  static bool isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  /// Retorna o nome do dia da semana em português
  static String getDayName(int weekday) {
    const days = [
      '',
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado',
      'Domingo',
    ];
    return days[weekday];
  }

  /// Retorna o nome do mês em português
  static String getMonthName(int month) {
    const months = [
      '',
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return months[month];
  }

  /// Retorna uma lista com estatísticas de feriados por dia da semana
  static Map<String, int> getHolidaysByWeekday(int year) {
    final stats = {
      'Segunda': 0,
      'Terça': 0,
      'Quarta': 0,
      'Quinta': 0,
      'Sexta': 0,
      'Sábado': 0,
      'Domingo': 0,
    };

    // Feriados federais fixos
    final fixedHolidays = [
      (day: 1, month: 1),    // Ano Novo
      (day: 21, month: 4),   // Tiradentes
      (day: 1, month: 5),    // Dia do Trabalho
      (day: 7, month: 9),    // Independência
      (day: 12, month: 10),  // Nossa Senhora Aparecida
      (day: 2, month: 11),   // Finados
      (day: 15, month: 11),  // Proclamação da República
      (day: 25, month: 12),  // Natal
    ];

    for (var holiday in fixedHolidays) {
      final date = DateTime(year, holiday.month, holiday.day);
      final dayName = getDayName(date.weekday);
      stats[dayName] = (stats[dayName] ?? 0) + 1;
    }

    return stats;
  }

  /// Retorna uma lista formatada com detalhes dos feriados por dia da semana
  static List<String> getHolidayDetailsFormatted(int year) {
    final holidays = [
      (day: 1, month: 1, name: 'Ano Novo'),
      (day: 21, month: 4, name: 'Tiradentes'),
      (day: 1, month: 5, name: 'Dia do Trabalho'),
      (day: 7, month: 9, name: 'Independência'),
      (day: 12, month: 10, name: 'Nossa Senhora Aparecida'),
      (day: 2, month: 11, name: 'Finados'),
      (day: 15, month: 11, name: 'Proclamação da República'),
      (day: 25, month: 12, name: 'Natal'),
    ];

    final details = <String>[];
    for (var holiday in holidays) {
      final date = DateTime(year, holiday.month, holiday.day);
      final dayName = getDayName(date.weekday);
      final monthName = getMonthName(holiday.month);
      details.add(
        '${holiday.name}: $dayName, ${holiday.day} de $monthName',
      );
    }

    return details;
  }

  /// Retorna um resumo dos feriados por dia da semana
  static String getHolidaySummary(int year) {
    final stats = getHolidaysByWeekday(year);
    final buffer = StringBuffer();
    buffer.writeln('Feriados Nacionais em $year:');
    buffer.writeln('');

    stats.forEach((day, count) {
      buffer.writeln('$day: $count feriado${count > 1 ? 's' : ''}');
    });

    return buffer.toString();
  }

  /// Retorna um resumo detalhado dos feriados
  static String getDetailedHolidaySummary(int year) {
    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('   FERIADOS NACIONAIS - $year');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('');

    final details = getHolidayDetailsFormatted(year);
    for (var detail in details) {
      buffer.writeln('✓ $detail');
    }

    buffer.writeln('');
    buffer.writeln('Resumo por dia da semana:');
    buffer.writeln('');

    final stats = getHolidaysByWeekday(year);
    stats.forEach((day, count) {
      buffer.writeln('  $day: $count feriado${count > 1 ? 's' : ''}');
    });

    return buffer.toString();
  }

  /// Retorna um resumo completo com a distribuição por dia
  static Map<String, dynamic> getHolidayAnalysis(int year) {
    return {
      'year': year,
      'summary': getHolidaySummary(year),
      'detailed_summary': getDetailedHolidaySummary(year),
      'by_weekday': getHolidaysByWeekday(year),
      'details': getHolidayDetailsFormatted(year),
    };
  }

  /// Retorna um objeto com a data ajustada e a mensagem de aviso (se houver).
  static ({DateTime date, String? warning}) adjustDateToBusinessDay(
    DateTime originalDate,
    String city,
  ) {
    DateTime adjusted = originalDate;
    bool changed = false;

    // Avança para o próximo dia útil.
    while (isWeekend(adjusted) || isHoliday(adjusted, city)) {
      adjusted = adjusted.add(const Duration(days: 1));
      changed = true;
    }

    if (changed) {
      String reason = isHoliday(originalDate, city) ? 'Feriado' : 'Final de Semana';
      if (isWeekend(originalDate) && isHoliday(originalDate, city)) {
        reason = 'Feriado/Fim de Semana';
      }

      return (
        date: adjusted,
        warning: '(Data Original: ${originalDate.day}/${originalDate.month}/${originalDate.year} - $reason)',
      );
    }

    return (date: adjusted, warning: null);
  }
}
