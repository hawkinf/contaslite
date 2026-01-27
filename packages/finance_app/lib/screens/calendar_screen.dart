import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:brasil_fields/brasil_fields.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../services/holiday_service.dart';
import '../services/prefs_service.dart';
import '../ui/components/period_header.dart';
import '../utils/app_colors.dart';

/// Modos de visualização do calendário
enum CalendarViewMode { weekly, monthly, yearly }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarViewMode _viewMode = CalendarViewMode.monthly;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, List<Account>> _events = {};
  bool _isLoading = true;
  Set<int> _recebimentosTypeIds = {};

  // ScrollController for weekly view
  final ScrollController _weeklyScrollController = ScrollController();

  // Totais gerais do mês
  double _totalPagarMes = 0;
  double _totalReceberMes = 0;
  int _countPagarMes = 0;
  int _countReceberMes = 0;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  @override
  void dispose() {
    _weeklyScrollController.dispose();
    super.dispose();
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  int _normalizeYear(int? year) {
    if (year == null) return DateTime.now().year;
    if (year < 100) return 2000 + year;
    return year;
  }

  DateTime _resolveEffectiveDate(Account account, DateTime fallbackMonth) {
    final year = _normalizeYear(account.year ?? fallbackMonth.year);
    final month = account.month ?? fallbackMonth.month;
    int day = account.dueDay;
    int maxDays = DateUtils.getDaysInMonth(year, month);
    if (day > maxDays) day = maxDays;

    DateTime effectiveDate = DateTime(year, month, day);
    final city = PrefsService.cityNotifier.value;

    bool needsAdjustment = HolidayService.isWeekend(effectiveDate) ||
        HolidayService.isHoliday(effectiveDate, city);

    if (needsAdjustment) {
      if (account.payInAdvance) {
        while (HolidayService.isWeekend(effectiveDate) ||
            HolidayService.isHoliday(effectiveDate, city)) {
          effectiveDate = effectiveDate.subtract(const Duration(days: 1));
        }
      } else {
        while (HolidayService.isWeekend(effectiveDate) ||
            HolidayService.isHoliday(effectiveDate, city)) {
          effectiveDate = effectiveDate.add(const Duration(days: 1));
        }
      }
    }

    return DateTime.utc(effectiveDate.year, effectiveDate.month, effectiveDate.day);
  }

  void _calculateMonthTotals() {
    _totalPagarMes = 0;
    _totalReceberMes = 0;
    _countPagarMes = 0;
    _countReceberMes = 0;

    final currentMonth = _focusedDay.month;
    final currentYear = _focusedDay.year;

    _events.forEach((dateKey, accounts) {
      final parts = dateKey.split('-');
      final eventYear = int.parse(parts[0]);
      final eventMonth = int.parse(parts[1]);

      if (eventMonth == currentMonth && eventYear == currentYear) {
        for (var account in accounts) {
          final isRecurrent = account.isRecurrent || account.recurrenceId != null;
          final displayValue = (isRecurrent && account.value <= 0.01)
              ? (account.estimatedValue ?? account.value)
              : account.value;

          if (_recebimentosTypeIds.contains(account.typeId)) {
            _totalReceberMes += displayValue;
            _countReceberMes++;
          } else {
            _totalPagarMes += displayValue;
            _countPagarMes++;
          }
        }
      }
    });
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);

    try {
      final allAccounts = await DatabaseHelper.instance.readAllAccountsExcludingCardExpenses();
      final cards = await DatabaseHelper.instance.readAllCards();
      final types = await DatabaseHelper.instance.readAllTypes();

      _recebimentosTypeIds = types
          .where((t) => t.name.trim().toLowerCase() == 'recebimentos')
          .map((t) => t.id!)
          .toSet();

      final now = DateTime.now();
      final startMonth = DateTime(now.year, now.month - 6, 1);
      final endMonth = DateTime(now.year, now.month + 6 + 1, 0);

      final Map<String, List<Account>> events = {};

      // Filtrar contas normais (avulsas/parceladas, não recorrentes)
      final normalAccounts = allAccounts.where((a) =>
          !a.isRecurrent && a.recurrenceId == null).toList();
      // Filtrar recorrentes (contas fixas mensais)
      final recurrents = allAccounts.where((a) =>
          a.isRecurrent && a.recurrenceId == null).toList();
      // Filtrar instâncias lançadas de recorrentes
      final launchedInstances = allAccounts.where((a) =>
          a.recurrenceId != null).toList();

      final launchedIndex = <int, Set<String>>{};
      for (var inst in launchedInstances) {
        if (inst.recurrenceId != null && inst.month != null && inst.year != null) {
          launchedIndex.putIfAbsent(inst.recurrenceId!, () => <String>{});
          launchedIndex[inst.recurrenceId!]!.add('${inst.recurrenceId}_${inst.year}_${inst.month}');
        }
      }

      for (var account in normalAccounts) {
        if (account.month != null && account.year != null) {
          final normalizedYear = _normalizeYear(account.year);
          final effectiveDate = _resolveEffectiveDate(account, DateTime(normalizedYear, account.month!));
          final key = _dateKey(effectiveDate);
          events.putIfAbsent(key, () => []).add(account);
        }
      }

      for (var account in launchedInstances) {
        if (account.month != null && account.year != null) {
          final normalizedYear = _normalizeYear(account.year);
          final effectiveDate = _resolveEffectiveDate(account, DateTime(normalizedYear, account.month!));
          final key = _dateKey(effectiveDate);
          events.putIfAbsent(key, () => []).add(account);
        }
      }

      DateTime current = DateTime(startMonth.year, startMonth.month, 1);
      while (current.isBefore(endMonth)) {
        for (var rec in recurrents) {
          final launchKey = '${rec.id}_${current.year}_${current.month}';
          final wasLaunched = launchedIndex[rec.id]?.contains(launchKey) ?? false;
          if (!wasLaunched) {
            final previewAccount = Account(
              id: null,
              typeId: rec.typeId,
              description: rec.description,
              value: rec.value,
              estimatedValue: rec.estimatedValue,
              dueDay: rec.dueDay,
              isRecurrent: true,
              payInAdvance: rec.payInAdvance,
              month: current.month,
              year: current.year,
              recurrenceId: rec.id,
            );
            final effectiveDate = _resolveEffectiveDate(previewAccount, current);
            final key = _dateKey(effectiveDate);
            events.putIfAbsent(key, () => []).add(previewAccount);
          }
        }
        current = DateTime(current.year, current.month + 1, 1);
      }

      current = DateTime(startMonth.year, startMonth.month, 1);
      while (current.isBefore(endMonth)) {
        for (var card in cards) {
          final expenses = await DatabaseHelper.instance
              .getCardExpensesForMonth(card.id!, current.month, current.year);
          if (expenses.isNotEmpty) {
            double total = expenses.fold(0.0, (sum, e) => sum + e.value);
            final cardAccount = Account(
              id: card.id,
              typeId: card.typeId,
              description: 'Fatura: ${card.cardBank} - ${card.cardBrand}',
              value: total,
              dueDay: card.dueDay,
              isRecurrent: false,
              payInAdvance: card.payInAdvance,
              month: current.month,
              year: current.year,
              cardBrand: card.cardBrand,
              cardBank: card.cardBank,
              cardColor: card.cardColor,
            );
            final effectiveDate = _resolveEffectiveDate(cardAccount, current);
            final key = _dateKey(effectiveDate);
            events.putIfAbsent(key, () => []).add(cardAccount);
          }
        }
        current = DateTime(current.year, current.month + 1, 1);
      }

      if (mounted) {
        setState(() {
          _events = events;
          _calculateMonthTotals();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Account> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final key = _dateKey(normalizedDay);
    return _events[key] ?? [];
  }

  (double pagar, double receber, int countPagar, int countReceber) _getDayTotals(DateTime day) {
    final events = _getEventsForDay(day);
    double totalPagar = 0;
    double totalReceber = 0;
    int countPagar = 0;
    int countReceber = 0;

    for (var event in events) {
      final isRecurrent = event.isRecurrent || event.recurrenceId != null;
      final displayValue = (isRecurrent && event.value <= 0.01)
          ? (event.estimatedValue ?? event.value)
          : event.value;

      if (_recebimentosTypeIds.contains(event.typeId)) {
        totalReceber += displayValue;
        countReceber++;
      } else {
        totalPagar += displayValue;
        countPagar++;
      }
    }

    return (totalPagar, totalReceber, countPagar, countReceber);
  }

  void _showDayDetailsModal(DateTime day) {
    final events = _getEventsForDay(day);
    if (events.isEmpty) return;

    final (totalPagar, totalReceber, countPagar, countReceber) = _getDayTotals(day);
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header com data e totais
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      DateFormat('dd \'de\' MMMM \'de\' yyyy', 'pt_BR').format(day),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE', 'pt_BR').format(day),
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Cards de totais compactos
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactTotalCard(
                            title: 'A Pagar',
                            value: totalPagar,
                            count: countPagar,
                            color: AppColors.error,
                            icon: Icons.arrow_upward_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildCompactTotalCard(
                            title: 'A Receber',
                            value: totalReceber,
                            count: countReceber,
                            color: AppColors.success,
                            icon: Icons.arrow_downward_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              // Lista de contas
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final account = events[index];
                    return _buildEventTile(account);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactTotalCard({
    required String title,
    required double value,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  UtilBrasilFields.obterReal(value),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + delta, 1);
      _calculateMonthTotals();
    });
  }

  void _changeWeek(int delta) {
    setState(() {
      _focusedDay = _focusedDay.add(Duration(days: 7 * delta));
      _calculateMonthTotals();
    });
  }

  void _changeYear(int delta) {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year + delta, _focusedDay.month, 1);
      _calculateMonthTotals();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // No AppBar - main navigation is in HomeScreen
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // PeriodHeader idêntico ao Contas (56px)
              PeriodHeader(
                label: _getPeriodLabel(),
                onPrevious: _onPrevious,
                onNext: _onNext,
                onTap: _pickMonthYear,
              ),
              // Seletor de modo (Semanal/Mensal/Anual)
              _buildModeSelector(colorScheme),
              // Totais do periodo
              _buildPeriodTotals(colorScheme),
              // Conteudo principal baseado no modo
              Expanded(
                child: _buildCalendarContent(colorScheme, isDark),
              ),
            ],
          );
  }

  /// Retorna o label formatado para o PeriodHeader baseado no modo atual
  String _getPeriodLabel() {
    String label;
    switch (_viewMode) {
      case CalendarViewMode.weekly:
      case CalendarViewMode.monthly:
        label = DateFormat('MMMM yyyy', 'pt_BR').format(_focusedDay);
        break;
      case CalendarViewMode.yearly:
        label = _focusedDay.year.toString();
        break;
    }
    // Capitalizar primeira letra
    return label[0].toUpperCase() + label.substring(1);
  }

  /// Callbacks de navegação baseados no modo atual
  VoidCallback get _onPrevious {
    switch (_viewMode) {
      case CalendarViewMode.weekly:
        return () => _changeWeek(-1);
      case CalendarViewMode.monthly:
        return () => _changeMonth(-1);
      case CalendarViewMode.yearly:
        return () => _changeYear(-1);
    }
  }

  VoidCallback get _onNext {
    switch (_viewMode) {
      case CalendarViewMode.weekly:
        return () => _changeWeek(1);
      case CalendarViewMode.monthly:
        return () => _changeMonth(1);
      case CalendarViewMode.yearly:
        return () => _changeYear(1);
    }
  }

  /// Seletor de modo padronizado (Semanal/Mensal/Anual)
  /// Altura fixa para manter consistência visual
  Widget _buildModeSelector(ColorScheme colorScheme) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModeButton('Semanal', CalendarViewMode.weekly, colorScheme),
              _buildModeButton('Mensal', CalendarViewMode.monthly, colorScheme),
              _buildModeButton('Anual', CalendarViewMode.yearly, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, CalendarViewMode mode, ColorScheme colorScheme) {
    final isSelected = _viewMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// Totais do periodo
  Widget _buildPeriodTotals(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildInlineTotalChip(
              label: 'Pagar',
              value: _totalPagarMes,
              count: _countPagarMes,
              color: AppColors.error,
              colorScheme: colorScheme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildInlineTotalChip(
              label: 'Receber',
              value: _totalReceberMes,
              count: _countReceberMes,
              color: AppColors.success,
              colorScheme: colorScheme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineTotalChip({
    required String label,
    required double value,
    required int count,
    required Color color,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                label == 'Pagar' ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                UtilBrasilFields.obterReal(value),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Conteudo principal baseado no modo
  Widget _buildCalendarContent(ColorScheme colorScheme, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: switch (_viewMode) {
          CalendarViewMode.weekly => _buildWeeklyView(colorScheme, isDark),
          CalendarViewMode.monthly => _buildMonthlyView(colorScheme, isDark),
          CalendarViewMode.yearly => _buildYearlyView(colorScheme, isDark),
        },
      ),
    );
  }

  /// MODO SEMANAL
  Widget _buildWeeklyView(ColorScheme colorScheme, bool isDark) {
    // Encontrar o inicio da semana (domingo)
    final weekStart = _focusedDay.subtract(Duration(days: _focusedDay.weekday % 7));
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    // ListView with explicit controller and Scrollbar
    return Scrollbar(
      controller: _weeklyScrollController,
      thumbVisibility: true,
      interactive: true,
      child: ListView.builder(
        controller: _weeklyScrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: const EdgeInsets.all(12),
        itemCount: days.length,
        itemBuilder: (context, index) => _buildWeekDayCard(days[index], colorScheme, isDark),
      ),
    );
  }

  Widget _buildWeekDayCard(DateTime day, ColorScheme colorScheme, bool isDark) {
    final (totalPagar, totalReceber, countPagar, countReceber) = _getDayTotals(day);
    final hasEvents = countPagar > 0 || countReceber > 0;
    final isToday = DateUtils.isSameDay(day, DateTime.now());
    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final dayName = DateFormat('EEE', 'pt_BR').format(day).toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isToday
            ? colorScheme.primary.withValues(alpha: 0.08)
            : colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        onTap: hasEvents ? () => _showDayDetailsModal(day) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Data
              SizedBox(
                width: 50,
                child: Column(
                  children: [
                    Text(
                      dayName,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isWeekend ? AppColors.error : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isToday ? colorScheme.primary : colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              // Chip de HOJE
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'HOJE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // Valores
              if (hasEvents) ...[
                if (countPagar > 0)
                  _buildCompactValueBadge(totalPagar, countPagar, AppColors.error, Icons.arrow_upward_rounded),
                if (countPagar > 0 && countReceber > 0)
                  const SizedBox(width: 8),
                if (countReceber > 0)
                  _buildCompactValueBadge(totalReceber, countReceber, AppColors.success, Icons.arrow_downward_rounded),
              ] else
                Text(
                  'Sem lancamentos',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactValueBadge(double value, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            UtilBrasilFields.obterReal(value),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// MODO MENSAL
  Widget _buildMonthlyView(ColorScheme colorScheme, bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cellWidth = (screenWidth - 48) / 7; // 48 = margin + padding
    final dayFontSize = (cellWidth * 0.32).clamp(12.0, 16.0);

    return TableCalendar<Account>(
      locale: 'pt_BR',
      firstDay: DateTime.now().subtract(const Duration(days: 365)),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: _focusedDay,
      calendarFormat: CalendarFormat.month,
      eventLoader: _getEventsForDay,
      startingDayOfWeek: StartingDayOfWeek.sunday,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
        _showDayDetailsModal(selectedDay);
      },
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
          _calculateMonthTotals();
        });
      },
      daysOfWeekHeight: 36,
      rowHeight: 70,
      headerVisible: false,
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurfaceVariant,
        ),
        weekendStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.error.withValues(alpha: 0.8),
        ),
      ),
      calendarStyle: CalendarStyle(
        markersMaxCount: 0,
        cellMargin: const EdgeInsets.all(2),
        defaultTextStyle: TextStyle(fontSize: dayFontSize),
        weekendTextStyle: TextStyle(
          fontSize: dayFontSize,
          color: AppColors.error.withValues(alpha: 0.7),
        ),
        outsideTextStyle: TextStyle(
          fontSize: dayFontSize,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
        todayDecoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.5)),
        ),
        todayTextStyle: TextStyle(
          fontSize: dayFontSize,
          fontWeight: FontWeight.bold,
          color: colorScheme.primary,
        ),
        selectedDecoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
        ),
        selectedTextStyle: TextStyle(
          fontSize: dayFontSize,
          fontWeight: FontWeight.bold,
          color: AppColors.successDark,
        ),
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          return _buildMonthDayCell(day, colorScheme, dayFontSize, false, false);
        },
        todayBuilder: (context, day, focusedDay) {
          return _buildMonthDayCell(day, colorScheme, dayFontSize, true, false);
        },
        selectedBuilder: (context, day, focusedDay) {
          return _buildMonthDayCell(day, colorScheme, dayFontSize, false, true);
        },
        outsideBuilder: (context, day, focusedDay) {
          return _buildMonthDayCell(day, colorScheme, dayFontSize * 0.85, false, false, isOutside: true);
        },
      ),
    );
  }

  Widget _buildMonthDayCell(DateTime day, ColorScheme colorScheme, double fontSize, bool isToday, bool isSelected, {bool isOutside = false}) {
    final (totalPagar, totalReceber, countPagar, countReceber) = _getDayTotals(day);
    final hasEvents = countPagar > 0 || countReceber > 0;
    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

    Color dayTextColor;
    if (isOutside) {
      dayTextColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.3);
    } else if (isToday) {
      dayTextColor = colorScheme.primary;
    } else if (isSelected) {
      dayTextColor = AppColors.successDark;
    } else if (isWeekend) {
      dayTextColor = AppColors.error.withValues(alpha: 0.7);
    } else {
      dayTextColor = colorScheme.onSurface;
    }

    BoxDecoration? dayDecoration;
    if (isToday) {
      dayDecoration = BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.4)),
      );
    } else if (isSelected) {
      dayDecoration = BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      );
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: dayDecoration,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.w500,
              color: dayTextColor,
            ),
          ),
          if (hasEvents && !isOutside) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (countPagar > 0)
                  _buildMiniBadge(totalPagar, AppColors.error, countReceber > 0),
                if (countPagar > 0 && countReceber > 0)
                  const SizedBox(width: 2),
                if (countReceber > 0)
                  _buildMiniBadge(totalReceber, AppColors.success, countPagar > 0),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniBadge(double value, Color color, bool isCompact) {
    String formattedValue;
    if (value >= 1000000) {
      formattedValue = '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      formattedValue = '${(value / 1000).toStringAsFixed(0)}K';
    } else {
      formattedValue = value.toStringAsFixed(0);
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 2 : 3,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        formattedValue,
        style: TextStyle(
          fontSize: isCompact ? 7 : 8,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  /// MODO ANUAL
  Widget _buildYearlyView(ColorScheme colorScheme, bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final month = index + 1;
        return _buildMiniMonthCard(month, colorScheme, isDark);
      },
    );
  }

  Widget _buildMiniMonthCard(int month, ColorScheme colorScheme, bool isDark) {
    final monthDate = DateTime(_focusedDay.year, month, 1);
    final monthName = DateFormat('MMM', 'pt_BR').format(monthDate);
    final isCurrentMonth = month == DateTime.now().month && _focusedDay.year == DateTime.now().year;

    // Calcular totais do mes
    double totalPagar = 0;
    double totalReceber = 0;
    int countPagar = 0;
    int countReceber = 0;

    _events.forEach((dateKey, accounts) {
      final parts = dateKey.split('-');
      final eventYear = int.parse(parts[0]);
      final eventMonth = int.parse(parts[1]);

      if (eventMonth == month && eventYear == _focusedDay.year) {
        for (var account in accounts) {
          final isRecurrent = account.isRecurrent || account.recurrenceId != null;
          final displayValue = (isRecurrent && account.value <= 0.01)
              ? (account.estimatedValue ?? account.value)
              : account.value;

          if (_recebimentosTypeIds.contains(account.typeId)) {
            totalReceber += displayValue;
            countReceber++;
          } else {
            totalPagar += displayValue;
            countPagar++;
          }
        }
      }
    });

    return GestureDetector(
      onTap: () {
        setState(() {
          _focusedDay = DateTime(_focusedDay.year, month, 1);
          _viewMode = CalendarViewMode.monthly;
          _calculateMonthTotals();
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isCurrentMonth
              ? colorScheme.primary.withValues(alpha: 0.08)
              : colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentMonth
                ? colorScheme.primary.withValues(alpha: 0.3)
                : colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Nome do mes
            Text(
              monthName.toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isCurrentMonth ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
            if (isCurrentMonth) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'ATUAL',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            // Mini totais
            if (countPagar > 0 || countReceber > 0) ...[
              if (countPagar > 0)
                _buildMiniTotalRow(totalPagar, AppColors.error, Icons.arrow_upward_rounded),
              if (countReceber > 0)
                _buildMiniTotalRow(totalReceber, AppColors.success, Icons.arrow_downward_rounded),
            ] else
              Text(
                'Sem lancamentos',
                style: TextStyle(
                  fontSize: 9,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniTotalRow(double value, Color color, IconData icon) {
    String formattedValue;
    if (value >= 1000000) {
      formattedValue = '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      formattedValue = '${(value / 1000).toStringAsFixed(0)}K';
    } else {
      formattedValue = UtilBrasilFields.obterReal(value);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 10),
        const SizedBox(width: 2),
        Text(
          formattedValue,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  void _pickMonthYear() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _focusedDay,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (result != null) {
      setState(() {
        _focusedDay = result;
        _calculateMonthTotals();
      });
    }
  }

  Widget _buildEventTile(Account account) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCard = account.cardBrand != null;
    final isRecurrent = account.isRecurrent || account.recurrenceId != null;
    final isPrevisao = isRecurrent && account.id == null;
    final isRecebimento = _recebimentosTypeIds.contains(account.typeId);
    final displayValue = (isRecurrent && account.value <= 0.01)
        ? (account.estimatedValue ?? account.value)
        : account.value;

    Color valueColor;
    Color cardBgColor;
    if (isRecebimento) {
      valueColor = AppColors.successDark;
      cardBgColor = AppColors.success.withValues(alpha: 0.08);
    } else if (isCard) {
      valueColor = AppColors.cardPurple;
      cardBgColor = Colors.purple.withValues(alpha: 0.08);
    } else {
      valueColor = AppColors.error;
      cardBgColor = AppColors.error.withValues(alpha: 0.08);
    }

    IconData leadingIcon;
    Color iconBgColor;
    if (isCard) {
      leadingIcon = Icons.credit_card;
      iconBgColor = account.cardColor != null
          ? Color(account.cardColor!)
          : Colors.purple;
    } else if (isRecebimento) {
      leadingIcon = Icons.arrow_downward_rounded;
      iconBgColor = AppColors.success;
    } else {
      leadingIcon = Icons.arrow_upward_rounded;
      iconBgColor = AppColors.error;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: valueColor.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconBgColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            leadingIcon,
            color: iconBgColor,
            size: 18,
          ),
        ),
        title: Text(
          account.description,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            if (isPrevisao)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'PREVISAO',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              )
            else if (isRecurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'LANCADO',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: AppColors.successDark,
                  ),
                ),
              ),
            if (isCard)
              Text(
                '${account.cardBank} - ${account.cardBrand}',
                style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
              ),
          ],
        ),
        trailing: Text(
          UtilBrasilFields.obterReal(displayValue),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: valueColor,
          ),
        ),
      ),
    );
  }
}
