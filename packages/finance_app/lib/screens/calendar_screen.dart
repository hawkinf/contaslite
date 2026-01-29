import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:brasil_fields/brasil_fields.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../models/calendar_export_snapshot.dart';
import '../services/app_startup_controller.dart';
import '../services/holiday_service.dart';
import '../services/prefs_service.dart';
import '../ui/components/period_header.dart';
import '../ui/components/ff_design_system.dart';
import '../utils/app_colors.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  FFCalendarViewMode _viewMode = FFCalendarViewMode.monthly;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, List<Account>> _events = {};
  bool _isLoading = true;
  Set<int> _recebimentosTypeIds = {};
  Map<int, String> _typeNames = {};

  // ScrollController for weekly view
  final ScrollController _weeklyScrollController = ScrollController();

  // Listener para jump to today
  late final VoidCallback _jumpToTodayListener;

  // Totais gerais do mês
  double _totalPagarMes = 0;
  double _totalReceberMes = 0;
  int _countPagarMes = 0;
  int _countReceberMes = 0;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;

    // Listener para jump to today (vindo do AppStartupController)
    _jumpToTodayListener = () {
      if (AppStartupController.jumpToTodayNotifier.value) {
        _jumpToToday();
      }
    };
    AppStartupController.jumpToTodayNotifier.addListener(_jumpToTodayListener);

    // Registrar provider de exportação
    PrefsService.calendarExportStateProvider = _buildExportSnapshot;

    _loadEvents();
  }

  @override
  void dispose() {
    AppStartupController.jumpToTodayNotifier.removeListener(_jumpToTodayListener);
    _weeklyScrollController.dispose();
    // Limpar provider de exportação
    PrefsService.calendarExportStateProvider = null;
    super.dispose();
  }

  /// Constrói o snapshot para exportação do calendário
  CalendarExportSnapshot? _buildExportSnapshot() {
    if (_isLoading) return null;

    final city = PrefsService.cityNotifier.value;
    final selectedDay = _selectedDay ?? _focusedDay;

    // Densidade baseada em largura padrão para export (A4 width ~595)
    final density = FFCalendarDensity.regular;

    // Construir células do mês (42 dias = 6 semanas)
    final monthCells = <CalendarDayCellModel>[];
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);

    // Encontrar primeiro domingo da primeira semana
    final firstSunday = firstDayOfMonth.subtract(
      Duration(days: firstDayOfMonth.weekday % 7),
    );

    for (int i = 0; i < 42; i++) {
      final date = firstSunday.add(Duration(days: i));
      final isOutside = date.month != _focusedDay.month;
      final isToday = DateUtils.isSameDay(date, DateTime.now());
      final isSelected = DateUtils.isSameDay(date, selectedDay);
      final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
      final isHoliday = HolidayService.isHoliday(date, city);

      monthCells.add(CalendarDayCellModel(
        date: date,
        isToday: isToday,
        isSelected: isSelected,
        isWeekend: isWeekend,
        isHoliday: isHoliday,
        isOutsideMonth: isOutside,
        totals: _getDayTotals(date),
      ));
    }

    // Construir dias da semana (7 dias)
    final weekStart = _focusedDay.subtract(Duration(days: _focusedDay.weekday % 7));
    final weekDays = List.generate(7, (i) {
      final date = weekStart.add(Duration(days: i));
      final dayName = DateFormat('EEE', 'pt_BR').format(date).toUpperCase();
      return CalendarWeekDayModel(
        date: date,
        dayName: dayName,
        isToday: DateUtils.isSameDay(date, DateTime.now()),
        isWeekend: date.weekday == DateTime.saturday || date.weekday == DateTime.sunday,
        totals: _getDayTotals(date),
      );
    });

    // Construir meses do ano (12 meses)
    final yearMonths = List.generate(12, (i) {
      final month = i + 1;
      final monthDate = DateTime(_focusedDay.year, month, 1);
      final monthName = DateFormat('MMM', 'pt_BR').format(monthDate);
      final isCurrentMonth = month == DateTime.now().month && _focusedDay.year == DateTime.now().year;
      return CalendarMiniMonthModel(
        month: month,
        year: _focusedDay.year,
        monthName: monthName,
        isCurrentMonth: isCurrentMonth,
        totals: _getMonthTotals(month, _focusedDay.year),
      );
    });

    // Construir itens da agenda do dia selecionado
    final dayEvents = _getEventsForDay(selectedDay);
    final agendaItems = dayEvents.map((account) {
      final isRecurrent = account.isRecurrent || account.recurrenceId != null;
      final isPrevisao = isRecurrent && account.id == null;
      final isRecebimento = _recebimentosTypeIds.contains(account.typeId);
      final isCard = account.cardBrand != null;
      final displayValue = (isRecurrent && account.value <= 0.01)
          ? (account.estimatedValue ?? account.value)
          : account.value;

      return CalendarAgendaItem(
        account: account,
        effectiveDate: selectedDay,
        isRecebimento: isRecebimento,
        isCard: isCard,
        isRecurrent: isRecurrent,
        isPrevisao: isPrevisao,
        displayValue: displayValue,
        typeName: _typeNames[account.typeId]
      );
    }).toList();

    return CalendarExportSnapshot(
      mode: _viewMode,
      density: density,
      anchorDate: _focusedDay,
      selectedDate: selectedDay,
      periodLabel: _getPeriodLabel(),
      periodTotals: FFPeriodTotals(
        totalPagar: _totalPagarMes,
        totalReceber: _totalReceberMes,
        countPagar: _countPagarMes,
        countReceber: _countReceberMes,
      ),
      monthCells: monthCells,
      weekDays: weekDays,
      yearMonths: yearMonths,
      agendaItems: agendaItems,
      typeNames: _typeNames,
    );
  }

  /// Navega para o dia de hoje
  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedDay = now;
      _selectedDay = now;
    });
    _calculateMonthTotals();
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

      _typeNames = {for (var t in types) if (t.id != null) t.id!: t.name};

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

  FFDayTotals _getDayTotals(DateTime day) {
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

    return FFDayTotals(
      totalPagar: totalPagar,
      totalReceber: totalReceber,
      countPagar: countPagar,
      countReceber: countReceber,
    );
  }

  FFPeriodTotals _getMonthTotals(int month, int year) {
    double totalPagar = 0;
    double totalReceber = 0;
    int countPagar = 0;
    int countReceber = 0;

    _events.forEach((dateKey, accounts) {
      final parts = dateKey.split('-');
      final eventYear = int.parse(parts[0]);
      final eventMonth = int.parse(parts[1]);

      if (eventMonth == month && eventYear == year) {
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

    return FFPeriodTotals(
      totalPagar: totalPagar,
      totalReceber: totalReceber,
      countPagar: countPagar,
      countReceber: countReceber,
    );
  }

  void _showDayDetailsModal(DateTime day) {
    final events = _getEventsForDay(day);
    if (events.isEmpty) return;

    final totals = _getDayTotals(day);
    final dateFormatted = DateFormat('dd \'de\' MMMM \'de\' yyyy', 'pt_BR').format(day);
    final weekdayName = DateFormat('EEEE', 'pt_BR').format(day);

    FFDayDetailsModal.show(
      context: context,
      date: day,
      dateFormatted: dateFormatted,
      weekdayName: weekdayName,
      totals: totals,
      currencyFormatter: (value) => UtilBrasilFields.obterReal(value),
      eventsBuilder: (scrollController) => ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final account = events[index];
          return _buildEventTile(account);
        },
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
              // Seletor de modo (Semanal/Mensal/Anual) - FF*
              FFCalendarModeSelector(
                currentMode: _viewMode,
                onModeChanged: (mode) => setState(() => _viewMode = mode),
              ),
              // Totais do periodo - FF*
              FFCalendarTotalsBar(
                totals: FFPeriodTotals(
                  totalPagar: _totalPagarMes,
                  totalReceber: _totalReceberMes,
                  countPagar: _countPagarMes,
                  countReceber: _countReceberMes,
                ),
                currencyFormatter: (value) => UtilBrasilFields.obterReal(value),
              ),
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
      case FFCalendarViewMode.weekly:
      case FFCalendarViewMode.monthly:
        label = DateFormat('MMMM yyyy', 'pt_BR').format(_focusedDay);
        break;
      case FFCalendarViewMode.yearly:
        label = _focusedDay.year.toString();
        break;
    }
    // Capitalizar primeira letra
    return label[0].toUpperCase() + label.substring(1);
  }

  /// Callbacks de navegação baseados no modo atual
  VoidCallback get _onPrevious {
    switch (_viewMode) {
      case FFCalendarViewMode.weekly:
        return () => _changeWeek(-1);
      case FFCalendarViewMode.monthly:
        return () => _changeMonth(-1);
      case FFCalendarViewMode.yearly:
        return () => _changeYear(-1);
    }
  }

  VoidCallback get _onNext {
    switch (_viewMode) {
      case FFCalendarViewMode.weekly:
        return () => _changeWeek(1);
      case FFCalendarViewMode.monthly:
        return () => _changeMonth(1);
      case FFCalendarViewMode.yearly:
        return () => _changeYear(1);
    }
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
          FFCalendarViewMode.weekly => _buildWeeklyView(colorScheme, isDark),
          FFCalendarViewMode.monthly => _buildMonthlyView(colorScheme, isDark),
          FFCalendarViewMode.yearly => _buildYearlyView(colorScheme, isDark),
        },
      ),
    );
  }

  /// MODO SEMANAL - usando FFWeekDayCard
  Widget _buildWeeklyView(ColorScheme colorScheme, bool isDark) {
    // Encontrar o inicio da semana (domingo)
    final weekStart = _focusedDay.subtract(Duration(days: _focusedDay.weekday % 7));
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));

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
        itemBuilder: (context, index) {
          final day = days[index];
          final dayName = DateFormat('EEE', 'pt_BR').format(day).toUpperCase();
          final isToday = DateUtils.isSameDay(day, DateTime.now());
          final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
          final totals = _getDayTotals(day);

          return FFWeekDayCard(
            day: day.day,
            dayName: dayName,
            isToday: isToday,
            isWeekend: isWeekend,
            totals: totals,
            onTap: () => _showDayDetailsModal(day),
            currencyFormatter: (value) => UtilBrasilFields.obterReal(value),
          );
        },
      ),
    );
  }

  /// MODO MENSAL - usando TableCalendar com FFWeekdayRow e FFDayTile
  Widget _buildMonthlyView(ColorScheme colorScheme, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;

        // Responsividade: desktop >= 1100px, tablet >= 600px, mobile < 600px
        final bool isDesktop = screenWidth >= 1100;
        final bool isTablet = screenWidth >= 600 && screenWidth < 1100;

        // Tamanhos responsivos para o cabeçalho dos dias da semana
        final double weekdayFontSize = isDesktop ? 15 : (isTablet ? 13 : 11);
        final double weekdayLetterSpacing = isDesktop ? 0.8 : 0.5;

        // Tamanhos responsivos para o número do dia
        final double dayFontSize = isDesktop ? 24 : (isTablet ? 20 : 16);

        // Altura das células e do cabeçalho
        final double daysHeaderHeight = isDesktop ? 48 : (isTablet ? 42 : 36);

        // Calcular altura das células para preencher o espaço disponível
        final double availableHeight = screenHeight - daysHeaderHeight - 16;
        final double calculatedRowHeight = (availableHeight / 6).clamp(
          isDesktop ? 96.0 : 70.0,
          isDesktop ? 140.0 : 100.0,
        );

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
          daysOfWeekHeight: daysHeaderHeight,
          rowHeight: calculatedRowHeight,
          headerVisible: false,
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(
              fontSize: weekdayFontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: weekdayLetterSpacing,
              color: colorScheme.onSurfaceVariant,
            ),
            weekendStyle: TextStyle(
              fontSize: weekdayFontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: weekdayLetterSpacing,
              color: AppColors.error.withValues(alpha: 0.85),
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          calendarStyle: CalendarStyle(
            markersMaxCount: 0,
            cellMargin: EdgeInsets.all(isDesktop ? 3 : 2),
            defaultTextStyle: TextStyle(fontSize: dayFontSize),
            weekendTextStyle: TextStyle(
              fontSize: dayFontSize,
              color: AppColors.error.withValues(alpha: 0.7),
            ),
            outsideTextStyle: TextStyle(
              fontSize: dayFontSize * 0.85,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            todayDecoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.6),
                width: 2,
              ),
            ),
            todayTextStyle: TextStyle(
              fontSize: dayFontSize,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
            selectedDecoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.6),
                width: 2,
              ),
            ),
            selectedTextStyle: TextStyle(
              fontSize: dayFontSize,
              fontWeight: FontWeight.bold,
              color: AppColors.successDark,
            ),
          ),
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) {
              return _buildMonthDayCell(day, colorScheme, dayFontSize, false, false, isDesktop: isDesktop);
            },
            todayBuilder: (context, day, focusedDay) {
              return _buildMonthDayCell(day, colorScheme, dayFontSize, true, false, isDesktop: isDesktop);
            },
            selectedBuilder: (context, day, focusedDay) {
              return _buildMonthDayCell(day, colorScheme, dayFontSize, false, true, isDesktop: isDesktop);
            },
            outsideBuilder: (context, day, focusedDay) {
              return _buildMonthDayCell(day, colorScheme, dayFontSize * 0.85, false, false, isOutside: true, isDesktop: isDesktop);
            },
          ),
        );
      },
    );
  }

  Widget _buildMonthDayCell(DateTime day, ColorScheme colorScheme, double fontSize, bool isToday, bool isSelected, {bool isOutside = false, bool isDesktop = false}) {
    final totals = _getDayTotals(day);
    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final city = PrefsService.cityNotifier.value;
    final isHoliday = HolidayService.isHoliday(day, city);

    return FFDayTile(
      day: day.day,
      isToday: isToday,
      isSelected: isSelected,
      isWeekend: isWeekend,
      isHoliday: isHoliday,
      isOutsideMonth: isOutside,
      totals: totals,
      isDesktop: isDesktop,
      dayFontSize: fontSize,
      onTap: totals.hasEvents ? () => _showDayDetailsModal(day) : null,
    );
  }

  /// MODO ANUAL - usando FFMiniMonthCard
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
        final monthDate = DateTime(_focusedDay.year, month, 1);
        final monthName = DateFormat('MMM', 'pt_BR').format(monthDate);
        final isCurrentMonth = month == DateTime.now().month && _focusedDay.year == DateTime.now().year;
        final totals = _getMonthTotals(month, _focusedDay.year);

        return FFMiniMonthCard(
          monthName: monthName,
          isCurrentMonth: isCurrentMonth,
          totals: totals,
          onTap: () {
            setState(() {
              _focusedDay = DateTime(_focusedDay.year, month, 1);
              _viewMode = FFCalendarViewMode.monthly;
              _calculateMonthTotals();
            });
          },
        );
      },
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
