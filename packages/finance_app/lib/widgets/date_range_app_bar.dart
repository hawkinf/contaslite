import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:finance_app/services/prefs_service.dart';
import 'package:finance_app/services/holiday_service.dart';

class DateRangeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final DateTimeRange range;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final String? title;
  final String? city;
  final List<Widget>? actions;
  final Widget? leading;
  final bool? centerTitle;
  final double? toolbarHeight;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final TextStyle? titleStyle;
  final TextStyle? monthStyle;

  const DateRangeAppBar({
    super.key,
    required this.range,
    required this.onPrevious,
    required this.onNext,
    this.title,
    this.city,
    this.actions,
    this.leading,
    this.centerTitle,
    this.toolbarHeight,
    this.backgroundColor,
    this.foregroundColor,
    this.titleStyle,
    this.monthStyle,
  });

  @override
  Size get preferredSize =>
      PrefsService.embeddedMode && title == null
          ? Size.zero
          : Size.fromHeight(
              toolbarHeight ?? (title == null ? 100 : 110),
            );

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

  ({DateTime date, String name, int daysUntil}) _getNextHoliday(DateTime from) {
    DateTime current = from;
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
    if (PrefsService.embeddedMode && title == null) {
      return const SizedBox.shrink();
    }

    final defaultTitleStyle = titleStyle ??
        const TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

    if (PrefsService.embeddedMode) {
      return AppBar(
        centerTitle: centerTitle ?? true,
        toolbarHeight: toolbarHeight ?? kToolbarHeight,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        leading: leading,
        title: Text(
          title ?? '',
          style: defaultTitleStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: actions,
      );
    }

    final monthLabel =
        DateFormat('MMMM yyyy', 'pt_BR').format(range.start).toUpperCase();
    final defaultMonthStyle = monthStyle ??
        const TextStyle(fontSize: 24, fontWeight: FontWeight.bold);

    final nextHoliday = _getNextHoliday(range.start);
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
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Text(
              title!,
              style: defaultTitleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 28),
                onPressed: onPrevious,
                tooltip: 'Mês anterior',
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    monthLabel,
                    style: defaultMonthStyle,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 28),
                onPressed: onNext,
                tooltip: 'Próximo mês',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.shade400,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              holidayLabel,
              style: const TextStyle(
                fontSize: 11,
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
