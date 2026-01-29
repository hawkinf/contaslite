import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../../services/holiday_service.dart';
import '../../../services/prefs_service.dart';

/// Densidade do calendário compacto
enum FFCompactCalendarDensity {
  /// Regular (tileHeight: 36, fontSize: 12)
  regular,

  /// Compacto (tileHeight: 32, fontSize: 11)
  compact,

  /// Extra compacto (tileHeight: 28, fontSize: 10)
  extraCompact,
}

/// Calendário compacto do FácilFin Design System.
///
/// Projetado para caber em espaços limitados sem scroll.
/// Usa tiles menores e espaçamento reduzido.
class FFCompactCalendar extends StatelessWidget {
  /// Data focada (mês/ano exibido)
  final DateTime focusedDate;

  /// Data selecionada
  final DateTime? selectedDate;

  /// Callback ao selecionar data
  final ValueChanged<DateTime>? onDateSelected;

  /// Callback ao mudar mês
  final ValueChanged<DateTime>? onPageChanged;

  /// Cor de destaque para a data selecionada
  final Color? accentColor;

  /// Título do calendário
  final String? title;

  /// Se deve mostrar o header com navegação
  final bool showHeader;

  /// Altura do tile do dia (padrão null = usa density)
  final double? tileHeight;

  /// Se deve mostrar dias fora do mês
  final bool showOutsideDays;

  /// Densidade do calendário
  final FFCompactCalendarDensity density;

  const FFCompactCalendar({
    super.key,
    required this.focusedDate,
    this.selectedDate,
    this.onDateSelected,
    this.onPageChanged,
    this.accentColor,
    this.title,
    this.showHeader = true,
    this.tileHeight,
    this.showOutsideDays = false,
    this.density = FFCompactCalendarDensity.regular,
  });

  double get _effectiveTileHeight {
    if (tileHeight != null) return tileHeight!;
    switch (density) {
      case FFCompactCalendarDensity.regular:
        return 36;
      case FFCompactCalendarDensity.compact:
        return 32;
      case FFCompactCalendarDensity.extraCompact:
        return 28;
    }
  }

  double get _fontSize {
    switch (density) {
      case FFCompactCalendarDensity.regular:
        return 12;
      case FFCompactCalendarDensity.compact:
        return 11;
      case FFCompactCalendarDensity.extraCompact:
        return 10;
    }
  }

  double get _headerFontSize {
    switch (density) {
      case FFCompactCalendarDensity.regular:
        return 13;
      case FFCompactCalendarDensity.compact:
        return 12;
      case FFCompactCalendarDensity.extraCompact:
        return 11;
    }
  }

  double get _weekdayFontSize {
    switch (density) {
      case FFCompactCalendarDensity.regular:
        return 10;
      case FFCompactCalendarDensity.compact:
        return 9;
      case FFCompactCalendarDensity.extraCompact:
        return 8;
    }
  }

  double get _headerHeight {
    switch (density) {
      case FFCompactCalendarDensity.regular:
        return 28;
      case FFCompactCalendarDensity.compact:
        return 24;
      case FFCompactCalendarDensity.extraCompact:
        return 22;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveAccent = accentColor ?? colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHeader) _buildHeader(context, colorScheme, effectiveAccent),
        _buildWeekdayRow(context, colorScheme),
        Expanded(
          child: _buildDaysGrid(context, colorScheme, effectiveAccent),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme, Color accent) {
    final monthFormat = DateFormat('MMMM', 'pt_BR');
    final yearFormat = DateFormat('yyyy');
    final month = monthFormat.format(focusedDate);
    final year = yearFormat.format(focusedDate);
    final displayMonth = '${month[0].toUpperCase()}${month.substring(1)} $year';
    final btnSize = _headerHeight;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: SizedBox(
        height: _headerHeight,
        child: Row(
          children: [
            _NavButton(
              icon: Icons.chevron_left,
              size: btnSize,
              onTap: () {
                final newDate = DateTime(focusedDate.year, focusedDate.month - 1, 1);
                onPageChanged?.call(newDate);
              },
              colorScheme: colorScheme,
            ),
            Expanded(
              child: Text(
                displayMonth,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: _headerFontSize,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            _NavButton(
              icon: Icons.chevron_right,
              size: btnSize,
              onTap: () {
                final newDate = DateTime(focusedDate.year, focusedDate.month + 1, 1);
                onPageChanged?.call(newDate);
              },
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekdayRow(BuildContext context, ColorScheme colorScheme) {
    const weekdays = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: SizedBox(
        height: _weekdayFontSize + 6,
        child: Row(
          children: List.generate(7, (index) {
            final isWeekend = index == 0 || index == 6;
            return Expanded(
              child: Center(
                child: Text(
                  weekdays[index],
                  style: TextStyle(
                    fontSize: _weekdayFontSize,
                    fontWeight: FontWeight.w600,
                    color: isWeekend
                        ? Colors.red.shade400
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDaysGrid(BuildContext context, ColorScheme colorScheme, Color accent) {
    final firstDayOfMonth = DateTime(focusedDate.year, focusedDate.month, 1);
    final lastDayOfMonth = DateTime(focusedDate.year, focusedDate.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final startWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday

    // Build 6 weeks (42 days) grid
    final days = <DateTime?>[];

    // Days from previous month
    final prevMonth = DateTime(focusedDate.year, focusedDate.month, 0);
    for (int i = startWeekday - 1; i >= 0; i--) {
      days.add(showOutsideDays
          ? DateTime(prevMonth.year, prevMonth.month, prevMonth.day - i)
          : null);
    }

    // Days of current month
    for (int i = 1; i <= daysInMonth; i++) {
      days.add(DateTime(focusedDate.year, focusedDate.month, i));
    }

    // Days from next month
    final remaining = 42 - days.length;
    for (int i = 1; i <= remaining; i++) {
      days.add(showOutsideDays
          ? DateTime(focusedDate.year, focusedDate.month + 1, i)
          : null);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate tile height based on available space
        final availableHeight = constraints.maxHeight;
        final effectiveTile = tileHeight ?? (availableHeight / 6).clamp(24.0, _effectiveTileHeight);

        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(6, (weekIndex) {
            return SizedBox(
              height: effectiveTile,
              child: Row(
                children: List.generate(7, (dayIndex) {
                  final index = weekIndex * 7 + dayIndex;
                  final day = days[index];
                  if (day == null) {
                    return const Expanded(child: SizedBox());
                  }
                  return Expanded(
                    child: _DayTile(
                      day: day,
                      isSelected: selectedDate != null &&
                          day.year == selectedDate!.year &&
                          day.month == selectedDate!.month &&
                          day.day == selectedDate!.day,
                      isToday: _isToday(day),
                      isOutsideMonth: day.month != focusedDate.month,
                      accentColor: accent,
                      colorScheme: colorScheme,
                      fontSize: _fontSize,
                      onTap: onDateSelected != null ? () => onDateSelected!(day) : null,
                    ),
                  );
                }),
              ),
            );
          }),
        );
      },
    );
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final double size;

  const _NavButton({
    required this.icon,
    required this.onTap,
    required this.colorScheme,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(
            icon,
            size: size * 0.6,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final DateTime day;
  final bool isSelected;
  final bool isToday;
  final bool isOutsideMonth;
  final Color accentColor;
  final ColorScheme colorScheme;
  final VoidCallback? onTap;
  final double fontSize;

  const _DayTile({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.isOutsideMonth,
    required this.accentColor,
    required this.colorScheme,
    this.onTap,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final city = PrefsService.cityNotifier.value;
    final isHoliday = HolidayService.isHoliday(day, city);
    final isWeekend = HolidayService.isWeekend(day);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color textColor;
    Color? bgColor;
    BoxBorder? border;

    if (isSelected) {
      textColor = Colors.white;
      bgColor = accentColor;
    } else if (isOutsideMonth) {
      textColor = colorScheme.onSurface.withValues(alpha: 0.3);
    } else if (isToday) {
      textColor = colorScheme.primary;
      border = Border.all(
        color: colorScheme.primary.withValues(alpha: 0.5),
        width: 1,
      );
    } else if (isHoliday) {
      textColor = Colors.purple.shade600;
      bgColor = Colors.purple.withValues(alpha: isDark ? 0.15 : 0.06);
    } else if (isWeekend) {
      textColor = Colors.red.shade400;
      bgColor = Colors.red.withValues(alpha: isDark ? 0.08 : 0.03);
    } else {
      textColor = colorScheme.onSurface;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isOutsideMonth ? null : onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: border,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isSelected || isToday ? FontWeight.w600 : FontWeight.normal,
                  color: textColor,
                ),
              ),
              // Dot para feriado ou hoje
              if (!isSelected && (isHoliday || isToday))
                Positioned(
                  bottom: 2,
                  child: Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: isHoliday ? Colors.purple.shade400 : colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
