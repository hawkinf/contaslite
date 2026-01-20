import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:brasil_fields/brasil_fields.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../services/holiday_service.dart';
import '../services/prefs_service.dart';
import '../utils/app_colors.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, List<Account>> _events = {};
  bool _isLoading = true;
  Set<int> _recebimentosTypeIds = {};

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
          // Para recorrências, usar estimatedValue se value for 0
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
      final allAccounts = await DatabaseHelper.instance.readAllAccountsRaw();
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

      final normalAccounts = allAccounts.where((a) =>
          a.cardBrand == null && !a.isRecurrent && a.recurrenceId == null).toList();
      final recurrents = allAccounts.where((a) =>
          a.cardBrand == null && a.isRecurrent && a.recurrenceId == null).toList();
      final launchedInstances = allAccounts.where((a) =>
          a.cardBrand == null && a.recurrenceId != null).toList();

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
    } catch (e, stack) {
      debugPrint('❌ Erro ao carregar eventos: $e');
      debugPrint('Stack: $stack');
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

  /// Calcula totais de um dia específico
  /// Para contas recorrentes não lançadas (value == 0), usa estimatedValue
  (double pagar, double receber, int countPagar, int countReceber) _getDayTotals(DateTime day) {
    final events = _getEventsForDay(day);
    double totalPagar = 0;
    double totalReceber = 0;
    int countPagar = 0;
    int countReceber = 0;

    for (var event in events) {
      // Para recorrências, usar estimatedValue se value for 0
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

  /// Mostra modal flutuante com detalhes do dia
  void _showDayDetailsModal(DateTime day) {
    final events = _getEventsForDay(day);
    if (events.isEmpty) return;

    final (totalPagar, totalReceber, countPagar, countReceber) = _getDayTotals(day);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            color: isDark ? Colors.grey.shade900 : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
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
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header com data e totais
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Data
                    Text(
                      DateFormat('dd \'de\' MMMM \'de\' yyyy', 'pt_BR').format(day),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      DateFormat('EEEE', 'pt_BR').format(day),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Cards de totais
                    Row(
                      children: [
                        Expanded(
                          child: _buildTotalCard(
                            title: 'A Pagar',
                            value: totalPagar,
                            count: countPagar,
                            color: Colors.red,
                            icon: Icons.arrow_upward,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTotalCard(
                            title: 'A Receber',
                            value: totalReceber,
                            count: countReceber,
                            color: Colors.green,
                            icon: Icons.arrow_downward,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Lista de contas
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _buildTotalCard({
    required String title,
    required double value,
    required int count,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: isDark ? 0.3 : 0.15),
            color.withValues(alpha: isDark ? 0.15 : 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            UtilBrasilFields.obterReal(value),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            '$count ${count == 1 ? 'conta' : 'contas'}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
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

  Widget _buildMonthNavigator() {
    final monthYear = DateFormat('MMMM yyyy', 'pt_BR').format(_focusedDay);
    final capitalizedMonth = monthYear[0].toUpperCase() + monthYear.substring(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _changeMonth(-1),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_left,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              capitalizedMonth,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          InkWell(
            onTap: () => _changeMonth(1),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_right,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final cellWidth = screenWidth / 7;
    final dayOfWeekFontSize = cellWidth * 0.28;
    final dayFontSize = cellWidth * 0.35;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? Colors.blue.shade900 : Colors.blue.shade700,
        foregroundColor: Colors.white,
        title: _buildMonthNavigator(),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Ir para hoje',
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
                _calculateMonthTotals();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
            onPressed: _loadEvents,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header com totais do mês
                _buildMonthTotalsHeader(isDark),
                // Calendário
                Expanded(
                  child: TableCalendar<Account>(
                    locale: 'pt_BR',
                    firstDay: DateTime.now().subtract(const Duration(days: 365)),
                    lastDay: DateTime.now().add(const Duration(days: 365)),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
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
                    onFormatChanged: (format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      setState(() {
                        _focusedDay = focusedDay;
                        _calculateMonthTotals();
                      });
                    },
                    daysOfWeekHeight: 40,
                    rowHeight: 80,
                    headerVisible: false, // Escondemos o header padrão
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: TextStyle(
                        fontSize: dayOfWeekFontSize,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      weekendStyle: TextStyle(
                        fontSize: dayOfWeekFontSize,
                        fontWeight: FontWeight.w900,
                        color: Colors.red.shade600,
                      ),
                    ),
                    calendarStyle: CalendarStyle(
                      markersMaxCount: 0,
                      cellMargin: const EdgeInsets.all(2),
                      defaultTextStyle: TextStyle(fontSize: dayFontSize),
                      weekendTextStyle: TextStyle(
                        fontSize: dayFontSize,
                        color: Colors.red.shade400,
                      ),
                      outsideTextStyle: TextStyle(
                        fontSize: dayFontSize,
                        color: Colors.grey.shade400,
                      ),
                      todayDecoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      todayTextStyle: TextStyle(
                        fontSize: dayFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: isDark ? AppColors.successDark.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      selectedTextStyle: TextStyle(
                        fontSize: dayFontSize,
                        fontWeight: FontWeight.bold,
                        color: AppColors.successDark,
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) {
                        return _buildDayCell(day, isDark, dayFontSize, false, false);
                      },
                      todayBuilder: (context, day, focusedDay) {
                        return _buildDayCell(day, isDark, dayFontSize, true, false);
                      },
                      selectedBuilder: (context, day, focusedDay) {
                        return _buildDayCell(day, isDark, dayFontSize, false, true);
                      },
                      outsideBuilder: (context, day, focusedDay) {
                        return _buildDayCell(day, isDark, dayFontSize * 0.8, false, false, isOutside: true);
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMonthTotalsHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Contas a Pagar
          _buildHeaderTotal(
            label: 'Contas a Pagar:',
            value: _totalPagarMes,
            count: _countPagarMes,
            suffix: 'D',
            color: Colors.red.shade700,
            isDark: isDark,
          ),
          // Contas a Receber
          _buildHeaderTotal(
            label: 'Contas a Receber:',
            value: _totalReceberMes,
            count: _countReceberMes,
            suffix: 'C',
            color: Colors.green.shade700,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderTotal({
    required String label,
    required double value,
    required int count,
    required String suffix,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          UtilBrasilFields.obterReal(value),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          suffix,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        if (count > 0) ...[
          const SizedBox(width: 6),
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
      ],
    );
  }

  Widget _buildDayCell(DateTime day, bool isDark, double fontSize, bool isToday, bool isSelected, {bool isOutside = false}) {
    final (totalPagar, totalReceber, countPagar, countReceber) = _getDayTotals(day);
    final hasEvents = countPagar > 0 || countReceber > 0;
    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

    // Cores do texto do dia
    Color dayTextColor;
    if (isOutside) {
      dayTextColor = Colors.grey.shade400;
    } else if (isToday) {
      dayTextColor = Colors.blue;
    } else if (isSelected) {
      dayTextColor = AppColors.successDark;
    } else if (isWeekend) {
      dayTextColor = Colors.red.shade400;
    } else {
      dayTextColor = isDark ? Colors.white : Colors.black87;
    }

    // Background do dia
    BoxDecoration? dayDecoration;
    if (isToday) {
      dayDecoration = BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.5), width: 1.5),
      );
    } else if (isSelected) {
      dayDecoration = BoxDecoration(
        color: AppColors.successDark.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.successDark.withValues(alpha: 0.5), width: 1.5),
      );
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: dayDecoration,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Número do dia
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.w500,
              color: dayTextColor,
            ),
          ),
          // Badges de totais
          if (hasEvents && !isOutside) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (countPagar > 0)
                  _buildBadge(
                    value: totalPagar,
                    count: countPagar,
                    color: Colors.red,
                    isCompact: countReceber > 0,
                  ),
                if (countPagar > 0 && countReceber > 0)
                  const SizedBox(width: 2),
                if (countReceber > 0)
                  _buildBadge(
                    value: totalReceber,
                    count: countReceber,
                    color: Colors.green,
                    isCompact: countPagar > 0,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge({
    required double value,
    required int count,
    required Color color,
    required bool isCompact,
  }) {
    // Formatar valor de forma compacta
    String formattedValue;
    if (value >= 1000000) {
      formattedValue = '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      formattedValue = '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      formattedValue = value.toStringAsFixed(0);
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 3 : 4,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        formattedValue,
        style: TextStyle(
          fontSize: isCompact ? 8 : 9,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildEventTile(Account account) {
    final isCard = account.cardBrand != null;
    final isRecurrent = account.isRecurrent || account.recurrenceId != null;
    final isPrevisao = isRecurrent && account.id == null;
    final isRecebimento = _recebimentosTypeIds.contains(account.typeId);
    // Para recorrências, usar estimatedValue se value for 0
    final displayValue = (isRecurrent && account.value <= 0.01)
        ? (account.estimatedValue ?? account.value)
        : account.value;

    Color valueColor;
    Color cardBgColor;
    if (isRecebimento) {
      valueColor = AppColors.successDark;
      cardBgColor = Colors.green.withValues(alpha: 0.1);
    } else if (isCard) {
      valueColor = AppColors.cardPurple;
      cardBgColor = Colors.purple.withValues(alpha: 0.1);
    } else {
      valueColor = Colors.red.shade700;
      cardBgColor = Colors.red.withValues(alpha: 0.1);
    }

    IconData leadingIcon;
    Color iconBgColor;
    if (isCard) {
      leadingIcon = Icons.credit_card;
      iconBgColor = account.cardColor != null
          ? Color(account.cardColor!)
          : Colors.purple;
    } else if (isRecebimento) {
      leadingIcon = Icons.arrow_downward;
      iconBgColor = Colors.green;
    } else {
      leadingIcon = Icons.arrow_upward;
      iconBgColor = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: valueColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconBgColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            leadingIcon,
            color: iconBgColor,
            size: 20,
          ),
        ),
        title: Text(
          account.description,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            if (isPrevisao)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PREVISÃO',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              )
            else if (isRecurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'LANÇADO',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            if (isCard)
              Text(
                '${account.cardBank} - ${account.cardBrand}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              UtilBrasilFields.obterReal(displayValue),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: valueColor,
              ),
            ),
            Text(
              isRecebimento ? 'Recebimento' : 'Pagamento',
              style: TextStyle(
                fontSize: 10,
                color: valueColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
