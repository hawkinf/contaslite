class HolidayService {
  static const Map<String, List<String>> regions = {
    'Vale do Paraíba': [
      'Aparecida', 'Arapeí', 'Areias', 'Bananal', 'Caçapava', 'Cachoeira Paulista', 
      'Campos do Jordão', 'Canas', 'Cruzeiro', 'Cunha', 'Guaratinguetá', 'Igaratá', 
      'Jacareí', 'Jambeiro', 'Lagoinha', 'Lavrinhas', 'Lorena', 'Monteiro Lobato', 
      'Natividade da Serra', 'Paraibuna', 'Pindamonhangaba', 'Piquete', 'Potim', 
      'Queluz', 'Redenção da Serra', 'Roseira', 'Santa Branca', 'Santo Antônio do Pinhal', 
      'São Bento do Sapucaí', 'São José do Barreiro', 'São José dos Campos', 
      'São Luiz do Paraitinga', 'Silveiras', 'Taubaté', 'Tremembé',
    ],
    'Litoral Norte': ['Caraguatatuba', 'Ilhabela', 'São Sebastião', 'Ubatuba'],
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

    // Exemplos simples de Feriados Municipais
    if (city == 'São José dos Campos' && date.day == 27 && date.month == 7) return true;
    if (city == 'Taubaté' && date.day == 5 && date.month == 12) return true;
    if (city == 'Caraguatatuba' && date.day == 20 && date.month == 4) return true;

    return false;
  }

  static bool isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  /// Retorna um objeto com a data ajustada e a mensagem de aviso (se houver)
  static ({DateTime date, String? warning}) adjustDateToBusinessDay(DateTime originalDate, String city) {
    DateTime adjusted = originalDate;
    bool changed = false;

    // Avança para o próximo dia útil
    while (isWeekend(adjusted) || isHoliday(adjusted, city)) {
      adjusted = adjusted.add(const Duration(days: 1));
      changed = true;
    }

    if (changed) {
      // Verifica o motivo (Feriado ou Fim de Semana)
      String reason = isHoliday(originalDate, city) ? 'Feriado' : 'Final de Semana';
      // Se for os dois, prioriza Feriado na mensagem ou concatena
      if (isWeekend(originalDate) && isHoliday(originalDate, city)) reason = 'Feriado/Fim de Semana';
      
      return (
        date: adjusted,
        warning: '(Data Original: ${originalDate.day}/${originalDate.month}/${originalDate.year} - $reason)'
      );
    }

    return (date: adjusted, warning: null);
  }
}