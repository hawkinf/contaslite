import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/holiday_service.dart';
import '../services/prefs_service.dart';

class CalculateDaysScreen extends StatefulWidget {
  const CalculateDaysScreen({super.key});

  @override
  State<CalculateDaysScreen> createState() => _CalculateDaysScreenState();
}

class _CalculateDaysScreenState extends State<CalculateDaysScreen> {
  // Datas selecionadas
  DateTime _referenceDate = DateTime.now();
  DateTime _calculatedDate = DateTime.now().add(const Duration(days: 30));
  DateTime _focusedReferenceDate = DateTime.now();
  DateTime _focusedCalculatedDate = DateTime.now().add(const Duration(days: 30));

  // Controles para "Calcular dias"
  final TextEditingController _daysController = TextEditingController(text: '30');
  String _dayType = 'Úteis'; // Úteis ou Corridos
  String _direction = 'Frente'; // Frente ou Trás

  // Resultados
  int _totalDays = 0;
  int _workingDays = 0;
  int _weekendDays = 0;
  int _holidayDays = 0;

  @override
  void initState() {
    super.initState();
    _calculateDays();
  }

  @override
  void dispose() {
    _daysController.dispose();
    super.dispose();
  }

  void _calculateDays() {
    final city = PrefsService.cityNotifier.value;
    final start = DateTime(_referenceDate.year, _referenceDate.month, _referenceDate.day);
    final end = DateTime(_calculatedDate.year, _calculatedDate.month, _calculatedDate.day);

    final actualStart = start.isBefore(end) ? start : end;
    final actualEnd = start.isBefore(end) ? end : start;

    int total = 0;
    int working = 0;
    int weekends = 0;
    int holidays = 0;

    DateTime current = actualStart;
    while (!current.isAfter(actualEnd)) {
      total++;
      final isWeekend = HolidayService.isWeekend(current);
      final isHoliday = HolidayService.isHoliday(current, city);

      if (isWeekend) {
        weekends++;
      } else if (isHoliday) {
        holidays++;
      } else {
        working++;
      }

      current = current.add(const Duration(days: 1));
    }

    setState(() {
      _totalDays = total;
      _workingDays = working;
      _weekendDays = weekends;
      _holidayDays = holidays;
    });
  }

  void _calculateFromDays() {
    final days = int.tryParse(_daysController.text) ?? 0;
    if (days <= 0) return;

    final city = PrefsService.cityNotifier.value;
    final isForward = _direction == 'Frente';
    final isWorkingDays = _dayType == 'Úteis';

    DateTime current = DateTime(_referenceDate.year, _referenceDate.month, _referenceDate.day);
    int counted = 0;

    while (counted < days) {
      current = isForward
          ? current.add(const Duration(days: 1))
          : current.subtract(const Duration(days: 1));

      if (isWorkingDays) {
        final isWeekend = HolidayService.isWeekend(current);
        final isHoliday = HolidayService.isHoliday(current, city);
        if (!isWeekend && !isHoliday) {
          counted++;
        }
      } else {
        counted++;
      }
    }

    setState(() {
      _calculatedDate = current;
      _focusedCalculatedDate = current;
    });
    _calculateDays();
  }

  void _copyResults() {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dayFormat = DateFormat('EEEE', 'pt_BR');
    final text = '''
Cálculo de Dias - FácilFin
═══════════════════════════════
Data Referência: ${dateFormat.format(_referenceDate)} (${dayFormat.format(_referenceDate)})
Data Calculada: ${dateFormat.format(_calculatedDate)} (${dayFormat.format(_calculatedDate)})

📊 Resultado:
• Total de Dias: $_totalDays
• Dias Úteis: $_workingDays
• Finais de Semana: $_weekendDays
• Feriados: $_holidayDays
''';

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Resultado copiado!'),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _swapDates() {
    setState(() {
      final temp = _referenceDate;
      _referenceDate = _calculatedDate;
      _calculatedDate = temp;
      _focusedReferenceDate = _referenceDate;
      _focusedCalculatedDate = _calculatedDate;
    });
    _calculateDays();
  }

  void _resetToToday() {
    setState(() {
      _referenceDate = DateTime.now();
      _focusedReferenceDate = _referenceDate;
      _daysController.text = '30';
    });
    _calculateFromDays();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? Colors.blue.shade900 : Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.calculate, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Calcular Dias',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Resetar para Hoje',
            onPressed: _resetToToday,
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Inverter Datas',
            onPressed: _swapDates,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            final isTablet = constraints.maxWidth >= 600;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Seção "Calcular dias" com inputs
                _buildCalculateDaysSection(colorScheme, isDark, isDesktop),
                const SizedBox(height: 20),

                // Calendários
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildDateCard(
                          title: 'Data Referência',
                          subtitle: 'Selecione a data inicial',
                          date: _referenceDate,
                          focusedDate: _focusedReferenceDate,
                          onDateSelected: (date) {
                            setState(() {
                              _referenceDate = date;
                              _focusedReferenceDate = date;
                            });
                            _calculateDays();
                          },
                          onPageChanged: (date) {
                            setState(() => _focusedReferenceDate = date);
                          },
                          colorScheme: colorScheme,
                          isDark: isDark,
                          accentColor: colorScheme.primary,
                          isReference: true,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildDateCard(
                          title: 'Data Calculada',
                          subtitle: 'Data resultante',
                          date: _calculatedDate,
                          focusedDate: _focusedCalculatedDate,
                          onDateSelected: (date) {
                            setState(() {
                              _calculatedDate = date;
                              _focusedCalculatedDate = date;
                            });
                            _calculateDays();
                          },
                          onPageChanged: (date) {
                            setState(() => _focusedCalculatedDate = date);
                          },
                          colorScheme: colorScheme,
                          isDark: isDark,
                          accentColor: Colors.amber.shade700,
                          isReference: false,
                        ),
                      ),
                    ],
                  )
                else ...[
                  _buildDateCard(
                    title: 'Data Referência',
                    subtitle: 'Selecione a data inicial',
                    date: _referenceDate,
                    focusedDate: _focusedReferenceDate,
                    onDateSelected: (date) {
                      setState(() {
                        _referenceDate = date;
                        _focusedReferenceDate = date;
                      });
                      _calculateDays();
                    },
                    onPageChanged: (date) {
                      setState(() => _focusedReferenceDate = date);
                    },
                    colorScheme: colorScheme,
                    isDark: isDark,
                    accentColor: colorScheme.primary,
                    isReference: true,
                    compact: !isTablet,
                  ),
                  const SizedBox(height: 16),
                  _buildDateCard(
                    title: 'Data Calculada',
                    subtitle: 'Data resultante',
                    date: _calculatedDate,
                    focusedDate: _focusedCalculatedDate,
                    onDateSelected: (date) {
                      setState(() {
                        _calculatedDate = date;
                        _focusedCalculatedDate = date;
                      });
                      _calculateDays();
                    },
                    onPageChanged: (date) {
                      setState(() => _focusedCalculatedDate = date);
                    },
                    colorScheme: colorScheme,
                    isDark: isDark,
                    accentColor: Colors.amber.shade700,
                    isReference: false,
                    compact: !isTablet,
                  ),
                ],
                const SizedBox(height: 20),

                // Resultado
                _buildResultsCard(colorScheme, isDark, isDesktop: isDesktop),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Seção "Calcular dias" com inputs
  Widget _buildCalculateDaysSection(ColorScheme colorScheme, bool isDark, bool isDesktop) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Calcular dias',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isDesktop)
              Row(
                children: [
                  // Input de dias
                  Expanded(
                    flex: 2,
                    child: _buildDaysInput(colorScheme),
                  ),
                  const SizedBox(width: 16),
                  // Dropdown Tipo
                  Expanded(
                    flex: 2,
                    child: _buildTypeDropdown(colorScheme),
                  ),
                  const SizedBox(width: 16),
                  // Dropdown Direção
                  Expanded(
                    flex: 2,
                    child: _buildDirectionDropdown(colorScheme),
                  ),
                  const SizedBox(width: 16),
                  // Botão Calcular
                  _buildCalculateButton(colorScheme),
                ],
              )
            else
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildDaysInput(colorScheme)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTypeDropdown(colorScheme)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildDirectionDropdown(colorScheme)),
                      const SizedBox(width: 12),
                      _buildCalculateButton(colorScheme),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysInput(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quantos dias',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 18),
                onPressed: () {
                  final current = int.tryParse(_daysController.text) ?? 0;
                  if (current > 1) {
                    _daysController.text = (current - 1).toString();
                  }
                },
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: TextField(
                  controller: _daysController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                onPressed: () {
                  final current = int.tryParse(_daysController.text) ?? 0;
                  _daysController.text = (current + 1).toString();
                },
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeDropdown(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _dayType,
              isExpanded: true,
              icon: Icon(Icons.expand_more, color: colorScheme.onSurfaceVariant),
              items: const [
                DropdownMenuItem(value: 'Úteis', child: Text('Dias Úteis')),
                DropdownMenuItem(value: 'Corridos', child: Text('Dias Corridos')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _dayType = value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDirectionDropdown(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Direção',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _direction,
              isExpanded: true,
              icon: Icon(Icons.expand_more, color: colorScheme.onSurfaceVariant),
              items: const [
                DropdownMenuItem(value: 'Frente', child: Text('Para frente')),
                DropdownMenuItem(value: 'Trás', child: Text('Para trás')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _direction = value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalculateButton(ColorScheme colorScheme) {
    return FilledButton.icon(
      onPressed: _calculateFromDays,
      icon: const Icon(Icons.calculate, size: 18),
      label: const Text('Calcular'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  /// Card de data com calendário
  Widget _buildDateCard({
    required String title,
    required String subtitle,
    required DateTime date,
    required DateTime focusedDate,
    required void Function(DateTime) onDateSelected,
    required void Function(DateTime) onPageChanged,
    required ColorScheme colorScheme,
    required bool isDark,
    required Color accentColor,
    required bool isReference,
    bool compact = false,
  }) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dayFormat = DateFormat('EEEE', 'pt_BR');
    final monthFormat = DateFormat('MMMM', 'pt_BR');
    final yearFormat = DateFormat('yyyy');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Indicador de cor
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Data selecionada
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        dateFormat.format(date),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                      Text(
                        dayFormat.format(date),
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Calendar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: TableCalendar(
              locale: 'pt_BR',
              firstDay: DateTime(2000, 1, 1),
              lastDay: DateTime(2100, 12, 31),
              focusedDay: focusedDate,
              selectedDayPredicate: (day) => isSameDay(date, day),
              onDaySelected: (selectedDay, focusedDay) {
                onDateSelected(selectedDay);
              },
              onPageChanged: onPageChanged,
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.sunday,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextFormatter: (date, locale) {
                  final month = monthFormat.format(date);
                  final year = yearFormat.format(date);
                  return '${month[0].toUpperCase()}${month.substring(1)} $year';
                },
                titleTextStyle: TextStyle(
                  fontSize: compact ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                leftChevronIcon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.chevron_left,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                rightChevronIcon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                headerPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              daysOfWeekHeight: 32,
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
                weekendStyle: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade400,
                ),
              ),
              rowHeight: compact ? 40 : 44,
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                cellMargin: const EdgeInsets.all(2),
                cellPadding: EdgeInsets.zero,
                // Default day
                defaultTextStyle: TextStyle(
                  fontSize: compact ? 13 : 14,
                  color: colorScheme.onSurface,
                ),
                // Weekend
                weekendTextStyle: TextStyle(
                  fontSize: compact ? 13 : 14,
                  color: Colors.red.shade400,
                ),
                // Selected day
                selectedDecoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                selectedTextStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                // Today
                todayDecoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                todayTextStyle: TextStyle(
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  return _buildDayCell(
                    day: day,
                    colorScheme: colorScheme,
                    accentColor: accentColor,
                    compact: compact,
                    isSelected: false,
                    isToday: false,
                  );
                },
                todayBuilder: (context, day, focusedDay) {
                  final isSelected = isSameDay(date, day);
                  if (isSelected) return null; // Let selectedBuilder handle it
                  return _buildDayCell(
                    day: day,
                    colorScheme: colorScheme,
                    accentColor: accentColor,
                    compact: compact,
                    isSelected: false,
                    isToday: true,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Célula do dia com estilos suaves
  Widget _buildDayCell({
    required DateTime day,
    required ColorScheme colorScheme,
    required Color accentColor,
    required bool compact,
    required bool isSelected,
    required bool isToday,
  }) {
    final city = PrefsService.cityNotifier.value;
    final isHoliday = HolidayService.isHoliday(day, city);
    final isWeekend = HolidayService.isWeekend(day);

    Color textColor = colorScheme.onSurface;
    Color? bgColor;
    BoxBorder? border;

    if (isToday) {
      border = Border.all(
        color: colorScheme.primary.withValues(alpha: 0.6),
        width: 1.5,
      );
      textColor = colorScheme.primary;
    }

    if (isWeekend) {
      textColor = Colors.red.shade400;
      bgColor = Colors.red.withValues(alpha: 0.04);
    }

    if (isHoliday) {
      textColor = Colors.purple.shade600;
      bgColor = Colors.purple.withValues(alpha: 0.06);
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: border,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
              color: textColor,
            ),
          ),
          // Dot para feriado
          if (isHoliday)
            Positioned(
              bottom: 4,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.purple.shade400,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          // Dot para hoje
          if (isToday && !isHoliday)
            Positioned(
              bottom: 4,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Card de resultados
  Widget _buildResultsCard(ColorScheme colorScheme, bool isDark, {required bool isDesktop}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.analytics_outlined,
                    color: Colors.indigo.shade600,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resultado do Cálculo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Entre ${DateFormat('dd/MM/yyyy').format(_referenceDate)} e ${DateFormat('dd/MM/yyyy').format(_calculatedDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Botão Copiar
                FilledButton.tonalIcon(
                  onPressed: _copyResults,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copiar'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Results grid
          Padding(
            padding: const EdgeInsets.all(16),
            child: isDesktop
                ? Row(
                    children: [
                      Expanded(
                        child: _buildResultItem(
                          label: 'Total de Dias',
                          value: _totalDays.toString(),
                          icon: Icons.date_range_outlined,
                          color: Colors.blue.shade600,
                          colorScheme: colorScheme,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildResultItem(
                          label: 'Dias Úteis',
                          value: _workingDays.toString(),
                          icon: Icons.work_outline,
                          color: Colors.green.shade600,
                          colorScheme: colorScheme,
                          highlight: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildResultItem(
                          label: 'Fins de Semana',
                          value: _weekendDays.toString(),
                          icon: Icons.weekend_outlined,
                          color: Colors.orange.shade600,
                          colorScheme: colorScheme,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildResultItem(
                          label: 'Feriados',
                          value: _holidayDays.toString(),
                          icon: Icons.celebration_outlined,
                          color: Colors.purple.shade600,
                          colorScheme: colorScheme,
                        ),
                      ),
                    ],
                  )
                : GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.8,
                    children: [
                      _buildResultItem(
                        label: 'Total de Dias',
                        value: _totalDays.toString(),
                        icon: Icons.date_range_outlined,
                        color: Colors.blue.shade600,
                        colorScheme: colorScheme,
                      ),
                      _buildResultItem(
                        label: 'Dias Úteis',
                        value: _workingDays.toString(),
                        icon: Icons.work_outline,
                        color: Colors.green.shade600,
                        colorScheme: colorScheme,
                        highlight: true,
                      ),
                      _buildResultItem(
                        label: 'Fins de Semana',
                        value: _weekendDays.toString(),
                        icon: Icons.weekend_outlined,
                        color: Colors.orange.shade600,
                        colorScheme: colorScheme,
                      ),
                      _buildResultItem(
                        label: 'Feriados',
                        value: _holidayDays.toString(),
                        icon: Icons.celebration_outlined,
                        color: Colors.purple.shade600,
                        colorScheme: colorScheme,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required ColorScheme colorScheme,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: highlight ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: highlight
            ? Border.all(color: color.withValues(alpha: 0.4), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
