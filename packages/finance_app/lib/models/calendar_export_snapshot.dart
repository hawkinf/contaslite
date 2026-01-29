import '../ui/components/ff_design_system.dart';
import 'account.dart';

/// Item de agenda para exportação do calendário
class CalendarAgendaItem {
  /// Conta/lançamento
  final Account account;

  /// Data efetiva (com ajuste de feriados)
  final DateTime effectiveDate;

  /// Se é um recebimento
  final bool isRecebimento;

  /// Se é cartão de crédito
  final bool isCard;

  /// Se é recorrente
  final bool isRecurrent;

  /// Se é previsão (recorrente não lançado)
  final bool isPrevisao;

  /// Valor para exibição (considera estimatedValue)
  final double displayValue;

  /// Nome do tipo
  final String? typeName;

  const CalendarAgendaItem({
    required this.account,
    required this.effectiveDate,
    required this.isRecebimento,
    required this.isCard,
    required this.isRecurrent,
    required this.isPrevisao,
    required this.displayValue,
    this.typeName,
  });
}

/// Célula de dia para o grid mensal
class CalendarDayCellModel {
  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final bool isWeekend;
  final bool isHoliday;
  final String? holidayName;
  final bool isOutsideMonth;
  final FFDayTotals totals;

  const CalendarDayCellModel({
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.isWeekend,
    required this.isHoliday,
    this.holidayName,
    required this.isOutsideMonth,
    required this.totals,
  });
}

/// Modelo para dia na view semanal
class CalendarWeekDayModel {
  final DateTime date;
  final String dayName;
  final bool isToday;
  final bool isWeekend;
  final FFDayTotals totals;

  const CalendarWeekDayModel({
    required this.date,
    required this.dayName,
    required this.isToday,
    required this.isWeekend,
    required this.totals,
  });
}

/// Modelo para mês na view anual
class CalendarMiniMonthModel {
  final int month;
  final int year;
  final String monthName;
  final bool isCurrentMonth;
  final FFPeriodTotals totals;

  const CalendarMiniMonthModel({
    required this.month,
    required this.year,
    required this.monthName,
    required this.isCurrentMonth,
    required this.totals,
  });
}

/// Snapshot do estado do calendário para exportação visual.
///
/// Contém todos os dados necessários para renderizar o calendário
/// sem precisar recalcular nada durante a exportação.
class CalendarExportSnapshot {
  /// Modo de visualização (weekly/monthly/yearly)
  final FFCalendarViewMode mode;

  /// Densidade do calendário
  final FFCalendarDensity density;

  /// Data âncora (mês/semana/ano focado)
  final DateTime anchorDate;

  /// Data selecionada
  final DateTime selectedDate;

  /// Label do período (ex: "Janeiro 2026", "Semana 27/01-02/02", "2026")
  final String periodLabel;

  /// Totais do período
  final FFPeriodTotals periodTotals;

  /// Células do mês (para modo mensal) - 42 dias (6 semanas)
  final List<CalendarDayCellModel> monthCells;

  /// Dias da semana (para modo semanal) - 7 dias
  final List<CalendarWeekDayModel> weekDays;

  /// Meses do ano (para modo anual) - 12 meses
  final List<CalendarMiniMonthModel> yearMonths;

  /// Itens da agenda (do dia selecionado ou período)
  final List<CalendarAgendaItem> agendaItems;

  /// Mapa de nomes de tipos por ID
  final Map<int, String> typeNames;

  const CalendarExportSnapshot({
    required this.mode,
    required this.density,
    required this.anchorDate,
    required this.selectedDate,
    required this.periodLabel,
    required this.periodTotals,
    required this.monthCells,
    required this.weekDays,
    required this.yearMonths,
    required this.agendaItems,
    required this.typeNames,
  });

  /// Verifica se há agenda para exibir
  bool get hasAgenda => agendaItems.isNotEmpty;

  /// Título da agenda formatado
  String get agendaTitle {
    final day = selectedDate.day.toString().padLeft(2, '0');
    final month = selectedDate.month.toString().padLeft(2, '0');
    final year = selectedDate.year;
    return 'Itens do dia $day/$month/$year';
  }
}
