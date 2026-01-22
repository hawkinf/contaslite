// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:brasil_fields/brasil_fields.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../services/prefs_service.dart';
import '../services/holiday_service.dart';
import '../utils/color_contrast.dart';
import 'card_expenses_screen.dart';
import '../utils/app_colors.dart';
import '../utils/installment_utils.dart';
import '../widgets/app_input_decoration.dart';
import '../widgets/new_expense_dialog.dart';
import '../widgets/payment_dialog.dart';
import '../widgets/date_range_app_bar.dart';
import '../widgets/single_day_app_bar.dart';
import '../utils/card_utils.dart';
import 'account_form_screen.dart';
import 'recebimento_form_screen.dart';
import 'credit_card_form.dart';

class _InstallmentSummary {
  final double totalAmount;
  final double remainingAmount;
  final DateTime? nextDueDate;
  final double? nextValue;

  const _InstallmentSummary({
    required this.totalAmount,
    required this.remainingAmount,
    this.nextDueDate,
    this.nextValue,
  });
}

class _CalendarHole extends StatelessWidget {
  final Color fill;
  final Color border;
  final double scale;
  const _CalendarHole({required this.fill, required this.border, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12 * scale,
      height: 12 * scale,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 0.8,
          colors: [
            fill.withValues(alpha: 0.95),
            fill.withValues(alpha: 0.7),
          ],
        ),
        border: Border.all(color: border, width: 1.5 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 2 * scale,
            offset: Offset(0, 1 * scale),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 4 * scale,
          height: 4 * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: border.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}


class _SeriesSummary {
  final double totalAmount;
  final List<double> remainingFromIndex;
  final Map<int, int> idToIndex;
  final List<Account> orderedInstallments;

  const _SeriesSummary({
    required this.totalAmount,
    required this.remainingFromIndex,
    required this.idToIndex,
    required this.orderedInstallments,
  });

  _InstallmentSummary? summaryFor(Account account, InstallmentDisplay display) {
    int? idx;
    if (account.id != null) {
      idx = idToIndex[account.id!];
    }
    idx ??= display.index - 1;
    if (idx < 0 || idx >= remainingFromIndex.length) {
      return null;
    }
    DateTime? nextDueDate;
    double? nextValue;
    final nextIndex = idx + 1;
    if (nextIndex < orderedInstallments.length) {
      final nextAccount = orderedInstallments[nextIndex];
      final nextYear = nextAccount.year ?? DateTime.now().year;
      final nextMonth = nextAccount.month ?? DateTime.now().month;
      nextDueDate = DateTime(nextYear, nextMonth, nextAccount.dueDay);
      nextValue = nextAccount.value;
    }
    return _InstallmentSummary(
      totalAmount: totalAmount,
      remainingAmount: remainingFromIndex[idx],
      nextDueDate: nextDueDate,
      nextValue: nextValue,
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final String? typeNameFilter;
  final String? excludeTypeNameFilter;
  final Color? appBarColorOverride;
  final String? totalLabelOverride;
  final String? totalForecastLabelOverride;
  final String? emptyTextOverride;

  const DashboardScreen({
    super.key,
    this.typeNameFilter,
    this.excludeTypeNameFilter,
    this.appBarColorOverride,
    this.totalLabelOverride,
    this.totalForecastLabelOverride,
    this.emptyTextOverride,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isInlineEditing = false;
  bool _isNavigating = false;
  Widget? _inlineEditWidget; // Widget de edição inline
  bool _inlinePreserveAppBar = false;

  Future<void>? _activeLoad;
  bool _pendingReload = false;
  int _loadCounter = 0;
  String _currentLoadStage = '';

  late final VoidCallback _dateRangeListener;
  // ... (Variáveis de estado mantidas)
  late DateTime _startDate;
  late DateTime _endDate;
  bool _datesInitialized = false;
  List<Account> _displayList = [];
  Map<int, String> _typeNames = {};
  Map<int, String> _typeLogos = {};
  Map<int, String> _categoryNames = {};
  Map<int, String> _categoryLogos = {};
  bool _isLoading = false;
  double _totalPeriod = 0.0;
  double _totalForecast = 0.0;
  double _totalPrevistoPagar = 0.0;
  double _totalPrevistoReceber = 0.0;
  // Totais para visão combinada
  double _totalLancadoPagar = 0.0;
  double _totalLancadoReceber = 0.0;
  Map<int, _InstallmentSummary> _installmentSummaries = {};
  Map<int, Map<String, dynamic>> _paymentInfo = {};
  final Map<int, double> _recurrenceParentValues = {}; // Mapeia recurrence ID -> valor previsto
  bool _showContasPagar = true;
  bool _showContasReceber = true;
  bool _showCartoesCredito = true;
  
  // Novos filtros
  bool _hidePaidAccounts = true; // Ocultar contas pagas/recebidas (true = oculta)
  String _periodFilter = 'month'; // 'month', 'currentWeek', 'nextWeek'
  // Controle do FAB durante scroll
  bool _isFabVisible = true;
  double _lastScrollOffset = 0;
  
  // Estado de seleção de card
  int? _selectedAccountId;
  int? _hoveredAccountId; // Rastrear card em hover

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final currentOffset = notification.metrics.pixels;
      final delta = currentOffset - _lastScrollOffset;

      // Scroll para baixo (delta > 0) -> esconde FAB
      // Scroll para cima (delta < 0) -> mostra FAB
      if (delta > 2 && _isFabVisible) {
        setState(() => _isFabVisible = false);
      } else if (delta < -2 && !_isFabVisible) {
        setState(() => _isFabVisible = true);
      }

      _lastScrollOffset = currentOffset;
    }
    return false;
  }


  @override
  void dispose() {
    PrefsService.dateRangeNotifier.removeListener(_dateRangeListener);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _dateRangeListener = () {
      final range = PrefsService.dateRangeNotifier.value;
      setState(() {
        if (DateUtils.isSameDay(range.start, range.end)) {
          _startDate = range.start;
          _endDate = range.end;
        } else {
          _startDate = DateTime(range.start.year, range.start.month, 1);
          _endDate = DateTime(range.start.year, range.start.month + 1, 0);
        }
        _datesInitialized = true;
      });
      _loadData();
    };
    PrefsService.dateRangeNotifier.addListener(_dateRangeListener);
    _initDates();
  }

  Future<void> _initDates() async {
    final range = PrefsService.dateRangeNotifier.value;
    DateTime start;
    DateTime end;
    if (DateUtils.isSameDay(range.start, range.end)) {
      start = range.start;
      end = range.end;
    } else {
      start = DateTime(range.start.year, range.start.month, 1);
      end = DateTime(range.start.year, range.start.month + 1, 0);
    }
    setState(() {
      _startDate = start;
      _endDate = end;
      _datesInitialized = true;
    });
    _loadData();
  }

  void _changeMonth(int offset) {
    DateTime newStart = DateTime(_startDate.year, _startDate.month + offset, 1);
    DateTime newEnd = DateTime(newStart.year, newStart.month + 1, 0);
    PrefsService.saveDateRange(newStart, newEnd);
  }

  void _refresh() => _loadData();

  Color _adaptiveGreyTextColor(BuildContext context, Color lightGrey, {Color? darkGrey}) {
    return Theme.of(context).brightness == Brightness.dark ? (darkGrey ?? Colors.grey.shade600) : lightGrey;
  }

  void _applyPeriodFilter(String filter) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (filter) {
      case 'currentWeek':
        // Início da semana (domingo) até fim (sábado)
        final weekday = now.weekday % 7; // Domingo = 0
        start = DateTime(now.year, now.month, now.day - weekday);
        end = start.add(const Duration(days: 6));
        break;
      case 'nextWeek':
        // Próxima semana
        final weekday = now.weekday % 7;
        final nextSunday = DateTime(now.year, now.month, now.day - weekday + 7);
        start = nextSunday;
        end = start.add(const Duration(days: 6));
        break;
      case 'month':
      default:
        // Mês inteiro
        start = DateTime(_startDate.year, _startDate.month, 1);
        end = DateTime(_startDate.year, _startDate.month + 1, 0);
        break;
    }

    setState(() {
      _startDate = start;
      _endDate = end;
    });
    _loadData();
  }

  bool get _isCombinedView => widget.typeNameFilter == null && widget.excludeTypeNameFilter == null;

  List<Widget> _buildAppBarActions({
    required bool includeFilter,
    Color? badgeFillColor,
  }) {
    if (!includeFilter) return <Widget>[];
    // Botão de filtro com badge - uniformizado com mesmo estilo
    return <Widget>[
      Transform.translate(
        offset: const Offset(-8, 0),
        child: IntrinsicWidth(
          child: Container(
            margin: const EdgeInsets.only(left: 20, right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF6B4A3E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2B1A14), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Checkbox(
                        value: _hidePaidAccounts,
                        onChanged: (value) {
                          setState(() => _hidePaidAccounts = value ?? true);
                          _loadData();
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: const BorderSide(color: Colors.transparent, width: 0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3),
                        ),
                        visualDensity: VisualDensity.compact,
                        activeColor: Colors.transparent,
                        checkColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Ocultar Contas Pagas',
                      style: TextStyle(
                        fontSize: 13.2,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Color(0xFF1A0F0B),
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7D7CE),
                    border: Border.all(color: const Color(0xFF2B1A14), width: 2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _periodFilter,
                      isDense: true,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _periodFilter = value);
                        _applyPeriodFilter(value);
                      },
                      icon: const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF2B1A14)),
                      style: const TextStyle(
                        fontSize: 13.2,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2B1A14),
                      ),
                      alignment: Alignment.center,
                      items: const [
                        DropdownMenuItem(
                          value: 'month',
                          child: Center(child: Text('Mês inteiro')),
                        ),
                        DropdownMenuItem(
                          value: 'currentWeek',
                          child: Center(child: Text('Semana atual')),
                        ),
                        DropdownMenuItem(
                          value: 'nextWeek',
                          child: Center(child: Text('Próxima semana')),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  bool _hasRecurrenceStarted(Account rec, DateTime current) {
    final hasStartDate = rec.year != null && rec.month != null;
    if (!hasStartDate) return true;
    return rec.year! < current.year || (rec.year == current.year && rec.month! <= current.month);
  }

  DateTime _resolveEffectiveDate(Account account, DateTime fallbackMonth) {
    final year = account.year ?? fallbackMonth.year;
    final month = account.month ?? fallbackMonth.month;
    int day = account.dueDay;
    int maxDays = DateUtils.getDaysInMonth(year, month);
    if (day > maxDays) day = maxDays;
    DateTime effectiveDate = DateTime(year, month, day);
    final isWeekend = HolidayService.isWeekend(effectiveDate);
    final isHoliday = HolidayService.isHoliday(effectiveDate, PrefsService.cityNotifier.value);
    if (isWeekend || isHoliday) {
      if (account.payInAdvance) {
        while (HolidayService.isWeekend(effectiveDate) ||
            HolidayService.isHoliday(effectiveDate, PrefsService.cityNotifier.value)) {
          effectiveDate = effectiveDate.subtract(const Duration(days: 1));
        }
      } else {
        while (HolidayService.isWeekend(effectiveDate) ||
            HolidayService.isHoliday(effectiveDate, PrefsService.cityNotifier.value)) {
          effectiveDate = effectiveDate.add(const Duration(days: 1));
        }
      }
    }
    return effectiveDate;
  }

  int? _normalizeYear(int? year) {
    if (year == null) return null;
    if (year < 100) return 2000 + year;
    return year;
  }

  Future<void> _loadData() async {
    if (!_datesInitialized) return;
    if (_activeLoad != null) {
      _pendingReload = true;
      return _activeLoad!;
    }

    final loadId = ++_loadCounter;
    final completer = Completer<void>();
    _activeLoad = completer.future;

    final stopwatch = Stopwatch()..start();
    Future<T> timed<T>(
      String label,
      Future<T> future, {
      Duration timeout = const Duration(seconds: 10),
    }) async {
      _currentLoadStage = label;
      debugPrint('⏳ DashboardScreen: $label (#$loadId)');
      final result = await future.timeout(timeout);
      debugPrint(
        '✅ DashboardScreen: $label ok (${stopwatch.elapsedMilliseconds}ms) (#$loadId)',
      );
      return result;
    }

    debugPrint('⏳ DashboardScreen: _loadData start (#$loadId)');
    setState(() => _isLoading = true);

    try {
      _currentLoadStage = 'readAllAccountsRaw';
      final allAccounts = await timed(
        'readAllAccountsRaw',
        DatabaseHelper.instance.readAllAccountsRaw(),
        timeout: const Duration(seconds: 15),
      );
      final types = await timed(
        'readAllTypes',
        DatabaseHelper.instance.readAllTypes(),
      );
      final categories = await timed(
        'readAllAccountCategories',
        DatabaseHelper.instance.readAllAccountCategories(),
      );
      final cards = await timed(
        'readAllCards',
        DatabaseHelper.instance.readAllCards(),
      );
      final typeMap = {for (var t in types) t.id!: t.name};
      final typeLogoMap = {
        for (final t in types)
          if (t.id != null && (t.logo?.trim().isNotEmpty ?? false))
            t.id!: t.logo!.trim(),
      };
      final categoryMap = {
        for (final c in categories)
          if (c.id != null) c.id!: c.categoria,
      };
      final categoryLogoMap = {
        for (final c in categories)
          if (c.id != null && (c.logo?.trim().isNotEmpty ?? false))
            c.id!: c.logo!.trim(),
      };

      debugPrint('📋 Tipos no banco: ${types.map((t) => '${t.name}(id: ${t.id})').join(', ')}');
      debugPrint('📋 Total de contas: ${allAccounts.length}');

      final typeFilter = widget.typeNameFilter?.trim();
      final excludeTypeFilter = widget.excludeTypeNameFilter?.trim();

      if (typeFilter != null) {
        debugPrint('🎯 typeNameFilter recebido: "$typeFilter"');
      }
      if (excludeTypeFilter != null) {
        debugPrint('🎯 excludeTypeNameFilter recebido: "$excludeTypeFilter"');
      }

      Set<int>? allowedTypeIds;
      Set<int>? excludedTypeIds;

      // Filtro de inclusão (mostrar apenas tipos específicos)
      if (typeFilter != null && typeFilter.isNotEmpty) {
        final normalizedFilter = typeFilter.toLowerCase();
        allowedTypeIds = types
            .where((t) => t.name.trim().toLowerCase() == normalizedFilter)
            .map((t) => t.id!)
            .toSet();
        if (allowedTypeIds.isEmpty) {
          allowedTypeIds = {};
        }
      }

      // Filtro de exclusão (esconder tipos específicos)
      if (excludeTypeFilter != null && excludeTypeFilter.isNotEmpty) {
        final normalizedFilter = excludeTypeFilter.toLowerCase();
        excludedTypeIds = types
            .where((t) => t.name.trim().toLowerCase() == normalizedFilter)
            .map((t) => t.id!)
            .toSet();
        debugPrint('🔍 Filtro de exclusão aplicado: $excludeTypeFilter → IDs: $excludedTypeIds');
      }

      if (allowedTypeIds != null) {
        debugPrint('🔍 Filtro de inclusão aplicado: $typeFilter → IDs: $allowedTypeIds');
      }

      // Preencher mapa de valores de recorrências pai
      _recurrenceParentValues.clear();
      _recurrenceParentValues.addAll({
        for (final acc in allAccounts.where((a) => a.isRecurrent && a.id != null))
          acc.id!: acc.value
      });

      List<Account> processedList = [];

      // Filtrar contas por categoria em uma única passagem
      final recurrents = allAccounts
          .where((a) => a.isRecurrent && a.cardBrand == null && a.cardId == null)
          .toList();
      // Filtrar lançamentos (inclui instâncias de recorrência)
      // Excluir contas com observation='[CANCELADA]' da exibição
      final normalExpenses = allAccounts
          .where((a) => a.cardId == null && !a.isRecurrent && a.cardBrand == null && a.observation != '[CANCELADA]')
          .toList();
      
      // Coletar também as instâncias canceladas para marcar o mês como "processado"
      final cancelledInstances = allAccounts
          .where((a) => a.observation == '[CANCELADA]')
          .toList();

      // Pré-computar índice de lançamentos para busca rápida
      final launchedIndex = <int, Set<String>>{};
      for (final exp in normalExpenses) {
        if (exp.recurrenceId != null) {
          final y = _normalizeYear(exp.year);
          if (y != null && exp.month != null) {
            final key = '${exp.recurrenceId}_${y}_${exp.month}';
            launchedIndex.putIfAbsent(exp.recurrenceId!, () => {}).add(key);
            debugPrint('📝 Lançamento indexado: recurrenceId=${exp.recurrenceId}, key=$key, description=${exp.description}');
          }
        }
      }
      // Também indexar instâncias canceladas para que o PAI não apareça
      for (final cancelled in cancelledInstances) {
        if (cancelled.recurrenceId != null) {
          final y = _normalizeYear(cancelled.year);
          if (y != null && cancelled.month != null) {
            final key = '${cancelled.recurrenceId}_${y}_${cancelled.month}';
            launchedIndex.putIfAbsent(cancelled.recurrenceId!, () => {}).add(key);
            debugPrint('🚫 Instância cancelada indexada: recurrenceId=${cancelled.recurrenceId}, key=$key');
          }
        }
      }
      debugPrint('🔍 launchedIndex completo: $launchedIndex');
      debugPrint('📊 normalExpenses ${normalExpenses.length} contas:');
      for (var exp in normalExpenses) {
        debugPrint('   - ${exp.description} (id=${exp.id}, recId=${exp.recurrenceId}, isRec=${exp.isRecurrent}, instTotal=${exp.installmentTotal}, ${exp.year}_${exp.month})');
      }

      // Processar contas pelo mês (não dia por dia)
      final accountsByMonth = <String, List<Account>>{};
      for (final acc in normalExpenses) {
        final normalizedYear = _normalizeYear(acc.year);
        if (normalizedYear == null || acc.month == null) continue;
        final key = '${normalizedYear}_${acc.month}';
        accountsByMonth.putIfAbsent(key, () => []).add(acc);
      }

      // Processar cada mês no intervalo (não dia por dia!)
      DateTime current = _startDate;
      final processedMonths = <String>{};
      while (current.isBefore(_endDate) || DateUtils.isSameDay(current, _endDate)) {
        final monthKey = '${current.year}_${current.month}';

        // Evitar processar o mesmo mês múltiplas vezes
        if (!processedMonths.contains(monthKey)) {
          processedMonths.add(monthKey);
          final monthAccounts = accountsByMonth[monthKey] ?? [];
          if (monthAccounts.isNotEmpty) {
            debugPrint('📋 Adicionando ${monthAccounts.length} contas do mês $monthKey:');
            for (var acc in monthAccounts) {
              debugPrint('   - ${acc.description} (id=${acc.id}, recurrenceId=${acc.recurrenceId}, value=${acc.value})');
            }
          }
          processedList.addAll(
            monthAccounts.where((account) => !(account.cardBrand != null && account.recurrenceId == null)),
          );

          // Adicionar recorrências não lançadas neste mês
          for (var rec in recurrents) {
            if (!_hasRecurrenceStarted(rec, current)) continue;

            final launchKey = '${rec.id}_${current.year}_${current.month}';
            final wasLaunched = launchedIndex[rec.id]?.contains(launchKey) ?? false;
            debugPrint('🔎 Verificando recorrência: ${rec.description} (id=${rec.id}), launchKey=$launchKey');
            debugPrint('   launchedIndex[${rec.id}] = ${launchedIndex[rec.id]}');
            debugPrint('   wasLaunched=$wasLaunched, value=${rec.value}');
              if (!wasLaunched) {
                debugPrint('➕ ADICIONANDO recorrência PAI: ${rec.description}');
                processedList.add(Account(
                  id: rec.id,
                  typeId: rec.typeId,
                  categoryId: rec.categoryId,
                  description: rec.description,
                  value: rec.value,
                  estimatedValue: rec.estimatedValue,
                  dueDay: rec.dueDay,
                  isRecurrent: true,
                recurrenceId: null,
                payInAdvance: rec.payInAdvance,
                month: current.month,
                year: current.year,
              ));
            } else {
              debugPrint('✅ PULANDO recorrência PAI pois foi lançada: ${rec.description} (id=${rec.id})');
            }
          }
        }

        current = current.add(const Duration(days: 1));
      }

      // Processar cartões: executar queries em paralelo com Future.wait
      final db = await DatabaseHelper.instance.database;
      final cardExpensesByCardId = <int, List<Account>>{};
      final cardSubscriptionsByCardId = <int, List<Account>>{};

      // Coletar todas as futures de queries
      final cardQueries = <Future<void>>[];

      for (var card in cards) {
        if (card.id == null) continue;

        // Executar queries em paralelo
        cardQueries.add(
          Future(() async {
            // Query para despesas do cartão
            final expenses = await DatabaseHelper.instance.getCardExpensesForMonth(
                card.id!, _startDate.month, _startDate.year);
            cardExpensesByCardId[card.id!] = expenses;

            // Query para subscrições do cartão
            final recurringRes = await db.query('accounts',
                where: 'cardId = ? AND isRecurrent = 1',
                whereArgs: [card.id]);
            cardSubscriptionsByCardId[card.id!] =
                recurringRes.map((e) => Account.fromMap(e)).toList();
          })
        );
      }

      // Executar todas as queries em paralelo
      if (cardQueries.isNotEmpty) {
        await Future.wait(cardQueries);
      }

      // Processar faturas dos cartões
      for (var card in cards) {
        if (card.id == null) continue;

        var launchedInvoices = allAccounts
            .where((a) =>
                a.recurrenceId == card.id &&
                !a.isRecurrent &&
                a.cardBrand != null &&
                a.month == _startDate.month &&
                a.year == _startDate.year)
            .toList();

        processedList.addAll(launchedInvoices);

        if (launchedInvoices.isEmpty) {
          final expenses = cardExpensesByCardId[card.id!] ?? [];
          final subs = cardSubscriptionsByCardId[card.id!] ?? [];

          double totalForecast = 0.0;
          double sumInst = 0.0;
          double sumOneOff = 0.0;
          double sumSubs = 0.0;

          // Calcular totais em uma passagem
          for (var exp in expenses) {
            totalForecast += exp.value;
            if (exp.description.contains(RegExp(r'\(\d+/\d+\)'))) {
              sumInst += exp.value;
            } else {
              sumOneOff += exp.value;
            }
          }

          for (var sub in subs) {
            if (!expenses.any((e) => e.recurrenceId == sub.id) && _hasRecurrenceStarted(sub, _startDate)) {
              totalForecast += sub.value;
              sumSubs += sub.value;
            }
          }

          String breakdown =
              'T:${totalForecast.toStringAsFixed(2)};P:${sumInst.toStringAsFixed(2)};V:${sumOneOff.toStringAsFixed(2)};A:${sumSubs.toStringAsFixed(2)}';

          processedList.add(Account(
            id: card.id,
            typeId: card.typeId,
            description: 'Fatura: ${card.cardBank} - ${card.cardBrand}',
            value: 0.0,
            dueDay: card.dueDay,
            month: _startDate.month,
            year: _startDate.year,
            isRecurrent: true,
            payInAdvance: card.payInAdvance,
            cardBrand: card.cardBrand,
            cardBank: card.cardBank,
            cardLimit: card.cardLimit,
            bestBuyDay: card.bestBuyDay,
            observation: breakdown,
            cardColor: card.cardColor,
          ));
        }
      }

      final filterSingleDay = DateUtils.isSameDay(_startDate, _endDate);
      if (filterSingleDay) {
        processedList = processedList
            .where((account) {
              final effectiveDate = _resolveEffectiveDate(account, _startDate);
              return DateUtils.isSameDay(effectiveDate, _startDate);
            })
            .toList();
      }

      debugPrint('📊 Antes de filtros: ${processedList.length} contas');
      debugPrint('   Detalhes: ${processedList.map((a) => '${a.description}(id=${a.id},rec=${a.isRecurrent},recId=${a.recurrenceId})').join(', ')}');

      // Aplicar filtro de inclusão (se especificado)
      if (allowedTypeIds != null) {
        final beforeFilter = processedList.length;
        processedList = processedList
            .where((account) => allowedTypeIds!.contains(account.typeId))
            .toList();
        debugPrint('✓ Filtro de inclusão: $beforeFilter → ${processedList.length} contas');
      }

      // Aplicar filtro de exclusão (se especificado)
      if (excludedTypeIds != null && excludedTypeIds.isNotEmpty) {
        final beforeFilter = processedList.length;
        processedList = processedList
            .where((account) => !excludedTypeIds!.contains(account.typeId))
            .toList();
        debugPrint('✓ Filtro de exclusão: $beforeFilter → ${processedList.length} contas');
      }

      if (_isCombinedView && (!(_showContasPagar && _showContasReceber && _showCartoesCredito))) {
        final beforeFilter = processedList.length;
        processedList = processedList.where((account) {
          final isCard = account.cardBrand != null;
          final typeName = typeMap[account.typeId]?.toLowerCase() ?? '';
          final isRecebimento = typeName.contains('receb');
          final isPagar = !isCard && !isRecebimento;

          if (isCard && !_showCartoesCredito) return false;
          if (isRecebimento && !_showContasReceber) return false;
          if (isPagar && !_showContasPagar) return false;
          return true;
        }).toList();
        debugPrint('✓ Filtro de categorias: $beforeFilter → ${processedList.length} contas');
      }

      debugPrint('📊 Depois de filtros: ${processedList.length} contas');
      
      // Aplicar filtro de período (semana atual, próxima semana)
      if (_periodFilter != 'month') {
        final beforePeriod = processedList.length;
        processedList = processedList.where((account) {
          final year = account.year ?? _startDate.year;
          final month = account.month ?? _startDate.month;
          int day = account.dueDay;
          final maxDays = DateUtils.getDaysInMonth(year, month);
          if (day > maxDays) day = maxDays;
          final dueDate = DateTime(year, month, day);
          return !dueDate.isBefore(_startDate) && !dueDate.isAfter(_endDate);
        }).toList();
        debugPrint('✓ Filtro de período ($_periodFilter): $beforePeriod → ${processedList.length} contas');
      }
      
      processedList.sort((a, b) {
        final dayCompare = a.dueDay.compareTo(b.dueDay);
        if (dayCompare != 0) return dayCompare;
        final aIsCard = a.cardBrand != null;
        final bIsCard = b.cardBrand != null;
        final aType = typeMap[a.typeId]?.toLowerCase() ?? '';
        final bType = typeMap[b.typeId]?.toLowerCase() ?? '';
        final aIsReceb = aType.contains('receb');
        final bIsReceb = bType.contains('receb');
        int rank(dynamic acc, bool isCard, bool isReceb) {
          if (isCard) return 0;
          if (!isReceb) return 1;
          return 2;
        }
        final aRank = rank(a, aIsCard, aIsReceb);
        final bRank = rank(b, bIsCard, bIsReceb);
        return aRank.compareTo(bRank);
      });
      
      final double totalForecast = processedList.fold(0.0, (sum, item) {
        if (item.cardBrand != null && item.isRecurrent) {
          final breakdown = CardBreakdown.parse(item.observation);
          return sum + breakdown.total;
        }
        return sum + item.value;
      });
      final installmentSummaries = await timed(
        'buildInstallmentSummaries',
        _buildInstallmentSummaries(processedList),
        timeout: const Duration(seconds: 15),
      );

      // Carregar informações de pagamento de forma assíncrona não-bloqueante
      final paymentIds = processedList
          .where((account) => account.id != null)
          .map((account) => account.id!)
          .toList();
      debugPrint('💳 Buscando pagamentos para IDs: $paymentIds');
      final paymentInfo = paymentIds.isEmpty
          ? <int, Map<String, dynamic>>{}
          : await timed(
              'getPaymentsForAccountsByMonth',
              DatabaseHelper.instance.getPaymentsForAccountsByMonth(
                paymentIds,
                _startDate.month,
                _startDate.year,
              ),
              timeout: const Duration(seconds: 10),
            );
      debugPrint('💳 Pagamentos encontrados: ${paymentInfo.keys.toList()}');
      for (var entry in paymentInfo.entries) {
        debugPrint('   accountId=${entry.key}: ${entry.value}');
      }
      
      // Filtrar contas pagas se a opção "Ocultar" estiver ativa
      if (_hidePaidAccounts) {
        final beforePaid = processedList.length;
        processedList = processedList.where((account) {
          if (account.id == null) return true;
          return !paymentInfo.containsKey(account.id!);
        }).toList();
        debugPrint('✓ Filtro de pagas (ocultar): $beforePaid → ${processedList.length} contas');
      }
      
      final totalPaid = paymentIds.isEmpty
          ? 0.0
          : await timed(
              'getPaymentsSumForAccountsByMonth',
              DatabaseHelper.instance.getPaymentsSumForAccountsByMonth(
                paymentIds,
                _startDate.month,
                _startDate.year,
              ),
              timeout: const Duration(seconds: 10),
            );
      final totalRemaining = math.max(0.0, totalForecast - totalPaid);

      // Calcular totais separados para visão combinada
      // Total Lançado = soma de contas lançadas + contas que não precisam ser lançadas
      // Total Previsto = se não lançada usa previsto, se lançada usa o valor lançado
      double previstoPagar = 0.0;
      double previstoReceber = 0.0;
      double lancadoPagar = 0.0;
      double lancadoReceber = 0.0;

      for (final item in processedList) {
        final isCard = item.cardBrand != null;
        final typeName = typeMap[item.typeId]?.toLowerCase() ?? '';
        final isRecebimento = typeName.contains('receb');

        // Identificar se é uma conta pai de recorrência (template, não deve ser somada no lançado)
        final isRecurrenceParent = item.isRecurrent && item.recurrenceId == null && !isCard;

        double itemPrevisto = 0.0;
        double itemLancado = 0.0;

        if (isCard) {
          final breakdown = CardBreakdown.parse(item.observation);
          // Previsto do cartão vem do breakdown
          final cardPrevisto = breakdown.total;
          // Lançado é o value da fatura
          itemLancado = item.value;
          // Previsto: se tem valor lançado, usa lançado; senão usa previsto
          itemPrevisto = cardPrevisto;
        } else if (isRecurrenceParent) {
          // Conta pai de recorrência: não soma no lançado, mas soma no previsto
          itemPrevisto = item.estimatedValue ?? item.value;
          itemLancado = 0.0; // Não conta no total lançado
        } else {
          // Conta normal ou filha de recorrência
          final valorPrevisto = item.estimatedValue ?? item.value;
          final valorLancado = item.value;

          // Total lançado: valor da conta (se > 0)
          itemLancado = valorLancado;

          // Total previsto: se lançado > 0, usa lançado; senão usa previsto
          itemPrevisto = valorLancado > 0.01 ? valorLancado : valorPrevisto;
        }

        if (isRecebimento) {
          previstoReceber += itemPrevisto;
          lancadoReceber += itemLancado;
        } else {
          // Contas a pagar + cartões
          previstoPagar += itemPrevisto;
          lancadoPagar += itemLancado;
        }
      }

      if (mounted) {
        setState(() {
          _displayList = processedList;
          _typeNames = typeMap;
          _typeLogos = typeLogoMap;
          _categoryNames = categoryMap;
          _categoryLogos = categoryLogoMap;
          _totalPeriod = totalPaid;
          _totalForecast = totalRemaining;
          _totalPrevistoPagar = previstoPagar;
          _totalPrevistoReceber = previstoReceber;
          _totalLancadoPagar = lancadoPagar;
          _totalLancadoReceber = lancadoReceber;
          _installmentSummaries = installmentSummaries;
          _paymentInfo = paymentInfo;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao carregar dados: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint(
        '✅ DashboardScreen: _loadData end (#$loadId) '
        'isLoading=$_isLoading items=${_displayList.length}',
      );
      _currentLoadStage = '';
      _activeLoad = null;
      completer.complete();
      if (_pendingReload) {
        _pendingReload = false;
        unawaited(_loadData());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      if (!_datesInitialized) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final media = MediaQuery.of(context);
      final isCompactHeight = media.size.height < 640;
      final isCompactWidth = media.size.width < 360;
      final isCompactFab = isCompactHeight || isCompactWidth;
      final fabRight = math.max(8.0, math.min(24.0, media.size.width * 0.02));
      final fabBottom = math.max(16.0, math.min(48.0, media.size.height * 0.08));
      final isDark = Theme.of(context).brightness == Brightness.dark;
        final bool isCombined = widget.typeNameFilter == null && widget.excludeTypeNameFilter == null;
        final headerColor = isCombined
          ? const Color(0xFFEDE7D9)
          : (isDark ? const Color(0xFF212121) : const Color(0xFFE3F2FD));
        final totalColor = widget.totalLabelOverride != null
          ? (isDark ? Colors.brown.shade200 : Colors.brown.shade700)
          : (_isRecebimentosFilter
            ? (isDark ? AppColors.primaryLight : AppColors.primary)
            : (isDark ? AppColors.errorLight : AppColors.error));
        final totalForecastColor = widget.totalForecastLabelOverride != null
          ? (isDark ? Colors.brown.shade300 : Colors.brown.shade600)
          : (_isRecebimentosFilter
            ? (isDark ? AppColors.primaryLight : AppColors.primary)
            : (isDark ? AppColors.warningLight : AppColors.warningDark));
        final totalLabel = widget.totalLabelOverride ?? (_isRecebimentosFilter ? 'TOTAL RECEBIDO' : 'TOTAL PAGO');
        final emptyText = widget.emptyTextOverride ??
          (_isRecebimentosFilter
            ? 'Nenhuma conta a receber para este mês.'
            : 'Nenhuma conta a pagar para este mês.');
        final appBarBg = widget.appBarColorOverride ??
          (_isRecebimentosFilter ? AppColors.success : AppColors.error);
      const appBarFg = Colors.white;
      final isSingleDayFilter = DateUtils.isSameDay(_startDate, _endDate);
      final PreferredSizeWidget appBarWidget = isSingleDayFilter
          ? (SingleDayAppBar(
              date: _startDate,
              city: PrefsService.cityNotifier.value,
              backgroundColor: appBarBg,
              foregroundColor: appBarFg,
              leading: IconButton(
                icon: _borderedIcon(Icons.arrow_back, size: 20, iconColor: Colors.white),
                tooltip: 'Voltar',
                onPressed: () {
                  final monthStart = DateTime(_startDate.year, _startDate.month, 1);
                  final monthEnd = DateTime(_startDate.year, _startDate.month + 1, 0);
                  PrefsService.saveDateRange(monthStart, monthEnd);
                  final targetTab = PrefsService.tabReturnNotifier.value ?? 2;
                  PrefsService.tabReturnNotifier.value = null;
                  PrefsService.requestTabChange(targetTab);
                },
              ),
              actions: _buildAppBarActions(includeFilter: false),
            ) as PreferredSizeWidget)
           : (DateRangeAppBar(
               range: DateTimeRange(start: _startDate, end: _endDate),
               onPrevious: () => _changeMonth(-1),
               onNext: () => _changeMonth(1),
               backgroundColor: appBarBg,
               foregroundColor: appBarFg,
               actions: _buildAppBarActions(
                 includeFilter: !_inlinePreserveAppBar,
                 badgeFillColor: appBarBg,
               ),
               showFilters: _isCombinedView && !_inlinePreserveAppBar,
               filterContasPagar: _showContasPagar,
               filterContasReceber: _showContasReceber,
               filterCartoes: _showCartoesCredito,
               onFilterContasPagarChanged: (value) {
                 setState(() => _showContasPagar = value);
                 _loadData();
               },
               onFilterContasReceberChanged: (value) {
                 setState(() => _showContasReceber = value);
                 _loadData();
               },
               onFilterCartoesChanged: (value) {
                 setState(() => _showCartoesCredito = value);
                 _loadData();
               },
             ) as PreferredSizeWidget);
      final dashboardBody = SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
              final headerPadding = EdgeInsets.symmetric(
                vertical: isCompactHeight ? 10 : 16,
                horizontal: isCompactHeight ? 6 : 8,
              );
              final totalFontSize = isCompactHeight ? 22.0 : 28.0;
              final listBottomPadding = isCompactHeight ? 72.0 : 100.0;
              const headerScale = 0.8;
              double hs(double value) => value * headerScale;

              final headerWidget = isCombined
                ? Container(
                    padding: headerPadding,
                    color: headerColor,
                    child: Row(
                      children: [
                        // Card A RECEBER
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: hs(16), vertical: hs(14)),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.green.shade600,
                                  Colors.green.shade800,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(hs(16)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.shade400.withValues(alpha: 0.5),
                                  blurRadius: hs(12),
                                  offset: Offset(0, hs(4)),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(hs(7)),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(hs(8)),
                                      ),
                                      child: const Icon(
                                        Icons.trending_up_rounded,
                                        color: Colors.white,
                                        size: 18 * headerScale,
                                      ),
                                    ),
                                    SizedBox(width: hs(10)),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Valor principal
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              UtilBrasilFields.obterReal(_totalLancadoReceber),
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: hs(32),  // 28-34px range
                                                letterSpacing: 0.6,
                                                height: 1.1,
                                              ),
                                            ),
                                          ),
                                          SizedBox(height: hs(2)),
                                          // Previsto (menor e discreto)
                                          Text(
                                            'Previsto: ${UtilBrasilFields.obterReal(_totalPrevistoReceber)}',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.80),
                                              fontWeight: FontWeight.w600,
                                              fontSize: hs(14),  // 13-15px range
                                              height: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: hs(8)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Card A PAGAR
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: hs(16), vertical: hs(14)),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.red.shade500,
                                  Colors.red.shade800,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(hs(16)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.shade400.withValues(alpha: 0.5),
                                  blurRadius: hs(12),
                                  offset: Offset(0, hs(4)),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(hs(7)),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(hs(8)),
                                      ),
                                      child: const Icon(
                                        Icons.trending_down_rounded,
                                        color: Colors.white,
                                        size: 18 * headerScale,
                                      ),
                                    ),
                                    SizedBox(width: hs(10)),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Valor principal
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              UtilBrasilFields.obterReal(_totalLancadoPagar),
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: hs(32),  // 28-34px range
                                                letterSpacing: 0.6,
                                                height: 1.1,
                                              ),
                                            ),
                                          ),
                                          SizedBox(height: hs(2)),
                                          // Previsto (menor e discreto)
                                          Text(
                                            'Previsto: ${UtilBrasilFields.obterReal(_totalPrevistoPagar)}',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.80),
                                              fontWeight: FontWeight.w600,
                                              fontSize: hs(14),  // 13-15px range
                                              height: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: hs(8)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    padding: headerPadding,
                    color: headerColor,
                    child: Row(children: [
                      Expanded(
                          child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.grey.withValues(alpha: 0.3)),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2))
                                  ]),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(totalLabel,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                          letterSpacing: 0.5,
                                          color: _adaptiveGreyTextColor(context, Colors.grey.shade600))),
                                  const SizedBox(height: 8),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(UtilBrasilFields.obterReal(_totalPeriod),
                                        style: TextStyle(
                                            fontSize: totalFontSize + 4,
                                            fontWeight: FontWeight.bold,
                                            color: totalColor)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Previsto',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 10,
                                          color: _adaptiveGreyTextColor(context, Colors.grey.shade500))),
                                  const SizedBox(height: 2),
                                  Text(UtilBrasilFields.obterReal(_totalForecast),
                                      style: TextStyle(
                                          fontSize: totalFontSize - 4,
                                          fontWeight: FontWeight.w600,
                                          color: totalForecastColor.withValues(alpha: 0.8))),
                                ]
                              ))),
                    ]));

              // Widget de indicação de seleção
              Widget? selectionBanner;
              if (_selectedAccountId != null) {
                // Buscar conta selecionada
                final selectedAccount = _displayList.where((a) => a.id == _selectedAccountId).firstOrNull;
                if (selectedAccount != null) {
                  final valueStr = UtilBrasilFields.obterReal(selectedAccount.value);
                  final categoryStr = _typeNames[selectedAccount.typeId] ?? 'Outro';
                  final descStr = selectedAccount.description.isNotEmpty 
                      ? selectedAccount.description 
                      : 'Sem descrição';
                  final bool isPaid = selectedAccount.id != null && _paymentInfo.containsKey(selectedAccount.id!);
                  final bool isCard = selectedAccount.cardBrand != null;
                  final bool isRecebimento = _isRecebimentosFilter || (_typeNames[selectedAccount.typeId]?.toLowerCase().contains('receb') ?? false);
                  
                  selectionBanner = Container(
                    height: 44, // Altura compacta
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF), // Fundo suave azul clarinho
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFFDBEAFE), // Borda ainda mais suave
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Info compacta
                        const Icon(
                          Icons.check_circle_outline,
                          color: Color(0xFF2563EB),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$categoryStr – $descStr – $valueStr',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1E40AF),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Ações inline
                        // ✏ Editar
                        InkWell(
                          onTap: () async {
                            if (isCard) {
                              await _openCardEditor(selectedAccount);
                            } else {
                              await _showEditSpecificDialog(selectedAccount);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, size: 14, color: Color(0xFF2563EB)),
                                SizedBox(width: 4),
                                Text(
                                  'Editar',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        
                        // ✓ Pagar/Receber (se não pago)
                        if (!isPaid) ...[
                          InkWell(
                            onTap: () => _handlePayAction(selectedAccount),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isRecebimento ? Icons.trending_up : Icons.attach_money,
                                    size: 14,
                                    color: const Color(0xFF059669),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isRecebimento ? 'Receber' : 'Pagar',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        
                        // 🗑 Excluir
                        InkWell(
                          onTap: () => _confirmDelete(selectedAccount),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.delete_outline, size: 14, color: Color(0xFFDC2626)),
                                SizedBox(width: 4),
                                Text(
                                  'Excluir',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        // X Limpar seleção
                        InkWell(
                          onTap: () => setState(() => _selectedAccountId = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: const Icon(
                              Icons.close,
                              color: Color(0xFF6B7280),
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              }

              return Column(children: [
                headerWidget,
                if (selectionBanner != null) selectionBanner,
                Expanded(
                    child: _isLoading
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 12),
                                Text(
                                  _currentLoadStage.isEmpty
                                      ? 'Carregando...'
                                      : 'Carregando... ($_currentLoadStage)',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    setState(() => _isLoading = false);
                                  },
                                  child: const Text('Cancelar carregamento'),
                                ),
                              ],
                            ),
                          )
                        : _displayList.isEmpty
                            ? Center(child: Text(emptyText))
                            : NotificationListener<ScrollNotification>(
                                onNotification: _handleScrollNotification,
                                child: ListView.builder(
                                  padding: EdgeInsets.fromLTRB(
                                      0, 0, 0, listBottomPadding),
                                  itemCount: _displayList.length,
                                  itemBuilder: (context, index) {
                                    try {
                                      final account = _displayList[index];
                                      final currentDate = DateTime(
                                        account.year ?? _startDate.year,
                                        account.month ?? _startDate.month,
                                        account.dueDay,
                                      );
                                      
                                      // Verificar se a data mudou em relação ao card anterior
                                      bool showDateSeparator = false;
                                      if (index > 0) {
                                        final prevAccount = _displayList[index - 1];
                                        final prevDate = DateTime(
                                          prevAccount.year ?? _startDate.year,
                                          prevAccount.month ?? _startDate.month,
                                          prevAccount.dueDay,
                                        );
                                        showDateSeparator = !DateUtils.isSameDay(currentDate, prevDate);
                                      }
                                      
                                      return Column(
                                        children: [
                                          if (showDateSeparator) ...[
                                            Container(
                                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              height: 1,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.transparent,
                                                    Colors.black.withValues(alpha: 0.08),
                                                    Colors.transparent,
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 6),
                                            child: _buildAccountCard(account),
                                          ),
                                        ],
                                      );
                                    } catch (e) {
                                      debugPrint(
                                          '? Erro ao renderizar card $index: $e');
                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        margin: const EdgeInsets.all(8),
                                        color: Colors.red.shade50,
                                        child: Text('Erro ao renderizar: $e'),
                                      );
                                    }
                                  },
                                ),
                              )),
              ]);
          },
        ),
      );

      return Scaffold(
        appBar: _isInlineEditing && !_inlinePreserveAppBar ? null : appBarWidget,
        body: _isInlineEditing && _inlineEditWidget != null
            ? _inlineEditWidget!
            : dashboardBody,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
        floatingActionButton: _isInlineEditing
            ? null
            : SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(right: fabRight, bottom: fabBottom),
                  child: AnimatedScale(
                    scale: _isFabVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedOpacity(
                      opacity: _isFabVisible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: FloatingActionButton(
                        heroTag: null,
                        tooltip: _isRecebimentosFilter
                            ? 'Novo recebimento'
                            : 'Novo lancamento',
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        onPressed: _isFabVisible
                            ? (_isRecebimentosFilter
                                ? _openRecebimentoForm
                                : _showQuickActions)
                            : null,
                        mini: isCompactFab,
                        child: _borderedIcon(
                          Icons.add,
                          iconColor: Colors.white,
                          borderColor: Colors.white,
                          size: isCompactFab ? 20 : 24,
                          padding: const EdgeInsets.all(6),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao renderizar DashboardScreen: $e');
      debugPrintStack(stackTrace: stackTrace);
      return Scaffold(
        appBar: DateRangeAppBar(
          range: DateTimeRange(start: _startDate, end: _endDate),
          onPrevious: () => _changeMonth(-1),
          onNext: () => _changeMonth(1),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _borderedIcon(Icons.error_outline,
                  size: 48, iconColor: Colors.red, padding: const EdgeInsets.all(8)),
              const SizedBox(height: 16),
              const Text('Erro ao carregar tela'),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _adaptiveGreyTextColor(context, Colors.grey)),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildAccountCard(Account account) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive font sizes based on screen width
        final screenWidth = constraints.maxWidth;
        const cardScale = 0.8;
        final baseFontSize = screenWidth / 50 * cardScale; // Base unit for scaling

        // Define all font sizes proportionally
        final dayNumberSize = baseFontSize * 2.0;
        final smallDateSize = baseFontSize * 0.6;
        final weekdaySize = baseFontSize * 0.75;
        final statusSize = baseFontSize * 0.55;
        final categorySize = baseFontSize * 1.1;  // ~16-18px: Categoria mais legível
        final descriptionSize = baseFontSize * 0.95;  // ~14px: Subtítulo legível e premium
        final badgeSize = baseFontSize * 0.65;
        final valuePreviewSize = baseFontSize * 0.75;
        final valueMainSize = baseFontSize * 1.05;
        final paidSize = baseFontSize * 0.7;
        final iconSize = baseFontSize * 0.95;

        return _buildAccountCardInternal(
          account,
          dayNumberSize,
          smallDateSize,
          weekdaySize,
          statusSize,
          categorySize,
          descriptionSize,
          badgeSize,
          valuePreviewSize,
          valueMainSize,
          paidSize,
          iconSize,
          cardScale,
        );
      },
    );
  }

  Widget _buildAccountCardInternal(
    Account account,
    double dayNumberSize,
    double smallDateSize,
    double weekdaySize,
    double statusSize,
    double categorySize,
    double descriptionSize,
    double badgeSize,
    double valuePreviewSize,
    double valueMainSize,
    double paidSize,
    double iconSize,
    double scale,
  ) {
    double sp(double value) => value * scale;
    int year = account.year ?? _startDate.year;
    int month = account.month ?? _startDate.month;
    int day = account.dueDay;
    int maxDays = DateUtils.getDaysInMonth(year, month);
    if (day > maxDays) day = maxDays;
    
    final originalDate = DateTime(year, month, day);
    final isWeekend = HolidayService.isWeekend(originalDate);
    final isHoliday =
        HolidayService.isHoliday(originalDate, PrefsService.cityNotifier.value);
    final isAlertDay = isWeekend || isHoliday;
    
    DateTime effectiveDate = originalDate;
    if (isAlertDay) {
      if (account.payInAdvance) {
        while (HolidayService.isWeekend(effectiveDate) ||
            HolidayService.isHoliday(
                effectiveDate, PrefsService.cityNotifier.value)) {
          effectiveDate = effectiveDate.subtract(const Duration(days: 1));
        }
      } else {
        while (HolidayService.isWeekend(effectiveDate) ||
            HolidayService.isHoliday(
                effectiveDate, PrefsService.cityNotifier.value)) {
          effectiveDate = effectiveDate.add(const Duration(days: 1));
        }
      }
    }

    // Configurações de Cor e Estilo
    bool isCard = account.cardBrand != null;
    bool isRecurrent = account.isRecurrent || account.recurrenceId != null;

    Color containerBg;
    Color cardColor;
    Color textColor;
    late Color typeColor;

    final String? typeName = _typeNames[account.typeId]?.toLowerCase();
    final bool isRecebimento = _isRecebimentosFilter || (typeName != null && typeName.contains('receb'));
    final Color receberColor = Colors.lightBlue.shade300;
    final Color pagarColor = Colors.red.shade300;

    if (isCard) {
        Color userColor = (account.cardColor != null)
          ? Color(account.cardColor!)
          : AppColors.cardPurpleDark;
        
        // Aplicar overlay sutil para "domar" a cor escolhida pelo usuário (8%)
        final bool isUserColorDark = ThemeData.estimateBrightnessForColor(userColor) == Brightness.dark;
        cardColor = Color.alphaBlend(
          isUserColorDark
              ? Colors.white.withValues(alpha: 0.08)  // Overlay branco 8% em cores escuras
              : Colors.black.withValues(alpha: 0.08), // Overlay preto 8% em cores claras (domar saturação)
          userColor,
        );
        
        containerBg = Colors.transparent;
        textColor = foregroundColorFor(cardColor);
        // ...existing code...
        typeColor = userColor;
    } else {
      final int? accountColorValue = account.cardColor;
      final bool usesCustomColor = accountColorValue != null;
      final Color? customColor = usesCustomColor ? Color(accountColorValue) : null;
      
      // Se houver cor customizada, aplicar overlay sutil
      final Color? domadaColor = customColor != null
          ? () {
              final bool isCustomDark = ThemeData.estimateBrightnessForColor(customColor) == Brightness.dark;
              return Color.alphaBlend(
                isCustomDark
                    ? Colors.white.withValues(alpha: 0.08)  // Overlay branco 8% em cores escuras
                    : Colors.black.withValues(alpha: 0.12), // Overlay preto 12% em cores claras
                customColor,
              );
            }()
          : null;
      
      final Color accent = domadaColor ?? (isRecebimento ? receberColor : pagarColor);
      
      // Background adaptável: cor customizada ou neutro elegante
      if (domadaColor != null) {
        // Se tem cor customizada, usar overlay sutil da cor
        containerBg = accent.withValues(alpha: 0.12);
        cardColor = domadaColor.withValues(alpha: 0.97);
      } else {
        // Sem cor customizada: fundo off-white elegante
        final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
        if (isDarkMode) {
          // Modo escuro: manter comportamento atual
          containerBg = accent.withValues(alpha: 0.12);
          cardColor = Theme.of(context).cardColor.withValues(alpha: 0.97);
        } else {
          // Modo claro: fundo neutro elegante ao invés de cinza
          containerBg = Colors.transparent;
          
          // Estados visuais mais agradáveis
          final bool isSelected = _selectedAccountId == account.id;
          final bool isHovered = _hoveredAccountId == account.id;
          
          if (isSelected) {
            // Selecionado: azul bem clarinho para combinar com borda + barra lateral
            cardColor = const Color(0xFFF0F7FF);
          } else if (isHovered) {
            // Hover: cinza muito claro
            cardColor = const Color(0xFFF3F4F6);
          } else {
            // Normal: off-white elegante
            cardColor = const Color(0xFFFAFAFA);
          }
        }
      }
      // ...existing code...
      if (customColor != null) {
        textColor = foregroundColorFor(customColor);
      } else {
        textColor = foregroundColorFor(cardColor);
        if (isAlertDay) {
          textColor = Colors.white;
        } else if (isRecurrent) {
        } else {
        }
        if (Theme.of(context).brightness == Brightness.dark && !isRecurrent) {
        }
        if (isAlertDay && !isRecurrent && !isRecebimento) {
        }
      }

      typeColor = accent;
    }

    final Color accentColor = typeColor;
    final bool isPagamento = !isRecebimento && (typeName?.contains('pag') ?? true);
    final breakdown = isCard ? CardBreakdown.parse(account.observation) : const CardBreakdown(total: 0, installments: 0, oneOff: 0, subscriptions: 0);
    // Valor previsto para exibir no badge (estimatedValue para recorrências)
    final double previstoValue = isCard
        ? breakdown.total
        : (isRecurrent && account.recurrenceId != null
            ? (account.estimatedValue ?? account.value)
            : account.value);
    // Valor lançado: sempre account.value (mostra 0,00 se não lançado)
    final double? lancadoValue = (!isCard && isRecurrent && account.recurrenceId == null)
        ? null
        : account.value;
    final String lancadoDisplay =
        UtilBrasilFields.obterReal(lancadoValue ?? previstoValue);
    final String previstoDisplay = UtilBrasilFields.obterReal(previstoValue);
    // Mostrar previsto para contas recorrentes filhas que têm estimatedValue definido
    final bool showPrevisto = !isCard &&
        isRecurrent &&
        account.recurrenceId != null &&
        account.estimatedValue != null &&
        account.estimatedValue!.abs() > 0.009;

    final cleanedDescription =
        cleanAccountDescription(account).replaceAll('Fatura: ', '').trim();
    final rawCategory = (account.categoryId != null)
        ? _categoryNames[account.categoryId!]
        : null;
    final String? parentLogo = _typeLogos[account.typeId];
    final String? childLogo =
        account.categoryId != null ? _categoryLogos[account.categoryId!] : null;
    // Extrair categoria pai (antes do ||) e categoria filho (depois do ||)
    final categoryParent = rawCategory == null
        ? null
        : (rawCategory.contains('||')
            ? rawCategory.split('||').first.trim()
            : null);
    final categoryChild = rawCategory == null
        ? null
        : (rawCategory.contains('||')
            ? rawCategory.split('||').last.trim()
            : rawCategory.trim());
    final sanitizedCategoryChild =
        categoryChild?.replaceAll(RegExp(r'^Fatura:\s*'), '').trim();
    final fallbackDescription = (cleanedDescription.isNotEmpty
            ? cleanedDescription
            : account.description)
        .trim();
    final childLabel = sanitizedCategoryChild?.isNotEmpty == true
        ? sanitizedCategoryChild!
        : fallbackDescription;
    final String cardBankLabel = (account.cardBank ?? '').trim();
    final String cardBrandLabel = (account.cardBrand ?? '').trim();
    final String middleLineText = isCard
        ? (cardBankLabel.isNotEmpty && cardBrandLabel.isNotEmpty
            ? '$cardBankLabel - $cardBrandLabel'
            : (cardBankLabel.isNotEmpty
                ? cardBankLabel
                : (cardBrandLabel.isNotEmpty
                    ? cardBrandLabel
                    : fallbackDescription)))
        : (() {
            final desc = fallbackDescription;
            if (desc.isEmpty) return childLabel;
            final childLower = childLabel.toLowerCase();
            final descLower = desc.toLowerCase();
            if (childLower == descLower || childLower.contains(descLower)) {
              return childLabel;
            }
            return '$childLabel - $desc';
          })();
    final installmentSummary =
        account.id != null ? _installmentSummaries[account.id!] : null;
    final bool isPaid =
        account.id != null && _paymentInfo.containsKey(account.id!);
    final bool isCardInvoice = isCard && account.recurrenceId != null;

    // Próxima fatura do cartão (mês seguinte ao vencimento atual exibido)
    DateTime cardNextDueDate = DateTime.now();
    if (isCard) {
      final currentYear = account.year ?? _startDate.year;
      final currentMonth = account.month ?? _startDate.month;
      int nextMonth = currentMonth + 1;
      int nextYear = currentYear;
      if (nextMonth > 12) {
        nextMonth = 1;
        nextYear += 1;
      }
      int day = account.dueDay;
      final maxDay = DateUtils.getDaysInMonth(nextYear, nextMonth);
      if (day > maxDay) day = maxDay;
      cardNextDueDate = DateTime(nextYear, nextMonth, day);
    }
    final String cardNextDueLabel = DateFormat('dd/MM').format(cardNextDueDate);
    final bool hasRecurrence = account.isRecurrent || account.recurrenceId != null;
    
    // Cores padronizadas para action buttons - adaptativas ao fundo do card
    // Usar foregroundColorFor() para garantir contraste em qualquer cor escolhida
    final bool isCardDark = ThemeData.estimateBrightnessForColor(cardColor) == Brightness.dark;
    final Color actionIconColor = foregroundColorFor(cardColor);
    final Color actionIconBg = actionIconColor.withValues(alpha: 0.08);
    
    final double childIconHeight = categorySize * 1.3;
    final double childIconWidth = categorySize * 1.8;

    final List<BoxShadow> badgeShadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.25),
        blurRadius: sp(3),
        offset: Offset(0, sp(2)),
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.7),
        blurRadius: sp(2),
        offset: Offset(0, -sp(1)),
      ),
    ];

    Widget? buildCardBrandBadge(String? brand) {
      final normalized = (brand ?? '').trim().toUpperCase();
      if (normalized.isEmpty) return null;

      // Usar imagens personalizadas para cada bandeira
      String? assetPath;
      if (normalized == 'VISA') {
        assetPath = 'assets/icons/cc_visa.png';
      } else if (normalized == 'AMEX' || normalized == 'AMERICAN EXPRESS' || normalized == 'AMERICANEXPRESS') {
        assetPath = 'assets/icons/cc_amex.png';
      } else if (normalized == 'MASTER' || normalized == 'MASTERCARD' || normalized == 'MASTER CARD') {
        assetPath = 'assets/icons/cc_mc.png';
      } else if (normalized == 'ELO') {
        assetPath = 'assets/icons/cc_elo.png';
      }

      if (assetPath != null) {
        return Image.asset(
          assetPath,
          package: 'finance_app',
          width: childIconWidth,
          height: childIconHeight,
          fit: BoxFit.contain,
        );
      }

      // Fallback para bandeiras não reconhecidas
      return Container(
        padding: EdgeInsets.symmetric(horizontal: sp(8), vertical: sp(4)),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(sp(6)),
          boxShadow: badgeShadow,
        ),
        child: Text(
          normalized,
          style: TextStyle(fontSize: badgeSize, fontWeight: FontWeight.w700),
        ),
      );
    }

    final Widget? brandBadge = isCard ? buildCardBrandBadge(account.cardBrand) : null;
    final installmentDisplay = resolveInstallmentDisplay(account);
    final Color parceladoFillColor =
        isRecebimento ? Colors.green.shade600 : Colors.red.shade600;
    final bool cardIsDark =
        ThemeData.estimateBrightnessForColor(cardColor) == Brightness.dark;
    // Identificar se é parcela única (não recorrente, não parcelada, total == 1)
    final bool isSinglePayment = !hasRecurrence && !installmentDisplay.isInstallment && !isCard;
    // Badge de parcelamento - único chip colorido (status)
    final Widget installmentBadge = Container(
        padding: EdgeInsets.symmetric(horizontal: sp(8), vertical: sp(3)),
        decoration: BoxDecoration(
            color: parceladoFillColor,
            borderRadius: BorderRadius.circular(sp(8)),
            border: Border.all(
              color: cardIsDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: parceladoFillColor.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ]),
        child: Text(installmentDisplay.labelText,
            style: TextStyle(fontSize: badgeSize, fontWeight: FontWeight.w700, color: Colors.white)));
    // Badge para parcela única (chip informativo neutro)
    final Widget singlePaymentBadge = Container(
        padding: EdgeInsets.symmetric(horizontal: sp(8), vertical: sp(3)),
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(sp(8)),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1,
            ),
        ),
        child: Text('Parcela única',
            style: TextStyle(fontSize: badgeSize, fontWeight: FontWeight.w600, color: Colors.grey.shade700)));
    final String nextValueLabel = installmentSummary?.nextValue != null
        ? UtilBrasilFields.obterReal(installmentSummary!.nextValue!)
        : '-';
    final Widget nextDueBadge = Container(
        padding: EdgeInsets.symmetric(horizontal: sp(8), vertical: sp(3)),
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(sp(8)),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1,
            ),
        ),
        child: Text('Próx: $nextValueLabel',
            style: TextStyle(
                fontSize: smallDateSize, fontWeight: FontWeight.w600, color: Colors.grey.shade700)));

      final bool canLaunchPayment = !isPaid;
      // Ordem dos botões: Editar → Lançamento → Pagamento → Despesa cartão → Lixeira
      final actionButtons = Row(mainAxisSize: MainAxisSize.min, children: [
        // 1. EDITAR (lápis) - sempre primeiro em todos os cards
        InkWell(
            onTap: () => isCard ? _openCardEditor(account) : _showEditSpecificDialog(account),
            child: _actionIcon(Icons.edit, actionIconBg, actionIconColor,
                size: iconSize, scale: scale, surfaceColor: cardColor)),
        SizedBox(width: sp(6)),

        // 2. LANÇAMENTO (rocket) - quando aplicável
        if (isCard) ...[
          if (!isCardInvoice) ...[
            InkWell(
                onTap: () => _showCartaoValueDialog(account),
                child: _actionIcon(Icons.rocket_launch, actionIconBg, actionIconColor,
                    size: iconSize, scale: scale, surfaceColor: cardColor)),
            SizedBox(width: sp(6)),
          ] else if (!isPaid && account.value > 0) ...[
            InkWell(
              onTap: () => _undoLaunch(account),
              child: _actionIcon(Icons.undo, actionIconBg, actionIconColor,
                  size: iconSize, scale: scale, surfaceColor: cardColor),
            ),
            SizedBox(width: sp(6)),
          ],
          // 3. PAGAMENTO DA FATURA (dinheiro) - para cartäes de cr‚dito
          InkWell(
              onTap: canLaunchPayment ? () => _handlePayAction(account) : null,
              child: _actionIcon(Icons.attach_money, actionIconBg, actionIconColor,
                  enabled: canLaunchPayment, size: iconSize, scale: scale, surfaceColor: cardColor)),
          SizedBox(width: sp(6)),
        ] else if (isRecebimento) ...[

          InkWell(
              onTap: () => _showRecebimentoValueDialog(account),
              child: _actionIcon(Icons.rocket_launch, actionIconBg, actionIconColor,
                  size: iconSize, scale: scale, surfaceColor: cardColor)),
          SizedBox(width: sp(6)),
        ] else if (isRecurrent && account.recurrenceId == null) ...[
          InkWell(
              onTap: () async {
                Account parentRecurrence = account;
                if (account.recurrenceId != null) {
                  final parentId = account.recurrenceId!;
                  try {
                    final parentAccount = await DatabaseHelper.instance.readAccountById(parentId);
                    if (parentAccount != null) {
                      parentRecurrence = parentAccount;
                    }
                  } catch (e) {
                    debugPrint('❌ Erro ao buscar recorrência PAI: $e');
                  }
                }
                if (mounted) _showLaunchDialog(parentRecurrence);
              },
              child: _actionIcon(Icons.rocket_launch, actionIconBg, actionIconColor,
                  size: iconSize, scale: scale, surfaceColor: cardColor)),
          SizedBox(width: sp(6)),
        ] else if (isRecurrent && account.recurrenceId != null && account.value == 0) ...[
          // Foguete só aparece se value == 0 (não foi lançada ainda)
          InkWell(
              onTap: () => _showDespesaValueDialog(account),
              child: _actionIcon(Icons.rocket_launch, actionIconBg, actionIconColor,
                  size: iconSize, scale: scale, surfaceColor: cardColor)),
          SizedBox(width: sp(6)),
        ],

        // 3. PAGAMENTO (ícone de dinheiro) - para contas não-cartão
        if (!isCard) ...[
          InkWell(
              onTap: canLaunchPayment ? () => _handlePayAction(account) : null,
              child: _actionIcon(Icons.attach_money, actionIconBg, actionIconColor,
                  enabled: canLaunchPayment, size: iconSize, scale: scale, surfaceColor: cardColor)),
          SizedBox(width: sp(6)),
        ],

        // 4. DESPESA NO CARTÃO (carrinho) - apenas para cartões de crédito
        if (isCard) ...[
          InkWell(
              onTap: () => _showExpenseDialog(account),
              child: _actionIcon(Icons.add_shopping_cart, actionIconBg, actionIconColor,
                  size: iconSize, scale: scale, surfaceColor: cardColor)),
          SizedBox(width: sp(6)),
        ],

        // Botão UNDO - para desfazer lançamento de recorrência (só aparece se value > 0, ou seja, foi lançada)
        if (!isCard && account.recurrenceId != null && account.id != null && !isPaid && account.value > 0) ...[
          InkWell(
            onTap: () => _undoLaunch(account),
            child: _actionIcon(Icons.undo, actionIconBg, actionIconColor,
                size: iconSize, scale: scale, surfaceColor: cardColor),
          ),
          SizedBox(width: sp(6)),
        ],

        // 5. LIXEIRA (delete) - sempre por último
        if (account.id != null)
          InkWell(
              onTap: () => _confirmDelete(account),
              child: _actionIcon(Icons.delete, actionIconBg, actionIconColor,
                  size: iconSize, scale: scale, surfaceColor: cardColor)),
      ]);

    Widget buildCardBody({required EdgeInsets padding, required List<Widget> children}) {
      final bool isSelected = account.id != null && _selectedAccountId == account.id;
      final bool isHovered = account.id != null && _hoveredAccountId == account.id;
      
      // Borda: azul 2px quando selecionado, suave e fina caso contrário
      final double borderWidth = isSelected ? sp(2.0) : 1.0; // Sempre 1px quando não selecionado
      final Color borderColor = isSelected 
          ? const Color(0xFF2563EB) // Azul forte quando selecionado
          : Colors.black.withValues(alpha: 0.12); // Borda suave rgba(0,0,0,0.12) padrão
      
      // Fundo: overlay azul FIXO quando selecionado (independente da cor do usuário)
      final Color effectiveCardColor = isSelected
          ? Color.alphaBlend(
              // Overlay azul 7% - funciona em qualquer cor de fundo
              const Color(0xFF2563EB).withValues(alpha: 0.07),
              cardColor,
            )
          : cardColor;
      
      // Sombra: glow azul quando selecionado, suave caso contrário
      final List<BoxShadow> boxShadows = isSelected
          ? [
              // Glow azul quando selecionado
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ]
          : [
              // Sombra suave e leve no estado normal
              BoxShadow(
                color: Colors.black.withValues(alpha: isHovered ? 0.08 : 0.05),
                blurRadius: isHovered ? 8 : 4,
                offset: Offset(0, isHovered ? 3 : 2),
              ),
            ];
      
      return MouseRegion(
        onEnter: (_) {
          if (account.id != null) {
            setState(() => _hoveredAccountId = account.id);
          }
        },
        onExit: (_) {
          setState(() => _hoveredAccountId = null);
        },
        cursor: SystemMouseCursors.click,
        child: Opacity(
          opacity: isPaid ? 0.6 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            color: isCard ? null : containerBg,
            padding: EdgeInsets.symmetric(vertical: sp(4), horizontal: sp(8)),
            child: Card(
            color: effectiveCardColor,
            elevation: 0, // Sem elevation padrão, usamos boxShadow customizado
            shadowColor: Colors.transparent,
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(sp(8)),
              side: BorderSide(color: borderColor, width: borderWidth),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(sp(8)),
                boxShadow: boxShadows,
              ),
              child: InkWell(
              onTap: () async {
                // Single tap: seleciona
                // Double tap: abre detalhes/edição
                if (_selectedAccountId == account.id) {
                  // Segundo clique no mesmo card: abre detalhes
                  if (isCard) {
                    await _openCardExpenses(account);
                  } else {
                    await _showEditSpecificDialog(account);
                  }
                } else {
                  // Primeiro clique: seleciona
                  setState(() {
                    _selectedAccountId = account.id;
                  });
                }
              },
              onLongPress: () async {
                // Long press também abre edição/detalhes
                if (isCard) {
                  await _openCardExpenses(account);
              } else {
                await _showEditSpecificDialog(account);
              }
            },
            // Efeito pressed: overlay azul translúcido
            splashColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
            highlightColor: const Color(0xFF2563EB).withValues(alpha: 0.05),
            child: Padding(padding: padding, child: Column(children: children)),
          ),
            ),
          ),
        ),
        ),
      );
    }

    final bool dateAdjusted = originalDate != effectiveDate;
    final String originalLabel = DateFormat('dd/MM').format(originalDate);
    final String weekdayLabel = DateFormat('EEE', 'pt_BR')
        .format(effectiveDate)
        .replaceAll('.', '')
        .toUpperCase();
    final double calendarWidth = sp(70);
    final double calendarHeight = sp(88);
    // Calendário sempre branco, borda adapta ao fundo do card
    const Color calendarBadgeBg = Colors.white;
    final Color calendarBorder = cardIsDark ? Colors.white : Colors.black;
    // Topo mantém esquema anterior (verde receber, vermelho pagar, laranja para demais)
    final Color calendarTopBar =
        isRecebimento ? Colors.green.shade600 : (isPagamento ? Colors.red.shade600 : Colors.orange.shade700);
    // Textos seguem regra nova (verde receber, vermelho pagar/cartões)
    final Color calendarEmphasis = isRecebimento ? Colors.green.shade700 : Colors.red.shade700;
    final BorderRadius calendarRadius = BorderRadius.circular(sp(10));
    // Furos com borda adaptativa ao fundo do card
    final Color holeFill = Colors.grey.shade300;
    final Color holeBorder = cardIsDark ? Colors.white : Colors.black;
    // Cor do texto: verde para receber, vermelho para pagar, preto demais casos
    final Color calendarContentColor = calendarEmphasis;

    // Widget do calendário principal
      final Widget calendarCore = SizedBox(
        width: calendarWidth,
        height: calendarHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: calendarRadius,
            color: calendarBadgeBg,
            boxShadow: [
              BoxShadow(
                blurRadius: 12,
                offset: const Offset(0, 4),
                color: Colors.black.withValues(alpha: cardIsDark ? 0.3 : 0.15),
              ),
              BoxShadow(
                blurRadius: 6,
                offset: const Offset(-2, -2),
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ],
            border: Border.all(color: calendarBorder, width: sp(2)),
          ),
        child: ClipRRect(
          borderRadius: calendarRadius,
          child: Stack(
            children: [
              // Barra superior colorida com borda completa
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  height: calendarHeight * 0.24,
                  decoration: BoxDecoration(
                    color: calendarTopBar,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(sp(8)),
                      topRight: Radius.circular(sp(8)),
                    ),
                    border: Border.all(color: calendarBorder, width: sp(1.5)),
                  ),
                ),
              ),
              // Furos do calendário - posicionados na barra superior
              Positioned(
                top: calendarHeight * 0.08,
                left: sp(12),
                child: _CalendarHole(fill: holeFill, border: holeBorder, scale: scale),
              ),
              Positioned(
                top: calendarHeight * 0.08,
                right: sp(12),
                child: _CalendarHole(fill: holeFill, border: holeBorder, scale: scale),
              ),
              // Conteúdo central (dia e dia da semana)
              Positioned(
                top: calendarHeight * 0.26,
                left: 4,
                right: 4,
                bottom: 4,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        effectiveDate.day.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: dayNumberSize,
                          height: 1.0,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          color: calendarContentColor,
                        ),
                      ),
                      Text(
                        weekdayLabel,
                        style: TextStyle(
                          fontSize: weekdaySize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: calendarContentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Widget completo com texto lateral esquerdo se data ajustada (usando Stack para não deslocar a folhinha)
    final Color originalDateColor = cardIsDark ? Colors.white : Colors.black;
    final Widget calendarBadge = dateAdjusted
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              calendarCore,
              Positioned(
                left: -18,
                top: 0,
                bottom: 0,
                child: Center(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      originalLabel,
                      style: TextStyle(
                        fontSize: smallDateSize * 1.2,
                        fontWeight: FontWeight.bold,
                        color: originalDateColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )
        : calendarCore;
    final Widget? parentIcon = (parentLogo?.isNotEmpty ?? false)
        ? Text(parentLogo!, style: TextStyle(fontSize: categorySize * 0.95))
        : null;
    final Widget? parentIconBox = parentIcon == null
        ? null
        : SizedBox(
            width: childIconWidth,
            height: childIconHeight,
            child: FittedBox(fit: BoxFit.scaleDown, child: parentIcon),
          );
    final Widget? childIcon = isCard
        ? brandBadge
        : ((childLogo?.isNotEmpty ?? false)
            ? Text(childLogo!, style: TextStyle(fontSize: categorySize * 0.9))
            : null);
    final Widget? headerChildIcon = childIcon == null
      ? null
      : SizedBox(
        width: childIconWidth,
        height: childIconHeight,
        child: FittedBox(fit: BoxFit.scaleDown, child: childIcon),
        );
    final bool showBadgesRow =
        installmentDisplay.isInstallment || hasRecurrence || showPrevisto || isSinglePayment;

    return buildCardBody(
      padding: EdgeInsets.symmetric(vertical: sp(8), horizontal: sp(10)),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: sp(6),
              height: sp(82),
              decoration: BoxDecoration(
                color: (account.id != null && _selectedAccountId == account.id) 
                    ? const Color(0xFF2563EB) // Azul quando selecionado
                    : accentColor, // Cor original (verde/vermelho/laranja)
                borderRadius: BorderRadius.circular(sp(6)),
              ),
            ),
            SizedBox(width: sp(12)),
            calendarBadge,
            SizedBox(width: sp(12)),
            Expanded(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: sp(52)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LINHA 1: Título + Badge de valor
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              if (parentIconBox != null) ...[
                                parentIconBox,
                                SizedBox(width: sp(6)),
                              ],
                              Expanded(
                                child: Text(
                                  categoryParent ?? _typeNames[account.typeId] ?? 'Outro',
                                  style: TextStyle(
                                    fontSize: categorySize * 0.95,  // 16-17px
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF111827),
                                    height: 1.15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: sp(8)),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: sp(8), vertical: sp(4)),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.70),
                                  borderRadius: BorderRadius.circular(sp(8)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isPaid) ...[
                                      Icon(
                                        Icons.check_circle,
                                        size: valueMainSize * 0.9,
                                        color: isRecebimento
                                            ? const Color(0xFF059669)
                                            : const Color(0xFFDC2626),
                                      ),
                                      SizedBox(width: sp(4)),
                                    ],
                                    Text(
                                      lancadoDisplay,
                                      style: TextStyle(
                                        fontSize: valueMainSize,
                                        fontWeight: FontWeight.w700,
                                        color: isRecebimento
                                            ? const Color(0xFF059669)
                                            : const Color(0xFFDC2626),
                                        decoration: isPaid ? TextDecoration.lineThrough : null,
                                        decorationColor: isRecebimento
                                            ? const Color(0xFF059669)
                                            : const Color(0xFFDC2626),
                                        decorationThickness: 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    // ESPAÇAMENTO entre linhas
                    SizedBox(height: sp(4)),
                    
                    // LINHA 2: Subtítulo (pill discreto opcional)
                    Row(
                      children: [
                        if (isCard && brandBadge != null) ...[
                          brandBadge,
                          SizedBox(width: sp(8)),
                        ] else if (headerChildIcon != null) ...[
                          headerChildIcon,
                          SizedBox(width: sp(6)),
                        ],
                        Flexible(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: sp(8),
                              vertical: sp(2.5),
                            ),
                            decoration: BoxDecoration(
                              // Pill discreto opcional (muito sutil)
                              color: isCardDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(sp(8)),
                            ),
                            child: Text(
                              middleLineText,
                              style: TextStyle(
                                fontSize: sp(14),  // 14px fixo para melhor legibilidade
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF374151),  // Cinza mais escuro (#374151)
                                height: 1.10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: sp(6)),
                    
                    // LINHA 3: Badges
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showBadgesRow)
                                Padding(
                                  padding: EdgeInsets.only(top: sp(4)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Chip "Pago" em cinza (sempre primeiro)
                                      if (isPaid) ...[
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: sp(8), vertical: sp(3)),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(sp(8)),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                size: badgeSize * 1.2,
                                                color: Colors.grey.shade600,
                                              ),
                                              SizedBox(width: sp(4)),
                                              Text(
                                                'Pago',
                                                style: TextStyle(
                                                  fontSize: badgeSize,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: sp(8)),
                                      ],
                                      if (isSinglePayment) ...[
                                        singlePaymentBadge,
                                      ],
                                      if (hasRecurrence && !isCard) ...[
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: sp(8), vertical: sp(3)),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(sp(8)),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            'Recorrência',
                                            style: TextStyle(
                                              fontSize: badgeSize,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                        if (installmentDisplay.isInstallment) SizedBox(width: sp(8)),
                                      ],
                                      if (installmentDisplay.isInstallment) ...[
                                        installmentBadge,
                                        SizedBox(width: sp(8)),
                                        nextDueBadge,
                                      ],
                                      if (showPrevisto) ...[
                                        if (installmentDisplay.isInstallment || (hasRecurrence && !isCard) || isSinglePayment)
                                          SizedBox(width: sp(8)),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: sp(8), vertical: sp(3)),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(sp(8)),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            'Previsto: $previstoDisplay',
                                            style: TextStyle(
                                              fontSize: badgeSize,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (isCard) ...[
                                        SizedBox(width: sp(8)),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: sp(8), vertical: sp(3)),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(sp(8)),
                                            border: Border.all(
                                              color: Colors.black,
                                              width: sp(1.25),
                                            ),
                                            boxShadow: badgeShadow,
                                          ),
                                          child: Text(
                                            'Próx.: $cardNextDueLabel',
                                            style: TextStyle(
                                              fontSize: badgeSize,
                                              fontWeight: FontWeight.w700,
                                              color: _adaptiveGreyTextColor(
                                                  context, Colors.grey.shade800),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: sp(8)),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: sp(8), vertical: sp(3)),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(sp(8)),
                                            border: Border.all(
                                              color: Colors.black,
                                              width: sp(1.25),
                                            ),
                                            boxShadow: badgeShadow,
                                          ),
                                          child: Text(
                                            'Previsto: $previstoDisplay',
                                            style: TextStyle(
                                              fontSize: badgeSize,
                                              fontWeight: FontWeight.w700,
                                              color: _adaptiveGreyTextColor(
                                                  context, Colors.grey.shade800),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              if (isPaid)
                                Padding(
                                  padding: EdgeInsets.only(top: sp(6)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () => _undoPayment(account),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: sp(6), vertical: sp(3)),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(sp(4)),
                                            border: Border.all(color: Colors.orange.shade300, width: sp(1)),
                                            boxShadow: badgeShadow,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.undo, size: sp(14), color: AppColors.warningDark),
                                              SizedBox(width: sp(4)),
                                              Text(
                                                'Desfazer',
                                                style: TextStyle(
                                                  fontSize: badgeSize,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.warningDark,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: sp(8)),
                                      Text(
                                        _isRecebimentosFilter ? '*** RECEBIDO ***' : '*** PAGO ***',
                                        style: TextStyle(
                                          color: AppColors.successDark,
                                          fontWeight: FontWeight.bold,
                                          fontSize: paidSize,
                                        ),
                                      ),
                                      SizedBox(width: sp(8)),
                                      Text(
                                        'via ${_paymentInfo[account.id!]?['method_name'] ?? ''}',
                                        style: TextStyle(
                                          fontSize: smallDateSize,
                                          color: _adaptiveGreyTextColor(context, Colors.grey.shade600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(width: sp(8)),
                        // Action Rail com transparência
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: sp(6), vertical: sp(4)),
                          decoration: BoxDecoration(
                            // Fundo: onColor (cor do texto) com 8% de opacidade
                            color: textColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(sp(6)),
                            // Divisória à esquerda com 15% de opacidade
                            border: Border(
                              left: BorderSide(
                                color: textColor.withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                          ),
                          child: actionButtons,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _undoPayment(Account account) async {
    if (account.id == null) return;
    final paymentInfo = _paymentInfo[account.id!];
    if (paymentInfo == null) return;

    final paymentId = paymentInfo['id'] as int?;
    if (paymentId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            _isRecebimentosFilter ? 'Desfazer Recebimento' : 'Desfazer Pagamento'),
        content: Text(
          _isRecebimentosFilter
              ? 'Deseja realmente desfazer o recebimento de "${account.description}"?'
              : 'Deseja realmente desfazer o pagamento de "${account.description}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Desfazer'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await DatabaseHelper.instance.deletePayment(paymentId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isRecebimentosFilter ? 'Recebimento desfeito' : 'Pagamento desfeito',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          _refresh();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isRecebimentosFilter
                  ? 'Erro ao desfazer recebimento: $e'
                  : 'Erro ao desfazer pagamento: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _undoLaunch(Account account) async {
    // Só aplica para instâncias lançadas (filhas) de recorrência
    if (account.id == null || account.recurrenceId == null) return;
    try {
      // Antes de remover a instância, garanta que o PAI tenha um valor previsto
      final parentId = account.recurrenceId!;
      final parent = await DatabaseHelper.instance.readAccountById(parentId);
      if (parent != null) {
        final double fallbackPrevisto =
            (account.estimatedValue ?? account.value).abs() > 0.009
                ? (account.estimatedValue ?? account.value)
                : (parent.estimatedValue ?? parent.value);

        if (fallbackPrevisto.abs() > 0.009 &&
            (parent.estimatedValue ?? 0) != fallbackPrevisto) {
          await DatabaseHelper.instance.updateAccount(
            parent.copyWith(
              estimatedValue: fallbackPrevisto,
              value: parent.value == 0 ? fallbackPrevisto : parent.value,
            ),
          );
        }
      }

      await DatabaseHelper.instance.deleteAccount(account.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lançamento desfeito — conta voltou para previsão'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao desfazer lançamento: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handlePayAction(Account account) async {
    // Se for uma recorrência PAI não lançada (sem id ou com id mas recurrenceId null e isRecurrent true),
    // precisamos criar a instância filha ANTES de abrir o diálogo de pagamento
    Account accountToUse = account;
    
    final isRecurrenceParent = account.isRecurrent && account.recurrenceId == null && account.cardBrand == null;
    
    if (isRecurrenceParent) {
      try {
        final month = account.month ?? _startDate.month;
        final year = account.year ?? _startDate.year;
        
        // Verificar se já existe uma instância lançada para este mês
        Account? existingInstance = await DatabaseHelper.instance.findInstanceByRecurrenceAndMonth(
          account.id!,
          month,
          year,
        );
        
        if (existingInstance != null) {
          // Usar a instância já existente
          accountToUse = existingInstance;
          debugPrint('💰 Usando instância existente: id=${existingInstance.id}');
        } else {
          // Criar nova instância filha para este mês específico
          final newInstance = account.copyWith(
            id: null, // Novo registro
            recurrenceId: account.id, // Link para o pai
            isRecurrent: false, // Instância não é recorrente
            month: month,
            year: year,
          );
          
          final newId = await DatabaseHelper.instance.createAccount(newInstance);
          accountToUse = newInstance.copyWith(id: newId);
          
          debugPrint('💰 Criada nova instância para pagamento: id=$newId, recurrenceId=${account.id}, month=$month, year=$year');
        }
      } catch (e) {
        debugPrint('❌ Erro ao criar instância de recorrência para pagamento: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao preparar conta para pagamento: $e')),
          );
        }
        return;
      }
    }
    
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final media = MediaQuery.of(dialogContext);
        final viewInsets = media.viewInsets.bottom;
        final maxWidth = (media.size.width * 0.92).clamp(280.0, 720.0);
        final availableHeight = media.size.height - viewInsets;
        final maxHeight = (availableHeight * 0.9).clamp(420.0, 900.0);
        return AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: viewInsets + 16,
          ),
          child: Dialog(
            insetPadding: EdgeInsets.zero,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: PaymentDialog(
                startDate: _startDate,
                endDate: _endDate,
                isRecebimento: _isRecebimentosFilter,
                preselectedAccount: accountToUse,
              ),
            ),
          ),
        );
      },
    );
    if (mounted) {
      _refresh();
    }
  }

  /// Constrói o badge da bandeira do cartão para uso nos diálogos
  Widget _buildCardBrandBadgeForDialog(String? brand, Color fallbackColor) {
    final normalized = (brand ?? '').trim().toUpperCase();
    const double badgeWidth = 36.0;
    const double badgeHeight = 24.0;

    if (normalized.isEmpty) {
      return Icon(Icons.credit_card, size: 24, color: fallbackColor);
    }

    // Usar imagens personalizadas para cada bandeira
    String? assetPath;
    if (normalized == 'VISA') {
      assetPath = 'assets/icons/cc_visa.png';
    } else if (normalized == 'AMEX' || normalized == 'AMERICAN EXPRESS' || normalized == 'AMERICANEXPRESS') {
      assetPath = 'assets/icons/cc_amex.png';
    } else if (normalized == 'MASTER' || normalized == 'MASTERCARD' || normalized == 'MASTER CARD') {
      assetPath = 'assets/icons/cc_mc.png';
    } else if (normalized == 'ELO') {
      assetPath = 'assets/icons/cc_elo.png';
    }

    if (assetPath != null) {
      return Image.asset(
        assetPath,
        package: 'finance_app',
        width: badgeWidth,
        height: badgeHeight,
        fit: BoxFit.contain,
      );
    }

    // Fallback para bandeiras não reconhecidas
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        normalized,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _actionIcon(IconData icon, Color bg, Color iconColor,
      {bool enabled = true,
      double size = 16,
      Color? borderColor,
      double borderWidth = 1,
      double scale = 1,
      Color? surfaceColor}) {
    Color resolvedBg = bg;
    if (surfaceColor != null) {
      resolvedBg = ColorContrast.adjustForContrast(bg, surfaceColor, targetRatio: 3.0);
    }
    Color resolvedIcon = iconColor;
    if (surfaceColor != null) {
      resolvedIcon = foregroundColorFor(resolvedBg);
    }

    final displayColor = enabled ? resolvedIcon : resolvedIcon.withValues(alpha: 0.6);
    final displayBg = enabled ? resolvedBg : resolvedBg.withValues(alpha: 0.5);
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Container(
          padding: EdgeInsets.all(5 * scale),
          decoration: BoxDecoration(
              color: displayBg,
              borderRadius: BorderRadius.circular(4 * scale),
              border: borderColor != null
                  ? Border.all(color: borderColor, width: borderWidth * scale)
                  : null),
          child: Icon(icon, size: size, color: displayColor)),
    );
  }

  Widget _borderedIcon(
    IconData icon, {
    Color? iconColor,
    double size = 20,
    EdgeInsetsGeometry padding = const EdgeInsets.all(4),
    Color? borderColor,
    double borderWidth = 1.2,
    BorderRadius? borderRadius,
  }) {
    final brightness = Theme.of(context).brightness;
    final resolvedIconColor = iconColor ?? Colors.grey.shade600;
    final resolvedBorderColor = borderColor ??
      (brightness == Brightness.dark ? Colors.white : Colors.grey.shade600);
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          border: Border.all(color: resolvedBorderColor, width: borderWidth),
          borderRadius: borderRadius ?? BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.7),
              blurRadius: 2,
              offset: const Offset(-1, -1),
            ),
          ],
        ),
        child: Icon(icon, size: size, color: resolvedIconColor),
      );
    }

  Future<void> _openCardExpenses(Account account) async {
    if (_isNavigating) return;
    _isNavigating = true;

    setState(() {
      _isInlineEditing = true;
      _inlinePreserveAppBar = true;
      _inlineEditWidget = CardExpensesScreen(
        card: account,
        month: _startDate.month,
        year: _startDate.year,
        inline: true,
        onClose: _closeInlineEdit,
      );
    });
  }

  Future<void> _openCardEditor(Account account) async {
    if (_isNavigating) return;
    _isNavigating = true;
    try {
      await showDialog(
        context: context,
        builder: (_) => CreditCardFormScreen(cardToEdit: account),
      );
      if (mounted) _refresh();
    } finally {
      _isNavigating = false;
    }
  }

  Future<Map<int, _InstallmentSummary>> _buildInstallmentSummaries(
      List<Account> accounts) async {
    final Map<int, _InstallmentSummary> result = {};
    final Map<String, _SeriesSummary?> cache = {};

    // Filtrar apenas contas que são parcelas
    final installments = accounts
        .where((a) => a.id != null && resolveInstallmentDisplay(a).isInstallment)
        .toList();

    for (final account in installments) {
      final display = resolveInstallmentDisplay(account);
      final accountId = account.id!;
      final key = _installmentSeriesKey(account, display);
      if (key == null) continue;

      if (!cache.containsKey(key)) {
        cache[key] = await _buildSeriesSummary(account, display);
      }

      final seriesSummary = cache[key];
      if (seriesSummary != null) {
        final summary = seriesSummary.summaryFor(account, display);
        if (summary != null) {
          result[accountId] = summary;
        }
      }
    }
    return result;
  }

  Future<_SeriesSummary?> _buildSeriesSummary(
      Account account, InstallmentDisplay display) async {
    final series = await _fetchInstallmentSeries(account, display);
    if (series.isEmpty) return null;

    final sorted = _sortInstallments(series);
    final total = sorted.fold<double>(0.0, (sum, item) => sum + item.value);

    // Calcular remaining amounts e idToIndex em uma única passagem
    final List<double> remaining = List<double>.filled(sorted.length, 0.0, growable: false);
    final Map<int, int> idToIndex = {};
    double running = 0.0;

    for (int i = sorted.length - 1; i >= 0; i--) {
      remaining[i] = running;
      running += sorted[i].value;

      final id = sorted[i].id;
      if (id != null) {
        idToIndex[id] = i;
      }
    }

    return _SeriesSummary(
      totalAmount: total,
      remainingFromIndex: remaining,
      idToIndex: idToIndex,
      orderedInstallments: sorted,
    );
  }

  Future<List<Account>> _fetchInstallmentSeries(
      Account account, InstallmentDisplay display) async {
    if (account.purchaseUuid?.isNotEmpty == true) {
      return DatabaseHelper.instance
          .readInstallmentSeriesByUuid(account.purchaseUuid!);
    }
    final db = await DatabaseHelper.instance.database;
    final String baseDescription = cleanAccountDescription(account);
    final clauses = <String>['isRecurrent = 0', 'description = ?'];
    final args = <Object?>[baseDescription];
    if (display.total > 1) {
      clauses.add('installmentTotal = ?');
      args.add(display.total);
    }
    if (account.cardId != null) {
      clauses.add('cardId = ?');
      args.add(account.cardId);
    } else {
      clauses.add('typeId = ?');
      args.add(account.typeId);
    }
    final rows = await db.query('accounts',
        where: clauses.join(' AND '),
        whereArgs: args,
        orderBy: 'year ASC, month ASC, dueDay ASC, id ASC');
    if (rows.isNotEmpty) {
      return rows.map((json) => Account.fromMap(json)).toList();
    }
    if (account.cardId != null) {
      return DatabaseHelper.instance.readInstallmentSeries(account.cardId!,
          baseDescription,
          installmentTotal: display.total);
    }
    return DatabaseHelper.instance.readInstallmentSeriesByDescription(
        account.typeId, baseDescription,
        installmentTotal: display.total);
  }

  String? _installmentSeriesKey(
      Account account, InstallmentDisplay display) {
    if (account.purchaseUuid?.isNotEmpty == true) {
      return 'uuid:${account.purchaseUuid}';
    }
    final baseDescription = cleanAccountDescription(account);
    if (baseDescription.isEmpty) return null;
    if (account.cardId != null) {
      return 'card:${account.cardId}:$baseDescription:${display.total}';
    }
    return 'type:${account.typeId}:$baseDescription:${display.total}';
  }

  List<Account> _sortInstallments(List<Account> source) {
    final sorted = List<Account>.from(source);
    sorted.sort(_compareAccountsByDate);
    return sorted;
  }

  int _compareAccountsByDate(Account a, Account b) {
    final yearCompare = (a.year ?? 0).compareTo(b.year ?? 0);
    if (yearCompare != 0) return yearCompare;
    final monthCompare = (a.month ?? 0).compareTo(b.month ?? 0);
    if (monthCompare != 0) return monthCompare;
    final dayCompare = a.dueDay.compareTo(b.dueDay);
    if (dayCompare != 0) return dayCompare;
    return (a.id ?? 0).compareTo(b.id ?? 0);
  }

  // ... (Diálogos mantidos)
  Future<void> _showLaunchDialog(Account rule) async {
    // Usar o estimatedValue (Valor Previsto) da recorrência pai
    double averageValue = rule.estimatedValue ?? rule.value;

    debugPrint('💰💰💰 LANÇANDO RECORRÊNCIA 💰💰💰');
    debugPrint('   rule.id=${rule.id} (DEVE SER A RECORRÊNCIA PAI)');
    debugPrint('   rule.recurrenceId=${rule.recurrenceId} (DEVE SER NULL para PAI)');
    debugPrint('   rule.isRecurrent=${rule.isRecurrent} (DEVE SER TRUE)');
    debugPrint('   rule.estimatedValue=${rule.estimatedValue}');
    debugPrint('   rule.value=${rule.value}');
    debugPrint('   averageValue final=$averageValue');

    // Controllers para valores médio e lançado
    final averageController =
        TextEditingController(text: UtilBrasilFields.obterReal(averageValue));
    final launchedValueController =
        TextEditingController(text: UtilBrasilFields.obterReal(averageValue));

    // Data padrão = dia filtrado (se houver) ou mês atual no dia do vencimento
    final useFilteredDay = DateUtils.isSameDay(_startDate, _endDate);
    DateTime nextDate = useFilteredDay
        ? _startDate
        : DateTime(_startDate.year, _startDate.month, rule.dueDay);

    var check = HolidayService.adjustDateToBusinessDay(
        nextDate, PrefsService.cityNotifier.value);
    final dateController = TextEditingController(
        text: DateFormat('dd/MM/yyyy').format(check.date));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lançar Parcela'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Recorrência: ${rule.description}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              // Campo Valor Médio (somente leitura)
              TextField(
                controller: averageController,
                readOnly: true,
                decoration: buildOutlinedInputDecoration(
                  label: 'Valor Médio (R\$)',
                  icon: Icons.trending_flat,
                ),
                style: TextStyle(color: _adaptiveGreyTextColor(context, Colors.grey.shade600)),
              ),
              const SizedBox(height: 12),
              // Campo Valor Lançado (editável) com botão de copiar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: launchedValueController,
                      decoration: buildOutlinedInputDecoration(
                        label: 'Valor Lançado (R\$)',
                        icon: Icons.attach_money,
                      ),
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        CentavosInputFormatter(moeda: true),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Copiar do Valor Médio',
                    child: IconButton(
                      icon: _borderedIcon(Icons.content_copy,
                          size: 18, padding: const EdgeInsets.all(4)),
                      onPressed: () {
                        launchedValueController.text = averageController.text;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Campo Data de Vencimento
              TextField(
                controller: dateController,
                readOnly: true,
                decoration: buildOutlinedInputDecoration(
                  label: 'Data de Vencimento',
                  icon: Icons.calendar_today,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton.icon(
            icon: _borderedIcon(Icons.check, size: 18, iconColor: Colors.white),
            label: const Text('Gravar'),
            onPressed: () async {
              if (launchedValueController.text.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Por favor, informe um valor'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                DateTime finalDate =
                    UtilData.obterDateTime(dateController.text);
                double finalValue =
                    UtilBrasilFields.converterMoedaParaDouble(
                        launchedValueController.text);

                debugPrint('🚀 Lançando recorrência:');
                debugPrint('   - Recorrência ID: ${rule.id}');
                debugPrint('   - Descrição: ${rule.description}');
                debugPrint('   - Valor Médio (Previsto): $averageValue');
                debugPrint('   - Valor Lançado: $finalValue');
                debugPrint('   - Data: ${finalDate.day}/${finalDate.month}/${finalDate.year}');

                // Procurar instância existente para este mês
                final existingInstance = await DatabaseHelper.instance.findInstanceByRecurrenceAndMonth(
                  rule.id!,
                  finalDate.month,
                  finalDate.year,
                );

                // Se valor zero, remover lançamento existente (ou manter sem lançar)
                if (finalValue == 0) {
                  if (existingInstance != null) {
                    debugPrint('🧹 Removendo instância lançada (valor zero) ID=${existingInstance.id}');
                    await DatabaseHelper.instance.deleteAccount(existingInstance.id!);
                  } else {
                    debugPrint('ℹ️ Valor zero informado e nenhuma instância lançada — mantendo apenas previsão.');
                  }
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Lançamento removido — conta voltou a previsão'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 2),
                      ),
                    );
                    _refresh();
                  }
                  return;
                }

                if (existingInstance != null) {
                  // ATUALIZAR a instância existente com o valor lançado
                  debugPrint('📝 Atualizando instância existente ID=${existingInstance.id} com valor $finalValue');
                  final updatedAccount = Account(
                    id: existingInstance.id,
                    typeId: existingInstance.typeId,
                    categoryId: existingInstance.categoryId,
                    description: existingInstance.description,
                    value: finalValue,
                    estimatedValue: averageValue, // garantir que o valor médio atualizado seja persistido
                    dueDay: finalDate.day,
                    month: finalDate.month,
                    year: finalDate.year,
                    isRecurrent: false,
                    payInAdvance: existingInstance.payInAdvance,
                    recurrenceId: existingInstance.recurrenceId,
                    cardBrand: existingInstance.cardBrand,
                    cardColor: existingInstance.cardColor,
                    cardBank: existingInstance.cardBank,
                    observation: existingInstance.observation,
                  );
                  await DatabaseHelper.instance.updateAccount(updatedAccount);
                  debugPrint('✅ Instância atualizada: ID=${existingInstance.id}, valor=$finalValue');
                } else {
                  // Criar nova instância (fallback se não existir)
                  final newAccount = Account(
                    typeId: rule.typeId,
                    categoryId: rule.categoryId,
                    description: rule.description,
                    value: finalValue,
                    estimatedValue: averageValue, // persistir valor médio atualizado
                    dueDay: finalDate.day,
                    month: finalDate.month,
                    year: finalDate.year,
                    isRecurrent: false,
                    payInAdvance: rule.payInAdvance,
                    recurrenceId: rule.id,
                    cardBrand: rule.cardBrand,
                    cardColor: rule.cardColor,
                    cardBank: rule.cardBank,
                    observation: rule.observation,
                  );

                  debugPrint('📝 Criando nova instância com recurrenceId=${rule.id}');
                  final id = await DatabaseHelper.instance.createAccount(newAccount);
                  debugPrint('✅ Parcela criada com ID: $id, recurrenceId=${rule.id}');
                }

                if (mounted) {
                  Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Parcela lançada: ${UtilBrasilFields.obterReal(finalValue)}'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  _refresh();
                }
              } catch (e, st) {
                debugPrint('❌ Erro ao lançar parcela: $e');
                debugPrintStack(stackTrace: st);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erro ao lançar parcela: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          )
        ],
      ),
    );
  }

  Future<void> _showExpenseDialog(Account card) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NewExpenseDialog(card: card),
    );
    if (mounted) {
      _refresh();
    }
  }

  Future<void> _showRecebimentoValueDialog(Account account) async {
    final previstoValue = account.estimatedValue ?? account.value;
    final valueController =
        TextEditingController(text: UtilBrasilFields.obterReal(previstoValue));
    final previstoController =
        TextEditingController(text: UtilBrasilFields.obterReal(previstoValue));
    DateTime initialDate = DateTime(account.year ?? _startDate.year,
        account.month ?? _startDate.month, account.dueDay);
    final check = HolidayService.adjustDateToBusinessDay(
        initialDate, PrefsService.cityNotifier.value);
    final dateController =
        TextEditingController(text: DateFormat('dd/MM/yyyy').format(check.date));

    final rawChildLabel = _categoryNames[account.categoryId] ?? 'Conta';
    // Remover a parte do pai (antes do ||) se existir
    final childLabel = rawChildLabel.contains('||')
        ? rawChildLabel.split('||').last.trim()
        : rawChildLabel;
    final childLogo = _categoryLogos[account.categoryId] ?? account.logo;
    final headerLogo = account.logo ?? childLogo;

    await showDialog(
      context: context,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final maxWidth = (media.size.width * 0.9).clamp(300.0, 520.0);
        final primaryColor = Theme.of(ctx).colorScheme.primary;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // AppBar
                Container(
                  color: primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      const Expanded(
                        child: Text(
                          'Lançamento de Recebimento',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Conteúdo
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Card com info da conta
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            if (headerLogo?.isNotEmpty ?? false)
                              Text(headerLogo!, style: const TextStyle(fontSize: 22))
                            else
                              Icon(Icons.attach_money, size: 22, color: primaryColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '$childLabel - ${account.description}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Data
                      TextField(
                        controller: dateController,
                        readOnly: true,
                        decoration: buildOutlinedInputDecoration(
                          label: 'Data do Vencimento',
                          icon: Icons.calendar_today,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Valor Previsto
                      TextField(
                        controller: previstoController,
                        readOnly: true,
                        decoration: buildOutlinedInputDecoration(
                          label: 'Valor Previsto (R\$)',
                          icon: Icons.trending_flat,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Valor Lançado
                      TextField(
                        controller: valueController,
                        decoration: buildOutlinedInputDecoration(
                          label: 'Valor Lançado (R\$)',
                          icon: Icons.attach_money,
                        ),
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          CentavosInputFormatter(moeda: true),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Botões
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Gravar'),
                            onPressed: () async {
                              if (valueController.text.isEmpty) return;
                              final finalDate = UtilData.obterDateTime(dateController.text);
                              final finalValue = UtilBrasilFields.converterMoedaParaDouble(
                                  valueController.text);

                              try {
                                final recurrenceKey = account.recurrenceId ?? (account.isRecurrent ? account.id : null);

                                if (finalValue == 0 && recurrenceKey != null) {
                                  // Valor zero: remover lançamento para este mês (se existir) e voltar à previsão
                                  Account? instanceToDelete = account.recurrenceId != null && account.id != null
                                      ? account
                                      : await DatabaseHelper.instance.findInstanceByRecurrenceAndMonth(
                                          recurrenceKey, finalDate.month, finalDate.year);

                                  if (instanceToDelete != null && instanceToDelete.id != null) {
                                    await DatabaseHelper.instance.deleteAccount(instanceToDelete.id!);
                                  }
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Lançamento removido — conta voltou a previsão'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    _refresh();
                                  }
                                  return;
                                }

                                final updated = account.copyWith(
                                  value: finalValue,
                                  dueDay: finalDate.day,
                                  month: finalDate.month,
                                  year: finalDate.year,
                                );
                                if (account.id != null) {
                                  await DatabaseHelper.instance.updateAccount(updated);
                                } else {
                                  await DatabaseHelper.instance.createAccount(updated);
                                }
                              } catch (e) {
                                debugPrint('❌ Erro ao lançar recebimento: $e');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content: Text('Erro ao lançar recebimento: $e')));
                                }
                                return;
                              }

                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) _refresh();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDespesaValueDialog(Account account) async {
    final previstoValue = account.estimatedValue ?? account.value;
    final valueController =
        TextEditingController(text: UtilBrasilFields.obterReal(previstoValue));
    final previstoController =
        TextEditingController(text: UtilBrasilFields.obterReal(previstoValue));
    DateTime initialDate = DateTime(account.year ?? _startDate.year,
        account.month ?? _startDate.month, account.dueDay);
    final check = HolidayService.adjustDateToBusinessDay(
        initialDate, PrefsService.cityNotifier.value);
    final dateController =
        TextEditingController(text: DateFormat('dd/MM/yyyy').format(check.date));

    final rawChildLabel = _categoryNames[account.categoryId] ?? 'Conta';
    final childLabel = rawChildLabel.contains('||')
        ? rawChildLabel.split('||').last.trim()
        : rawChildLabel;
    final childLogo = _categoryLogos[account.categoryId] ?? account.logo;
    final headerLogo = account.logo ?? childLogo;

    await showDialog(
      context: context,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final maxWidth = (media.size.width * 0.9).clamp(300.0, 520.0);
        final despesaColor = Colors.orange.shade700;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // AppBar
                Container(
                  color: despesaColor,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      const Expanded(
                        child: Text(
                          'Lançamento de Despesa',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Conteúdo
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Card com info da conta
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            if (headerLogo?.isNotEmpty ?? false)
                              Text(headerLogo!, style: const TextStyle(fontSize: 22))
                            else
                              Icon(Icons.receipt_long, size: 22, color: despesaColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '$childLabel - ${account.description}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Data
                      TextField(
                        controller: dateController,
                        readOnly: true,
                        decoration: buildOutlinedInputDecoration(
                          label: 'Data do Vencimento',
                          icon: Icons.calendar_today,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Valor Previsto
                      TextField(
                        controller: previstoController,
                        readOnly: true,
                        decoration: buildOutlinedInputDecoration(
                          label: 'Valor Previsto (R\$)',
                          icon: Icons.trending_flat,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Valor Lançado
                      TextField(
                        controller: valueController,
                        decoration: buildOutlinedInputDecoration(
                          label: 'Valor Lançado (R\$)',
                          icon: Icons.attach_money,
                        ),
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          CentavosInputFormatter(moeda: true),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Botões
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Gravar'),
                            style: FilledButton.styleFrom(backgroundColor: despesaColor),
                            onPressed: () async {
                              if (valueController.text.isEmpty) return;
                              final finalDate = UtilData.obterDateTime(dateController.text);
                              final finalValue = UtilBrasilFields.converterMoedaParaDouble(
                                  valueController.text);

                              try {
                                final recurrenceKey = account.recurrenceId ?? (account.isRecurrent ? account.id : null);

                                if (finalValue == 0 && recurrenceKey != null) {
                                  // Valor zero: remover lançamento para este mês (se existir) e voltar à previsão
                                  Account? instanceToDelete = account.recurrenceId != null && account.id != null
                                      ? account
                                      : await DatabaseHelper.instance.findInstanceByRecurrenceAndMonth(
                                          recurrenceKey, finalDate.month, finalDate.year);

                                  if (instanceToDelete != null && instanceToDelete.id != null) {
                                    await DatabaseHelper.instance.deleteAccount(instanceToDelete.id!);
                                  }
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Lançamento removido — conta voltou a previsão'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    _refresh();
                                  }
                                  return;
                                }

                                final updated = account.copyWith(
                                  value: finalValue,
                                  dueDay: finalDate.day,
                                  month: finalDate.month,
                                  year: finalDate.year,
                                );
                                if (account.id != null) {
                                  await DatabaseHelper.instance.updateAccount(updated);
                                } else {
                                  await DatabaseHelper.instance.createAccount(updated);
                                }
                              } catch (e) {
                                debugPrint('❌ Erro ao lançar despesa: $e');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content: Text('Erro ao lançar despesa: $e')));
                                }
                                return;
                              }

                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) _refresh();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCartaoValueDialog(Account account) async {
    final breakdown = CardBreakdown.parse(account.observation);
    final previstoValue = breakdown.total;
    final valueController =
        TextEditingController(text: UtilBrasilFields.obterReal(previstoValue));
    final previstoController =
        TextEditingController(text: UtilBrasilFields.obterReal(previstoValue));
    DateTime initialDate = DateTime(account.year ?? _startDate.year,
        account.month ?? _startDate.month, account.dueDay);
    final check = HolidayService.adjustDateToBusinessDay(
        initialDate, PrefsService.cityNotifier.value);
    final dateController =
        TextEditingController(text: DateFormat('dd/MM/yyyy').format(check.date));

    final cardBrand = account.cardBrand ?? 'Cartão';
    final cardBank = account.cardBank ?? '';

    await showDialog(
      context: context,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        final maxWidth = (media.size.width * 0.9).clamp(300.0, 520.0);
        final cartaoColor = Colors.orange.shade700;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // AppBar
                Container(
                  color: cartaoColor,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      const Expanded(
                        child: Text(
                          'Lançamento de Fatura',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Conteúdo
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Card com info do cartão
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            // Badge da bandeira do cartão
                            _buildCardBrandBadgeForDialog(account.cardBrand, cartaoColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '$cardBrand${cardBank.isNotEmpty ? ' - $cardBank' : ''}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Data
                      TextField(
                        controller: dateController,
                        readOnly: true,
                        decoration: buildOutlinedInputDecoration(
                          label: 'Data do Vencimento',
                          icon: Icons.calendar_today,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Valor Previsto
                      TextField(
                        controller: previstoController,
                        readOnly: true,
                        decoration: buildOutlinedInputDecoration(
                          label: 'Valor Previsto (R\$)',
                          icon: Icons.trending_flat,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Valor Lançado
                      TextField(
                        controller: valueController,
                        decoration: buildOutlinedInputDecoration(
                          label: 'Valor Lançado (R\$)',
                          icon: Icons.attach_money,
                        ),
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          CentavosInputFormatter(moeda: true),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Botões
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Gravar'),
                            style: FilledButton.styleFrom(backgroundColor: cartaoColor),
                            onPressed: () async {
                              if (valueController.text.isEmpty) return;
                              final finalDate = UtilData.obterDateTime(dateController.text);
                              final finalValue = UtilBrasilFields.converterMoedaParaDouble(
                                  valueController.text);

                              try {
                                if (account.id == null) {
                                  final updated = account.copyWith(
                                    value: finalValue,
                                    dueDay: finalDate.day,
                                    month: finalDate.month,
                                    year: finalDate.year,
                                  );
                                  await DatabaseHelper.instance.createAccount(updated);
                                } else {
                                  final parentId = account.id!;
                                  final existingInstance =
                                      await DatabaseHelper.instance.findInstanceByRecurrenceAndMonth(
                                    parentId,
                                    finalDate.month,
                                    finalDate.year,
                                  );

                                  if (finalValue == 0) {
                                    if (existingInstance != null) {
                                      await DatabaseHelper.instance.deleteAccount(existingInstance.id!);
                                    }
                                  } else if (existingInstance != null) {
                                    final updatedInstance = Account(
                                      id: existingInstance.id,
                                      typeId: existingInstance.typeId,
                                      categoryId: existingInstance.categoryId,
                                      description: existingInstance.description,
                                      value: finalValue,
                                      estimatedValue: previstoValue > 0 ? previstoValue : existingInstance.value,
                                      dueDay: finalDate.day,
                                      month: finalDate.month,
                                      year: finalDate.year,
                                      isRecurrent: false,
                                      payInAdvance: existingInstance.payInAdvance,
                                      recurrenceId: existingInstance.recurrenceId,
                                      cardBrand: existingInstance.cardBrand,
                                      cardColor: existingInstance.cardColor,
                                      cardBank: existingInstance.cardBank,
                                      observation: existingInstance.observation,
                                    );
                                    await DatabaseHelper.instance.updateAccount(updatedInstance);
                                  } else {
                                    final newAccount = Account(
                                      typeId: account.typeId,
                                      categoryId: account.categoryId,
                                      description: account.description,
                                      value: finalValue,
                                      estimatedValue: previstoValue > 0 ? previstoValue : account.value,
                                      dueDay: finalDate.day,
                                      month: finalDate.month,
                                      year: finalDate.year,
                                      isRecurrent: false,
                                      payInAdvance: account.payInAdvance,
                                      recurrenceId: parentId,
                                      cardBrand: account.cardBrand,
                                      cardColor: account.cardColor,
                                      cardBank: account.cardBank,
                                      observation: account.observation,
                                    );
                                    await DatabaseHelper.instance.createAccount(newAccount);
                                  }
                                }
                              } catch (e) {
                                debugPrint('❌ Erro ao lançar fatura: $e');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content: Text('Erro ao lançar fatura: $e')));
                                }
                                return;
                              }

                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) _refresh();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _closeInlineEdit() {
    if (!mounted) return;
    setState(() {
      _isInlineEditing = false;
      _inlineEditWidget = null;
      _isNavigating = false;
      _inlinePreserveAppBar = false;
    });
    _refresh();
  }

  Future<void> _showEditSpecificDialog(Account account) async {
    if (_isNavigating) return;
    _isNavigating = true;

    // Determinar se a conta editada é recebimento pelo tipo da conta
    final isRecebimento = _isRecebimentoAccount(account);

    // Usar AccountFormScreen para todos os tipos de conta, passando isRecebimento corretamente
    final screenToOpen = AccountFormScreen(
      accountToEdit: account,
      isRecebimento: isRecebimento,
      onClose: _closeInlineEdit,
    );

    setState(() {
      _isInlineEditing = true;
      _inlineEditWidget = screenToOpen;
      _inlinePreserveAppBar = false;
    });
  }

  bool _isRecebimentoAccount(Account account) {
    final typeName = _typeNames[account.typeId]?.trim().toLowerCase();
    if (typeName == null || typeName.isEmpty) {
      return _isRecebimentosFilter;
    }
    return typeName == 'recebimentos';
  }

  Future<void> _confirmDelete(Account acc) async {
    if (acc.id == null) return;

    debugPrint('🗑️ _confirmDelete iniciado para conta:');
    debugPrint('   id=${acc.id}');
    debugPrint('   description=${acc.description}');
    debugPrint('   isRecurrent=${acc.isRecurrent}');
    debugPrint('   recurrenceId=${acc.recurrenceId}');
    debugPrint('   installmentTotal=${acc.installmentTotal}');
    debugPrint('   month=${acc.month}, year=${acc.year}');

    // Se é recorrente (PAI ou FILHA) ou parcelada (installment)
    final isRecurringOrInstallment = acc.isRecurrent || acc.recurrenceId != null || (acc.installmentTotal != null && acc.installmentTotal! > 1);
    debugPrint('   isRecurringOrInstallment=$isRecurringOrInstallment');
    
    if (isRecurringOrInstallment) {
      // Determinar se é recorrência ou parcelamento
      final isInstallment = acc.installmentTotal != null && acc.installmentTotal! > 1 && acc.recurrenceId == null;
      final isRecurrence = acc.isRecurrent || acc.recurrenceId != null;
      debugPrint('   isInstallment=$isInstallment, isRecurrence=$isRecurrence');

      // Se é filha de recorrência, carregar o pai para referência
      Account? parent;
      if (acc.recurrenceId != null) {
        try {
          final allAccounts =
              await DatabaseHelper.instance.readAllAccountsRaw();
          parent = allAccounts.firstWhere(
            (a) => a.id == acc.recurrenceId,
            orElse: () => acc,
          );
        } catch (_) {
          parent = acc;
        }
      } else {
        parent = acc;
      }

      final dialogTitle = isInstallment ? 'Excluir Parcela' : 'Excluir Recorrência';
      final deleteAllText = isInstallment ? 'Apagar todas as parcelas' : 'Apagar todas as recorrências';

      final option = await showDialog<int>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(dialogTitle),
          content: Text('Como você deseja excluir "${acc.description}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 0),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 1),
              child: const Text('Apagar somente essa conta'),
            ),
            if (isRecurrence)
              TextButton(
                onPressed: () => Navigator.pop(ctx, 3),
                child: const Text('Apagar essa e futuras'),
              ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, 2),
              child: Text(deleteAllText),
            ),
          ],
        ),
      );

      if (option == null || option == 0) return;

      // Confirmar exclusão antes de prosseguir
      String confirmMessage;
      switch (option) {
        case 1:
          confirmMessage = 'Tem certeza que deseja apagar somente esta conta "${acc.description}"?';
          break;
        case 2:
          confirmMessage = isInstallment
              ? 'Tem certeza que deseja apagar TODAS as parcelas de "${acc.description}"?\n\nEsta ação não pode ser desfeita.'
              : 'Tem certeza que deseja apagar TODAS as recorrências de "${acc.description}"?\n\nEsta ação não pode ser desfeita.';
          break;
        case 3:
          confirmMessage = 'Tem certeza que deseja apagar "${acc.description}" e todas as recorrências futuras?\n\nEsta ação não pode ser desfeita.';
          break;
        default:
          return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: _borderedIcon(Icons.warning_amber_rounded,
              iconColor: Colors.orange, size: 48, padding: const EdgeInsets.all(6)),
          title: const Text('Confirmar Exclusão'),
          content: Text(confirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sim, Apagar'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      if (option == 1) {
        // Apagar apenas esta instância específica (sem cascata)
        try {
          // Verificar se é PAI (isRecurrent=true e recurrenceId=null) ou FILHA (recurrenceId != null)
          final isPai = acc.isRecurrent && acc.recurrenceId == null;
          debugPrint('🗑️ Opção 1 selecionada - isPai=$isPai');

          if (isPai) {
            // Se é PAI exibido como "previsão" (não lançado ainda no mês atual),
            // precisamos criar uma exceção para esse mês específico
            // Por agora: criar uma instância "cancelada" para esse mês (com valor 0)
            // ou simplesmente não fazer nada (o mês passa sem lançamento)
            
            // Nova abordagem: criar uma instância filha com valor 0 para "marcar como cancelado" esse mês
            debugPrint('🗑️ Opção 1: Conta é PAI - criando instância cancelada para o mês ${acc.month}/${acc.year}');
            
            // Verificar se já existe uma instância para esse mês
            final allAccounts = await DatabaseHelper.instance.readAllAccountsRaw();
            final existingInstance = allAccounts.where((a) =>
                a.recurrenceId == acc.id &&
                a.month == acc.month &&
                a.year == acc.year
            ).toList();
            
            if (existingInstance.isNotEmpty) {
              // Já existe instância, deletar ela
              debugPrint('🗑️ Encontrada instância existente id=${existingInstance.first.id}, deletando...');
              await DatabaseHelper.instance.deleteAccountOnly(existingInstance.first.id!);
            } else {
              // Não existe instância lançada - criar uma instância "cancelada"
              // para marcar que esse mês foi pulado
              debugPrint('📝 Criando instância cancelada para mês ${acc.month}/${acc.year}');
              
              // Criar instância filha com observation="[CANCELADA]" para marcar como pulada
              final cancelledInstance = Account(
                typeId: acc.typeId,
                categoryId: acc.categoryId,
                description: acc.description,
                value: 0,  // Valor 0 para não afetar totais
                dueDay: acc.dueDay,
                isRecurrent: false,  // Filha, não PAI
                month: acc.month,
                year: acc.year,
                recurrenceId: acc.id,  // Referência ao PAI
                observation: '[CANCELADA]',  // Marcador especial
              );
              
              await DatabaseHelper.instance.createAccount(cancelledInstance);
              debugPrint('✅ Instância cancelada criada com sucesso para ${acc.month}/${acc.year}');
            }
          } else {
            // Se é FILHA de recorrência, deletar ela E criar instância cancelada
            // para que o PAI não volte a aparecer
            debugPrint('🗑️ Opção 1: Conta é FILHA - deletando SOMENTE esta instância (id=${acc.id})');
            await DatabaseHelper.instance.deleteAccountOnly(acc.id!);
            
            // Se é filha de uma recorrência (tem recurrenceId), criar instância cancelada
            if (acc.recurrenceId != null) {
              debugPrint('📝 Criando instância cancelada para impedir PAI de reaparecer');
              final cancelledInstance = Account(
                typeId: acc.typeId,
                categoryId: acc.categoryId,
                description: acc.description,
                value: 0,
                dueDay: acc.dueDay,
                isRecurrent: false,
                month: acc.month,
                year: acc.year,
                recurrenceId: acc.recurrenceId,  // Referência ao PAI
                observation: '[CANCELADA]',
              );
              await DatabaseHelper.instance.createAccount(cancelledInstance);
              debugPrint('✅ Instância cancelada criada para ${acc.month}/${acc.year}');
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isPai ? 'Recorrência excluída com sucesso' : 'Conta excluída com sucesso'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
            _refresh();
          }
        } catch (e) {
          debugPrint('❌ Erro ao excluir conta: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao excluir: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else if (option == 3) {
        // Apagar atual e daqui pra frente (APENAS RECORRÊNCIAS)
        final confirmFuture = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmar'),
            content: Text(
              'Tem certeza que deseja excluir "${acc.description}" a partir dessa data?\n\nIsso vai apagar essa parcela e TODAS as futuras, mas mantém as anteriores.',
              style: const TextStyle(color: Colors.orange),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        );

        if (confirmFuture == true) {
          try {
            debugPrint('🗑️ Opção 3: Apagar esta e futuras recorrências');

            // Verificar se é PAI (isRecurrent=true e recurrenceId=null)
            final isPai = acc.isRecurrent && acc.recurrenceId == null;
            debugPrint('🗑️ isPai=$isPai');

            // Obter todas as contas para análise
            final allAccounts = await DatabaseHelper.instance.readAllAccountsRaw();

            // Obter a data do mês atual
            final currentDate = DateTime(acc.year ?? DateTime.now().year,
                acc.month ?? DateTime.now().month, 1);

            // Determinar qual recorrência estamos lidando
            final parentId = isPai ? acc.id : (acc.recurrenceId ?? acc.id);
            debugPrint('🗑️ parentId=$parentId, currentDate=${currentDate.month}/${currentDate.year}');

            // Apagar instâncias filhas atuais e futuras (mes/ano >= mes/ano atual)
            final futureAccounts = allAccounts.where((a) {
              if (a.recurrenceId != parentId) return false;

              final accDate =
                  DateTime(a.year ?? DateTime.now().year, a.month ?? 1, 1);
              return accDate.isAtSameMomentAs(currentDate) ||
                  accDate.isAfter(currentDate);
            }).toList();

            debugPrint('🗑️ Encontradas ${futureAccounts.length} instâncias futuras para deletar');

            int deletedCount = 0;
            for (final future in futureAccounts) {
              if (future.id != null) {
                debugPrint('🗑️ Apagando instância futura: ${future.description} (id=${future.id}, mês=${future.month}/${future.year})');
                await DatabaseHelper.instance.deleteAccountOnly(future.id!);
                deletedCount++;
              }
            }

            // Verificar se resta alguma instância filha ANTERIOR
            final remainingInstances = allAccounts.where((a) =>
                a.recurrenceId == parentId && 
                !futureAccounts.any((f) => f.id == a.id)
            ).toList();
            
            debugPrint('🗑️ Instâncias anteriores restantes: ${remainingInstances.length}');

            // SEMPRE deletar o PAI quando usar "essa e daqui pra frente"
            // As instâncias anteriores já existem como contas independentes no banco
            if (parentId != null) {
              debugPrint('🗑️ Deletando PAI (id=$parentId) para encerrar a recorrência');
              await DatabaseHelper.instance.deleteAccountOnly(parentId);
              deletedCount++;
              debugPrint('✅ Recorrência encerrada. Instâncias anteriores mantidas: ${remainingInstances.length}');
            }

            debugPrint('✅ Total de $deletedCount itens deletados');

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$deletedCount instância(s) excluída(s)'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
              debugPrint('📄 Atualizando tela...');
              _refresh();
            }
          } catch (e) {
            debugPrint('❌ Erro ao excluir instâncias futuras: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erro ao excluir: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      } else if (option == 2) {
        // Apagar tudo (recorrência ou parcelamento)
        late String confirmMessage;
        if (isInstallment) {
          confirmMessage = 'Tem certeza que deseja excluir TODAS as parcelas de "${acc.description}"?\n\nIsso vai apagar todas as ${acc.installmentTotal} parcelas.';
        } else {
          confirmMessage = 'Tem certeza que deseja excluir TODA a recorrência "${parent.description}"?\n\nIsso vai apagar a recorrência e TODAS as suas parcelas lançadas.';
        }

        final confirmAll = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmar'),
            content: Text(
              confirmMessage,
              style: const TextStyle(color: Colors.red),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Excluir Tudo'),
              ),
            ],
          ),
        );

        if (confirmAll == true) {
          try {
            if (isInstallment) {
              // Para parcelamentos: apagar todas as parcelas com mesmo installmentTotal e description
              final allInstallments = await DatabaseHelper.instance
                  .getAccountsByInstallmentTotal(acc.installmentTotal!, acc.description);

              for (final installment in allInstallments) {
                if (installment.id != null) {
                  debugPrint('🗑️ Apagando parcela: ${installment.description} (índice ${installment.installmentIndex}/${installment.installmentTotal})');
                  await DatabaseHelper.instance.deleteAccount(installment.id!);
                }
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${allInstallments.length} parcelas excluídas com sucesso'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
                _refresh();
              }
            } else {
              // Para recorrências: deletar PAI + todas as filhas manualmente
              final parentId = acc.recurrenceId ?? acc.id;

              if (parentId != null) {
                debugPrint('🗑️ Apagando recorrência completa (parentId=$parentId)');
                
                // Primeiro, buscar e deletar todas as instâncias filhas
                final allAccounts = await DatabaseHelper.instance.readAllAccountsRaw();
                final childInstances = allAccounts.where((a) => a.recurrenceId == parentId).toList();
                
                debugPrint('🗑️ Encontradas ${childInstances.length} instâncias filhas para deletar');
                
                for (final child in childInstances) {
                  if (child.id != null) {
                    debugPrint('🗑️ Deletando filha: ${child.description} (id=${child.id}, mês=${child.month}/${child.year})');
                    await DatabaseHelper.instance.deleteAccountOnly(child.id!);
                  }
                }
                
                // Depois, deletar o PAI
                debugPrint('🗑️ Deletando PAI (id=$parentId)');
                await DatabaseHelper.instance.deleteAccountOnly(parentId);
                debugPrint('✅ Recorrência completamente deletada (PAI + ${childInstances.length} filhas)');
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Recorrência "${parent.description}" excluída com sucesso'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
                _refresh();
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erro ao excluir: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      }
    } else {
      // Conta única (não recorrente) - confirmar simples
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: _borderedIcon(Icons.warning_amber_rounded,
              iconColor: Colors.orange, size: 48, padding: const EdgeInsets.all(6)),
          title: const Text('Confirmar Exclusão'),
          content: Text('Tem certeza que deseja excluir "${acc.description}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sim, Apagar'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        try {
          await DatabaseHelper.instance.deleteAccount(acc.id!);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Conta excluída'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            _refresh();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao excluir: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  bool get _isRecebimentosFilter {
    final filter = widget.typeNameFilter;
    if (filter == null) return false;
    return filter.trim().toLowerCase() == 'recebimentos';
  }

  Future<void> _openRecebimentoForm() async {
    await showDialog(
      context: context,
      builder: (_) => const RecebimentoFormScreen(),
    );
    _refresh();
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (ctx) => SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final maxHeight = constraints.maxHeight;
            const spacing = 10.0;
            const horizontalPadding = 16.0;
            final verticalPadding = maxHeight < 240 ? 12.0 : 20.0;
            final bottomOffset = math.max(24.0, maxHeight * 0.08);
            final availableHeight = math.max(0.0, maxHeight - bottomOffset);
            final maxTileWidth = math.max(
              0.0,
              (maxWidth - (horizontalPadding * 2) - (spacing * 3)) / 4,
            );
            final maxTileHeight =
                math.max(0.0, availableHeight - (verticalPadding * 2));
            final tileSize =
                math.min(104.0, math.min(maxTileWidth, maxTileHeight));
            final iconSize = math.min(28.0, tileSize * 0.35);
            final fontSize = math.min(12.0, math.max(8.0, tileSize * 0.12));
            final sheetHeight =
                math.min(availableHeight, tileSize + (verticalPadding * 2));

            return Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomOffset),
                child: Container(
                  height: sheetHeight,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: verticalPadding,
                    horizontal: horizontalPadding,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildQuickAction(
                        icon: Icons.receipt_long,
                        label: 'Conta a Pagar',
                        color: AppColors.error,
                        size: tileSize,
                        iconSize: iconSize,
                        fontSize: fontSize,
                        textColor: Colors.white,
                        iconColor: Colors.white,
                        iconBorderColor: Colors.white,
                        onTap: () async {
                          Navigator.pop(ctx);
                          await showDialog(
                            context: context,
                            builder: (dialogContext) => Dialog(
                              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                              backgroundColor: Colors.transparent,
                              child: Center(
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 700,
                                    maxHeight: 850,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).scaffoldBackgroundColor,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 16,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    children: [
                                      // Header com botão de fechar
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Nova Conta a Pagar',
                                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                            ),
                                            IconButton(
                                              icon: _borderedIcon(Icons.close,
                                                  size: 20, padding: const EdgeInsets.all(4)),
                                              onPressed: () => Navigator.pop(dialogContext),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 1),
                                      // Formulário expandido
                                      const Expanded(
                                        child: AccountFormScreen(showAppBar: false),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                          _refresh();
                        },
                      ),
                      const SizedBox(width: spacing),
                      _buildQuickAction(
                        icon: Icons.account_balance_wallet,
                        label: 'Conta a Receber',
                        color: AppColors.success,
                        size: tileSize,
                        iconSize: iconSize,
                        fontSize: fontSize,
                        textColor: Colors.white,
                        iconColor: Colors.white,
                        iconBorderColor: Colors.white,
                        onTap: () {
                          Navigator.pop(ctx);
                          _openRecebimentoForm();
                        },
                      ),
                      const SizedBox(width: spacing),
                      _buildQuickAction(
                        icon: Icons.credit_card,
                        label: 'Despesa Cartão',
                        color: AppColors.cardPurple,
                        size: tileSize,
                        iconSize: iconSize,
                        fontSize: fontSize,
                        onTap: () {
                          Navigator.pop(ctx);
                          _startCardExpenseFlow();
                        },
                      ),
                      const SizedBox(width: spacing),
                      _buildQuickAction(
                        icon: Icons.add_card,
                        label: 'Novo Cartão',
                        color: AppColors.cardPurple.withValues(alpha: 0.85),
                        size: tileSize,
                        iconSize: iconSize,
                        fontSize: fontSize,
                        onTap: () async {
                          Navigator.pop(ctx);
                          await showDialog(
                            context: context,
                            builder: (_) => const CreditCardFormScreen(),
                          );
                          _refresh();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    double size = 110,
    double iconSize = 30,
    double fontSize = 13,
    Color? textColor,
    Color? iconColor,
    Color? iconBorderColor,
  }) {
    final fg = textColor ?? foregroundColorFor(color);
    final padding = math.max(8.0, size * 0.12);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: EdgeInsets.all(padding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _borderedIcon(
              icon,
              iconColor: iconColor ?? fg,
              size: iconSize,
              padding: const EdgeInsets.all(4),
              borderWidth: 1,
              borderColor: iconBorderColor ?? fg,
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  fontSize: fontSize,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startCardExpenseFlow() async {
    final cards = (await DatabaseHelper.instance.readAllCards())
        .where((card) =>
            card.cardId == null &&
            card.cardBrand != null &&
            card.id != null)
        .toList()
      ..sort((a, b) {
        // Ordenar pelo dia de vencimento
        return a.dueDay.compareTo(b.dueDay);
      });

    if (cards.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastre um cartão antes de lançar despesas.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<Account>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Selecione o cartão',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: cards.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, index) {
                  final card = cards[index];
                  final baseColor = card.cardColor != null
                      ? Color(card.cardColor!)
                      : AppColors.cardPurple;
                  final dueDay =
                      card.dueDay.toString().padLeft(2, '0');
                  
                  // Obter logo da bandeira do cartão
                  Widget? brandLogo;
                  final normalized = (card.cardBrand ?? '').trim().toUpperCase();
                  String? assetPath;
                  if (normalized == 'VISA') {
                    assetPath = 'assets/icons/cc_visa.png';
                  } else if (normalized == 'AMEX' || normalized == 'AMERICAN EXPRESS' || normalized == 'AMERICANEXPRESS') {
                    assetPath = 'assets/icons/cc_amex.png';
                  } else if (normalized == 'MASTER' || normalized == 'MASTERCARD' || normalized == 'MASTER CARD') {
                    assetPath = 'assets/icons/cc_mc.png';
                  } else if (normalized == 'ELO') {
                    assetPath = 'assets/icons/cc_elo.png';
                  }
                  
                  if (assetPath != null) {
                    brandLogo = Image.asset(
                      assetPath,
                      package: 'finance_app',
                      width: 32,
                      height: 20,
                      fit: BoxFit.contain,
                    );
                  }
                  
                  // Cor zebrada para linhas alternadas
                  final isEven = index % 2 == 0;
                  final zebraColor = isEven
                      ? Colors.transparent
                      : Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
                  
                  return ListTile(
                    tileColor: zebraColor,
                    onTap: () => Navigator.pop(ctx, card),
                    leading: CircleAvatar(
                      backgroundColor: baseColor,
                      radius: 22,
                      child: brandLogo ?? _borderedIcon(
                        Icons.credit_card,
                        iconColor: foregroundColorFor(baseColor),
                        size: 18,
                        padding: const EdgeInsets.all(4),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    title: Text(card.cardBank ?? card.description),
                    subtitle: Text(
                      '${card.cardBrand ?? 'Cartão'} • Vencimento dia $dueDay',
                    ),
                    trailing: _borderedIcon(Icons.chevron_right,
                        size: 16, padding: const EdgeInsets.all(3)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null && mounted) {
      await _showExpenseDialog(selected);
    }
  }
}
