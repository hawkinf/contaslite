import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:finance_app/services/prefs_service.dart';
import 'package:finance_app/services/holiday_service.dart';

class SingleDayAppBar extends StatelessWidget implements PreferredSizeWidget {
  final DateTime date;
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

  // Calcula o próximo feriado a partir da data atual
  String _getNextHolidayInfo(DateTime currentDate) {
    try {
      final city = PrefsService.cityNotifier.value;

      // Procurar pelo próximo feriado nos próximos 365 dias
      for (int i = 0; i < 365; i++) {
        final checkDate = currentDate.add(Duration(days: i));
        if (HolidayService.isHoliday(checkDate, city)) {
          final daysUntil = i;

          // Obter nome do feriado (meses fixos)
          String holidayName = '';
          if (checkDate.day == 1 && checkDate.month == 1) {
            holidayName = 'Ano Novo';
          } else if (checkDate.day == 21 && checkDate.month == 4) {
            holidayName = 'Tiradentes';
          } else if (checkDate.day == 1 && checkDate.month == 5) {
            holidayName = 'Dia do Trabalho';
          } else if (checkDate.day == 7 && checkDate.month == 9) {
            holidayName = 'Independência';
          } else if (checkDate.day == 12 && checkDate.month == 10) {
            holidayName = 'Nossa Senhora Aparecida';
          } else if (checkDate.day == 2 && checkDate.month == 11) {
            holidayName = 'Finados';
          } else if (checkDate.day == 15 && checkDate.month == 11) {
            holidayName = 'Proclamação da República';
          } else if (checkDate.day == 25 && checkDate.month == 12) {
            holidayName = 'Natal';
          } else if (city == 'São José dos Campos' && checkDate.day == 27 && checkDate.month == 7) {
            holidayName = 'Fundação de SJC';
          } else if (city == 'Taubaté' && checkDate.day == 5 && checkDate.month == 12) {
            holidayName = 'Fundação de Taubaté';
          }

          if (holidayName.isEmpty) return '';

          if (daysUntil == 0) {
            return '🎉 Hoje: $holidayName';
          } else if (daysUntil == 1) {
            return '⏰ Amanhã: $holidayName';
          } else {
            return '📅 $holidayName em $daysUntil dias';
          }
        }
      }

      return '';
    } catch (e) {
      return '';
    }
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

    final nextHolidayInfo = _getNextHolidayInfo(date);

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
          if (nextHolidayInfo.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              nextHolidayInfo,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      actions: actions,
    );
  }
}
