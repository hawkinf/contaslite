import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/holiday_service.dart';
import '../services/prefs_service.dart';
import '../ui/components/ff_design_system.dart';
import '../ui/theme/app_spacing.dart';
import '../ui/theme/app_radius.dart';

/// Tela de Cálculo de Dias do FácilFin.
///
/// Layout otimizado:
/// - Header compacto com cidade e estatísticas
/// - Dois calendários lado a lado (ocupam a maior parte)
/// - Barra compacta inferior (44px) com resumo + botão "Ajustar"
/// - Modal para editar parâmetros de cálculo
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

  // Parâmetros de cálculo
  int _daysCount = 30;
  String _dayType = 'Úteis';
  String _direction = 'Frente';

  // Resultados
  int _totalDays = 0;
  int _workingDays = 0;
  int _weekendDays = 0;
  int _holidayDays = 0;

  // Layout constants
  static const double _headerHeight = 36.0;
  static const double _actionBarHeight = 44.0;
  static const double _gap = 6.0;

  @override
  void initState() {
    super.initState();
    _calculateDays();
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
    if (_daysCount <= 0) return;

    final city = PrefsService.cityNotifier.value;
    final isForward = _direction == 'Frente';
    final isWorkingDays = _dayType == 'Úteis';

    DateTime current = DateTime(_referenceDate.year, _referenceDate.month, _referenceDate.day);
    int counted = 0;

    while (counted < _daysCount) {
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

  void _copyCalculatedDate() {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dayFormat = DateFormat('EEEE', 'pt_BR');
    final text = '${dateFormat.format(_calculatedDate)} (${dayFormat.format(_calculatedDate)})';

    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('Data copiada!');
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
    _showSnackBar('Resultado copiado!');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(message),
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
      _daysCount = 30;
    });
    _calculateFromDays();
  }

  void _showCalculateModal() {
    showDialog(
      context: context,
      builder: (context) => _CalculateDaysModal(
        daysCount: _daysCount,
        dayType: _dayType,
        direction: _direction,
        onApply: (days, type, direction) {
          setState(() {
            _daysCount = days;
            _dayType = type;
            _direction = direction;
          });
          _calculateFromDays();
        },
      ),
    );
  }

  FFCompactCalendarDensity _getDensityForHeight(double calendarAreaHeight) {
    if (calendarAreaHeight < 240) {
      return FFCompactCalendarDensity.extraCompact;
    } else if (calendarAreaHeight < 300) {
      return FFCompactCalendarDensity.compact;
    }
    return FFCompactCalendarDensity.regular;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final city = PrefsService.cityNotifier.value;

    return FFScreenScaffold(
      title: 'Calcular Dias',
      useScrollView: false,
      horizontalPadding: AppSpacing.sm,
      verticalPadding: AppSpacing.xs,
      appBarActions: [
        FFIconActionButton(
          icon: Icons.refresh,
          tooltip: 'Resetar para Hoje',
          onPressed: _resetToToday,
          size: 32,
          iconSize: 16,
        ),
        const SizedBox(width: 2),
        FFIconActionButton(
          icon: Icons.swap_horiz,
          tooltip: 'Inverter Datas',
          onPressed: _swapDates,
          size: 32,
          iconSize: 16,
        ),
        const SizedBox(width: 2),
        FFIconActionButton(
          icon: Icons.copy_all,
          tooltip: 'Copiar Resultado',
          onPressed: _copyResults,
          size: 32,
          iconSize: 16,
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final calendarAreaHeight = constraints.maxHeight - _headerHeight - _actionBarHeight - (_gap * 2);
          final density = _getDensityForHeight(calendarAreaHeight);

          return Column(
            children: [
              // Header compacto
              SizedBox(
                height: _headerHeight,
                child: _buildHeader(colorScheme, city),
              ),
              const SizedBox(height: _gap),

              // Calendários (ocupam o máximo de espaço)
              Expanded(
                child: _buildCalendarsArea(colorScheme, density),
              ),
              const SizedBox(height: _gap),

              // Barra de ação compacta (44px)
              SizedBox(
                height: _actionBarHeight,
                child: _buildActionBar(colorScheme),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, String city) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, size: 14, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            city,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
          ),
          const Spacer(),
          _buildStat('$_totalDays', 'dias', Colors.blue, colorScheme),
          const SizedBox(width: 12),
          _buildStat('$_workingDays', 'úteis', Colors.green, colorScheme),
          const SizedBox(width: 12),
          _buildStat('$_weekendDays', 'fim sem', Colors.orange, colorScheme),
          const SizedBox(width: 12),
          _buildStat('$_holidayDays', 'feriados', Colors.purple, colorScheme),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label, Color color, ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 2),
        Text(label, style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildCalendarsArea(ColorScheme colorScheme, FFCompactCalendarDensity density) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _buildCalendarCard(
            title: 'Referência',
            date: _referenceDate,
            focusedDate: _focusedReferenceDate,
            accentColor: colorScheme.primary,
            density: density,
            onDateSelected: (date) {
              setState(() {
                _referenceDate = date;
                _focusedReferenceDate = date;
              });
              _calculateDays();
            },
            onPageChanged: (date) => setState(() => _focusedReferenceDate = date),
            colorScheme: colorScheme,
            showCopyButton: false,
          ),
        ),
        const SizedBox(width: _gap),
        Expanded(
          child: _buildCalendarCard(
            title: 'Calculada',
            date: _calculatedDate,
            focusedDate: _focusedCalculatedDate,
            accentColor: Colors.amber.shade700,
            density: density,
            onDateSelected: (date) {
              setState(() {
                _calculatedDate = date;
                _focusedCalculatedDate = date;
              });
              _calculateDays();
            },
            onPageChanged: (date) => setState(() => _focusedCalculatedDate = date),
            colorScheme: colorScheme,
            showCopyButton: true,
            onCopy: _copyCalculatedDate,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarCard({
    required String title,
    required DateTime date,
    required DateTime focusedDate,
    required Color accentColor,
    required FFCompactCalendarDensity density,
    required ValueChanged<DateTime> onDateSelected,
    required ValueChanged<DateTime> onPageChanged,
    required ColorScheme colorScheme,
    required bool showCopyButton,
    VoidCallback? onCopy,
  }) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dayFormat = DateFormat('EEE', 'pt_BR');
    final dayFormatted = dayFormat.format(date).replaceAll('.', '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FFCard(
      padding: const EdgeInsets.all(8),
      showShadow: !isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header compacto
          SizedBox(
            height: 22,
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    dateFormat.format(date),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accentColor),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  dayFormatted,
                  style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                ),
                const Spacer(),
                if (showCopyButton)
                  InkWell(
                    onTap: onCopy,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.copy, size: 14, color: accentColor),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Calendário
          Expanded(
            child: FFCompactCalendar(
              focusedDate: focusedDate,
              selectedDate: date,
              accentColor: accentColor,
              density: density,
              onDateSelected: onDateSelected,
              onPageChanged: onPageChanged,
            ),
          ),
        ],
      ),
    );
  }

  /// Barra de ação compacta (44px) - mostra resumo e botão "Ajustar"
  Widget _buildActionBar(ColorScheme colorScheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeLabel = _dayType == 'Úteis' ? 'úteis' : 'corridos';
    final dirLabel = _direction == 'Frente' ? 'p/ frente' : 'p/ trás';

    return Material(
      color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      elevation: isDark ? 0 : 2,
      child: InkWell(
        onTap: _showCalculateModal,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.calculate_outlined, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Calcular dias',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_daysCount $typeLabel, $dirLabel',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune, size: 14, color: colorScheme.onPrimary),
                    const SizedBox(width: 4),
                    Text(
                      'Ajustar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal para editar parâmetros de cálculo
class _CalculateDaysModal extends StatefulWidget {
  final int daysCount;
  final String dayType;
  final String direction;
  final void Function(int days, String type, String direction) onApply;

  const _CalculateDaysModal({
    required this.daysCount,
    required this.dayType,
    required this.direction,
    required this.onApply,
  });

  @override
  State<_CalculateDaysModal> createState() => _CalculateDaysModalState();
}

class _CalculateDaysModalState extends State<_CalculateDaysModal> {
  late TextEditingController _daysController;
  late String _dayType;
  late String _direction;

  @override
  void initState() {
    super.initState();
    _daysController = TextEditingController(text: widget.daysCount.toString());
    _dayType = widget.dayType;
    _direction = widget.direction;
  }

  @override
  void dispose() {
    _daysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surfaceContainerHigh : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.calculate_outlined, size: 24, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Calcular Dias',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Campo: Quantos dias?
            Text(
              'Quantos dias?',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            _buildNumberInput(colorScheme, isDark),
            const SizedBox(height: 16),

            // Campo: Tipo de dias
            Text(
              'Tipo de dias',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            _buildSegmentedButton(
              options: const ['Úteis', 'Corridos'],
              selected: _dayType,
              onChanged: (v) => setState(() => _dayType = v),
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 16),

            // Campo: Direção
            Text(
              'Direção',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            _buildSegmentedButton(
              options: const ['Frente', 'Trás'],
              selected: _direction,
              onChanged: (v) => setState(() => _direction = v),
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 24),

            // Botões
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final days = int.tryParse(_daysController.text) ?? 0;
                      if (days > 0) {
                        widget.onApply(days, _dayType, _direction);
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Aplicar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberInput(ColorScheme colorScheme, bool isDark) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              final current = int.tryParse(_daysController.text) ?? 1;
              if (current > 1) {
                _daysController.text = (current - 1).toString();
              }
            },
            child: Container(
              width: 48,
              alignment: Alignment.center,
              child: Icon(Icons.remove, color: colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _daysController,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              final current = int.tryParse(_daysController.text) ?? 0;
              if (current < 9999) {
                _daysController.text = (current + 1).toString();
              }
            },
            child: Container(
              width: 48,
              alignment: Alignment.center,
              child: Icon(Icons.add, color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedButton({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onChanged,
    required ColorScheme colorScheme,
  }) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: options.map((option) {
          final isSelected = option == selected;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(option),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.horizontal(
                    left: option == options.first ? const Radius.circular(7) : Radius.zero,
                    right: option == options.last ? const Radius.circular(7) : Radius.zero,
                  ),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
