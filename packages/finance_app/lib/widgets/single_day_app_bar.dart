import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:finance_app/services/prefs_service.dart';
import 'package:finance_app/services/holiday_service.dart';

class SingleDayAppBar extends StatelessWidget implements PreferredSizeWidget {
  final DateTime date;
  final String? city;
  final List<Widget>? actions;
  final Widget? leading;
  final bool? centerTitle;
  final double? toolbarHeight;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final TextStyle? titleStyle;

  const SingleDayAppBar({
    super.key,
    required this.date,
    this.city,
    this.actions,
    this.leading,
    this.centerTitle,
    this.toolbarHeight,
    this.backgroundColor,
    this.foregroundColor,
    this.titleStyle,
  });

  @override
  Size get preferredSize =>
      PrefsService.embeddedMode ? Size.zero : Size.fromHeight(toolbarHeight ?? 80);

  // Retorna o nome do feriado para uma data específica
  String _getHolidayName(DateTime date) {
    if (date.day == 1 && date.month == 1) return 'Ano Novo';
    if (date.day == 21 && date.month == 4) return 'Tiradentes';
    if (date.day == 1 && date.month == 5) return 'Dia do Trabalho';
    if (date.day == 7 && date.month == 9) return 'Independência';
    if (date.day == 12 && date.month == 10) return 'Nossa Senhora Aparecida';
    if (date.day == 2 && date.month == 11) return 'Finados';
    if (date.day == 15 && date.month == 11) return 'Proclamação da República';
    if (date.day == 25 && date.month == 12) return 'Natal';
    if (city == 'São José dos Campos' && date.day == 27 && date.month == 7) return 'Dia de São José';
    if (city == 'Taubaté' && date.day == 5 && date.month == 12) return 'Dia de Taubaté';
    return 'Feriado';
  }

  // Calcula o próximo feriado a partir da data atual
  ({DateTime date, String name, int daysUntil}) _getNextHoliday(DateTime from) {
    DateTime current = from;
    // Procura no máximo 365 dias
    for (int i = 0; i < 365; i++) {
      current = current.add(const Duration(days: 1));
      if (HolidayService.isHoliday(current, city ?? '')) {
        return (date: current, name: _getHolidayName(current), daysUntil: i + 1);
      }
    }
    return (date: DateTime(2099), name: 'Sem feriado próximo', daysUntil: 365);
  }

  @override
  Widget build(BuildContext context) {
    if (PrefsService.embeddedMode) {
      return const SizedBox.shrink();
    }

    final formatter = DateFormat('dd MMMM yyyy', 'pt_BR');
    final weekdayFormatter = DateFormat('EEEE', 'pt_BR');
    final label = formatter.format(date);
    final weekday = weekdayFormatter.format(date);
    final weekdayLabel = weekday.substring(0, 1).toUpperCase() + weekday.substring(1);
    final style = titleStyle ??
        const TextStyle(fontSize: 18, fontWeight: FontWeight.bold);

    final nextHoliday = _getNextHoliday(date);
    final daysText = nextHoliday.daysUntil == 1
        ? 'Falta 1 dia'
        : 'Faltam ${nextHoliday.daysUntil} dias';
    final holidayLabel = '${nextHoliday.name} - $daysText';

    return AppBar(
      centerTitle: centerTitle ?? true,
      toolbarHeight: preferredSize.height,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      leading: leading,
      title: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$label - $weekdayLabel',
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.shade400,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              holidayLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: actions,
    );
  }
}
