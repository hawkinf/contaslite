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
import '../utils/installment_utils.dart';
import '../widgets/app_input_decoration.dart';
import '../widgets/new_expense_dialog.dart';
import '../widgets/payment_dialog.dart';
import '../widgets/date_range_app_bar.dart';
import '../widgets/single_day_app_bar.dart';
import '../utils/card_utils.dart';
import '../widgets/dialog_close_button.dart';
import 'account_form_screen.dart';
import 'recebimento_form_screen.dart';
import 'credit_card_form.dart';
import 'card_expenses_screen.dart';
import 'account_edit_screen.dart';
import 'recurrent_account_edit_screen.dart' as rec;

class _InstallmentSummary {
  final double totalAmount;
  final double remainingAmount;


  const _InstallmentSummary({
    required this.totalAmount,
    required this.remainingAmount,
  });
}

class _SeriesSummary {
  final double totalAmount;
  final List<double> remainingFromIndex;
  final Map<int, int> idToIndex;

  const _SeriesSummary({
    required this.totalAmount,
    required this.remainingFromIndex,
    required this.idToIndex,
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
    return _InstallmentSummary(
      totalAmount: totalAmount,
      remainingAmount: remainingFromIndex[idx],
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final String? typeNameFilter;
  final String? excludeTypeNameFilter;

  const DashboardScreen({
    super.key,
    this.typeNameFilter,
    this.excludeTypeNameFilter,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isInlineEditing = false;

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
  bool _isLoading = false;
  double _totalPeriod = 0.0;
  double _totalForecast = 0.0;
  Map<int, _InstallmentSummary> _installmentSummaries = {};
  Map<int, Map<String, dynamic>> _paymentInfo = {};
  final Map<int, double> _recurrenceParentValues = {}; // Mapeia recurrence ID -> valor previsto


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

  String _formatRangeLabel(DateTime start, DateTime end) {
    final formatter = DateFormat('dd/MM/yyyy');
    return '${formatter.format(start)} ate ${formatter.format(end)}';
  }

  Future<void> _showFilterInfo() async {
    if (!_datesInitialized) {
      return;
    }
    final rangeLabel = _formatRangeLabel(_startDate, _endDate);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filtro'),
        content: Text('Periodo de $rangeLabel'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAppBarActions({required bool includeFilter}) {
    final actions = <Widget>[];
    if (includeFilter) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.filter_alt),
          tooltip: 'Filtro de periodo',
          onPressed: _showFilterInfo,
        ),
      );
    }
    return actions;
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
      final cards = await timed(
        'readAllCards',
        DatabaseHelper.instance.readAllCards(),
      );
      final typeMap = {for (var t in types) t.id!: t.name};

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
          final key = '${exp.recurrenceId}_${exp.year}_${exp.month}';
          launchedIndex.putIfAbsent(exp.recurrenceId!, () => {}).add(key);
          debugPrint('📝 Lançamento indexado: recurrenceId=${exp.recurrenceId}, key=$key, description=${exp.description}');
        }
      }
      // Também indexar instâncias canceladas para que o PAI não apareça
      for (final cancelled in cancelledInstances) {
        if (cancelled.recurrenceId != null) {
          final key = '${cancelled.recurrenceId}_${cancelled.year}_${cancelled.month}';
          launchedIndex.putIfAbsent(cancelled.recurrenceId!, () => {}).add(key);
          debugPrint('🚫 Instância cancelada indexada: recurrenceId=${cancelled.recurrenceId}, key=$key');
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
        final key = '${acc.year}_${acc.month}';
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
          processedList.addAll(monthAccounts);

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

      debugPrint('📊 Depois de filtros: ${processedList.length} contas');
      processedList.sort((a, b) => a.dueDay.compareTo(b.dueDay));
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

      if (mounted) {
        setState(() {
          _displayList = processedList;
          _typeNames = typeMap;
          _totalPeriod = totalPaid;
          _totalForecast = totalRemaining;
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
      final headerColor = isDark ? Colors.grey.shade900 : Colors.blue.shade50;
      final totalColor = _isRecebimentosFilter
          ? (isDark ? Colors.lightBlueAccent : Colors.blue.shade700)
          : (isDark ? Colors.redAccent : Colors.red.shade700);
      final totalForecastColor = _isRecebimentosFilter
          ? (isDark ? Colors.blueAccent : Colors.blue.shade700)
          : (isDark ? Colors.orangeAccent : Colors.deepOrange.shade700);
      final totalLabel = _isRecebimentosFilter ? 'TOTAL RECEBIDO' : 'TOTAL PAGO';
      final totalForecastLabel =
          _isRecebimentosFilter ? 'TOTAL A RECEBER' : 'TOTAL A PAGAR';
      final emptyText = _isRecebimentosFilter
          ? 'Nenhuma conta a receber para este mês.'
          : 'Nenhuma conta a pagar para este mês.';
      final appBarBg =
          _isRecebimentosFilter ? Colors.green.shade700 : Colors.red.shade700;
      const appBarFg = Colors.white;
      final isSingleDayFilter = DateUtils.isSameDay(_startDate, _endDate);
      final PreferredSizeWidget appBarWidget = isSingleDayFilter
          ? (SingleDayAppBar(
              date: _startDate,
              city: PrefsService.cityNotifier.value,
              backgroundColor: appBarBg,
              foregroundColor: appBarFg,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
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
               actions: _buildAppBarActions(includeFilter: true),
             ) as PreferredSizeWidget);
      final dashboardBody = SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
              final headerPadding = EdgeInsets.symmetric(
                vertical: isCompactHeight ? 10 : 16,
                horizontal: isCompactHeight ? 6 : 8,
              );
              final totalFontSize = isCompactHeight ? 22.0 : 28.0;
              final cardPadding = EdgeInsets.symmetric(
                horizontal: isCompactHeight ? 16 : 24,
                vertical: isCompactHeight ? 8 : 12,
              );
              final listBottomPadding = isCompactHeight ? 72.0 : 100.0;

              return Column(children: [
                Container(
                    padding: headerPadding,
                    color: headerColor,
                    child: Row(children: [
                      Expanded(
                          child: Container(
                              padding: cardPadding,
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
                              child: Column(children: [
                                Text(totalLabel,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.grey)),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(UtilBrasilFields.obterReal(_totalPeriod),
                                      style: TextStyle(
                                          fontSize: totalFontSize,
                                          fontWeight: FontWeight.bold,
                                          color: totalColor)),
                                )
                              ]))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Container(
                              padding: cardPadding,
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
                              child: Column(children: [
                                Text(totalForecastLabel,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.grey)),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(UtilBrasilFields.obterReal(_totalForecast),
                                      style: TextStyle(
                                          fontSize: totalFontSize,
                                          fontWeight: FontWeight.bold,
                                          color: totalForecastColor)),
                                )
                              ]))),
                    ])),
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
                            : ListView.builder(
                                padding: EdgeInsets.fromLTRB(
                                    0, 0, 0, listBottomPadding),
                                itemCount: _displayList.length,
                                itemBuilder: (context, index) {
                                  try {
                                    return _buildAccountCard(_displayList[index]);
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
                                })),
              ]);
          },
        ),
      );

      return Scaffold(
        appBar: _isInlineEditing ? null : appBarWidget,
        body: dashboardBody,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
        floatingActionButton: _isInlineEditing
            ? null
            : SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(right: fabRight, bottom: fabBottom),
                  child: FloatingActionButton(
                    heroTag: null,
                    tooltip: _isRecebimentosFilter
                        ? 'Novo recebimento'
                        : 'Novo lancamento',
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                    onPressed: _isRecebimentosFilter
                        ? _openRecebimentoForm
                        : _showQuickActions,
                    mini: isCompactFab,
                    child: const Icon(Icons.add),
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
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Erro ao carregar tela'),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
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
        final baseFontSize = screenWidth / 50; // Base unit for scaling

        // Define all font sizes proportionally
        final dayNumberSize = baseFontSize * 2.0;
        final smallDateSize = baseFontSize * 0.6;
        final weekdaySize = baseFontSize * 0.75;
        final statusSize = baseFontSize * 0.55;
        final categorySize = baseFontSize * 0.7;
        final descriptionSize = baseFontSize * 0.95;
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
  ) {
    // Tratamento de Data
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

    final weekdayName =
        DateFormat('EEEE', 'pt_BR').format(effectiveDate); // Dia da Semana

    // Configurações de Cor e Estilo
    bool isCard = account.cardBrand != null;
    // isRecurrent = true se é recorrência PAI OU é instância de recorrência
    bool isRecurrent = account.isRecurrent || account.recurrenceId != null;

    Color containerBg;
    Color cardColor;
    Color textColor;
    Color moneyColor;
    Color subTextColor;
    // customAccent removed (unused)

    if (isCard) {
      Color userColor = (account.cardColor != null)
          ? Color(account.cardColor!)
          : Colors.purple.shade900;
      cardColor = userColor;
      containerBg = Colors.transparent;
        textColor = foregroundColorFor(userColor);
      subTextColor = textColor.withValues(alpha: 0.8);
      moneyColor = textColor;
    } else {
      containerBg = isAlertDay ? Colors.red.shade800 : Colors.transparent;
      cardColor = isAlertDay ? Colors.white : Theme.of(context).cardColor;
      textColor = isAlertDay
          ? Colors.black87
          : (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black);
      subTextColor = Colors.grey.shade600;
      if (isRecurrent) {
        moneyColor = Colors.grey;
      } else {
        moneyColor =
            _isRecebimentosFilter ? Colors.green.shade700 : Colors.red.shade700;
      }
      if (Theme.of(context).brightness == Brightness.dark && !isRecurrent) {
        moneyColor = _isRecebimentosFilter ? Colors.lightGreenAccent : Colors.redAccent;
      }
      if (isAlertDay && !isRecurrent && !_isRecebimentosFilter) {
        moneyColor = Colors.red.shade900;
      }
    }

    // Dados para Cartão
    final breakdown = isCard ? CardBreakdown.parse(account.observation) : const CardBreakdown(total: 0, installments: 0, oneOff: 0, subscriptions: 0);
    final t = breakdown.total;
    String statusText = isRecurrent ? 'PREVISÃO [RECORRENTE]' : 'LANÇADO';
    Color statusColor = isRecurrent ? Colors.deepOrange : Colors.green;
    if (isCard) {
      statusText = isRecurrent ? 'PREVISÃO' : 'FATURA FECHADA';
      statusColor = isRecurrent ? Colors.white : Colors.black;
    }

    // Diferenciador: se é instância de recorrência (recurrenceId != null) E tem valor lançado (value > 0), foi lançado
    bool isLaunched = account.recurrenceId != null && account.value > 0.01;
    if (isRecurrent && isLaunched) {
      statusText = 'LANÇADO';
      statusColor = Colors.green;
    }
    final cleanedDescription =
        cleanAccountDescription(account).replaceAll('Fatura: ', '');
    final installmentSummary =
        account.id != null ? _installmentSummaries[account.id!] : null;
    final bool isPaid =
        account.id != null && _paymentInfo.containsKey(account.id!);
    final installmentDisplay = resolveInstallmentDisplay(account);
    final Color installmentBadgeBg = installmentDisplay.isInstallment
        ? Colors.deepPurple.shade50
        : Colors.green.shade50;
    final Color installmentBadgeTextColor = installmentDisplay.isInstallment
        ? Colors.deepPurple.shade700
        : Colors.green.shade700;
    final Widget installmentBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: installmentBadgeBg, borderRadius: BorderRadius.circular(8)),
        child: Text(installmentDisplay.labelText,
            style: TextStyle(
                fontSize: badgeSize,
                fontWeight: FontWeight.w600,
                color: installmentBadgeTextColor)));

    return Container(
      color: isCard ? null : containerBg,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Card(
        color: cardColor,
        elevation: 2,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          onTap: () async {
            if (isCard) {
              await _openCardExpenses(account);
            } else {
              await _showEditSpecificDialog(account);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              
              // 1. COLUNA DATA
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(effectiveDate.day.toString().padLeft(2, '0'),
                      style: TextStyle(
                          fontSize: dayNumberSize,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          height: 1.0)),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      children: [
                        Text(
                          "Orig. ${DateFormat('dd/MM').format(originalDate)}",
                          style: TextStyle(
                            fontSize: smallDateSize,
                            color: isCard ? subTextColor : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isAlertDay)
                          Text(
                            "Ajust. ${DateFormat('dd/MM').format(effectiveDate)}",
                            style: TextStyle(
                              fontSize: smallDateSize,
                              color: isCard ? subTextColor : Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // 2. COLUNA STATUS E NOME
              SizedBox(
                  width: 100,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(weekdayName,
                            style:
                                TextStyle(fontSize: weekdaySize, color: subTextColor)),
                        if (isHoliday)
                          Text('FERIADO',
                              style: TextStyle(
                                  fontSize: smallDateSize,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold)),
                        if (isWeekend && !isHoliday)
                          Text('FIM DE SEMANA',
                              style: TextStyle(
                                  fontSize: smallDateSize,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: (isCard ? Colors.white : statusColor)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4)),
                            child: Text(statusText,
                                style: TextStyle(
                                    fontSize: statusSize,
                                    fontWeight: FontWeight.bold,
                                    color: isCard ? textColor : statusColor)))
                      ])),

                const SizedBox(width: 12),

              // 3. COLUNA DESCRIÇÃO
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        isCard
                            ? account.cardBank ?? 'Cartão'
                            : _typeNames[account.typeId] ?? 'Outros',
                        style: TextStyle(fontSize: categorySize, color: subTextColor)),
                    Text(cleanedDescription,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: descriptionSize,
                            color: textColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    if (installmentDisplay.isInstallment)
                      Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            installmentBadge,
                            if (installmentSummary != null) ...[
                              Text(
                                  'Original: ${UtilBrasilFields.obterReal(installmentSummary.totalAmount)}',
                                  style: TextStyle(
                                      fontSize: badgeSize,
                                      color: textColor.withValues(alpha: 0.85),
                                      fontWeight: FontWeight.w600)),
                              Text(
                                  'Restam: ${UtilBrasilFields.obterReal(installmentSummary.remainingAmount)}',
                                  style: TextStyle(
                                      fontSize: badgeSize,
                                      color: textColor,
                                      fontWeight: FontWeight.bold)),
                            ]
                          ])
                    else
                      installmentBadge,
                  ])),

              // 4. COLUNA VALOR E ESTATÍSTICAS
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                // Renderizar valor com diferenciação entre previsto e lançado
                if (isRecurrent) ...[
                  // Se for lançamento, mostrar ambos (Previsto e Lançado)
                  if (isLaunched) ..._buildRecurrenceValues(account, valuePreviewSize, valueMainSize, smallDateSize) else ...[
                    // Recorrência prevista (não lançada) - mostrar estimatedValue
                    Text(
                      UtilBrasilFields.obterReal(account.estimatedValue ?? account.value),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: valuePreviewSize,
                        color: Colors.grey.shade600,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'PREVISTO',
                      style: TextStyle(
                        fontSize: smallDateSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ] else ...[
                  // Conta avulsa/parcelada: valor normal
                  Text(
                      UtilBrasilFields.obterReal(account.value),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: valueMainSize,
                          color: moneyColor)),
                ],
                // Indicador de pagamento com botão desfazer na mesma linha
                if (account.id != null && _paymentInfo.containsKey(account.id))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => _undoPayment(account),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.orange.shade300, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.undo, size: 12, color: Colors.orange.shade700),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Desfazer',
                                      style: TextStyle(
                                        color: Colors.orange.shade700,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isRecebimentosFilter
                                  ? '*** RECEBIDO ***'
                                  : '*** PAGO ***',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: paidSize,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'via ${_paymentInfo[account.id!]?['method_name'] ?? ''}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: smallDateSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  if (isCard) ...[
                    InkWell(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CreditCardFormScreen(cardToEdit: account),
                            ),
                          );
                          _refresh();
                        },
                        child: _actionIcon(Icons.edit,
                            textColor.withValues(alpha: 0.2), textColor, size: iconSize)),
                    const SizedBox(width: 6),
                    InkWell(
                        onTap: isPaid ? null : () => _handlePayAction(account),
                        child: _actionIcon(Icons.payments, Colors.blue.shade50,
                          Colors.blue.shade800,
                          enabled: !isPaid, size: iconSize)),
                    const SizedBox(width: 6),
                    InkWell(
                        onTap: () => _showExpenseDialog(account),
                        child: _actionIcon(Icons.add_shopping_cart,
                            textColor.withValues(alpha: 0.2), textColor, size: iconSize)),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _showLaunchInvoiceDialog(account, t),
                      child: _actionIcon(Icons.description,
                          Colors.orange.shade50, Colors.orange.shade700, size: iconSize),
                    ),
                    const SizedBox(width: 6),
                    if (account.id != null)
                      InkWell(
                        onTap: () => _confirmDelete(account),
                        child: _actionIcon(
                            Icons.delete, Colors.red.shade50, Colors.red.shade800, size: iconSize),
                      ),
                  ] else ...[
                    InkWell(
                        onTap: isPaid ? null : () => _handlePayAction(account),
                        child: _actionIcon(Icons.payments, Colors.blue.shade50,
                            Colors.blue.shade800,
                            enabled: !isPaid, size: iconSize)),
                    const SizedBox(width: 8),
                    if (isRecurrent && !isLaunched)
                      InkWell(
                          onTap: () async {
                            // Se é uma instância lançada, encontrar a recorrência pai no banco
                            Account parentRecurrence = account;
                            if (account.recurrenceId != null) {
                              // Esta é uma instância lançada, precisa encontrar a PAI no banco
                              final parentId = account.recurrenceId!;
                              try {
                                final parentAccount = await DatabaseHelper.instance.readAccountById(parentId);
                                if (parentAccount != null) {
                                  parentRecurrence = parentAccount;
                                  debugPrint('✅ Encontrada recorrência PAI: ${account.id} → ${parentRecurrence.id} (isRecurrent=${parentRecurrence.isRecurrent})');
                                } else {
                                  debugPrint('⚠️ Recorrência PAI não encontrada (ID: $parentId)');
                                }
                              } catch (e) {
                                debugPrint('❌ Erro ao buscar recorrência PAI: $e');
                              }
                            }
                            if (mounted) _showLaunchDialog(parentRecurrence);
                          },
                          child: _actionIcon(Icons.rocket_launch,
                              Colors.green.shade50, Colors.green.shade800, size: iconSize)),
                    if (isRecurrent && !isLaunched)
                      const SizedBox(width: 8),
                    InkWell(
                        onTap: () => _confirmDelete(account),
                        child: _actionIcon(Icons.delete, Colors.red.shade50,
                            Colors.red.shade800, size: iconSize)),
                  ]
                ]),
              ]),
            ]),
          ),
        ),
      ),
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

  Future<void> _handlePayAction(Account account) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentDialog(
          startDate: _startDate,
          endDate: _endDate,
          isRecebimento: _isRecebimentosFilter,
          preselectedAccount: account,
        ),
      ),
    );
    if (mounted) {
      _refresh();
    }
  }

  Widget _actionIcon(IconData icon, Color bg, Color iconColor,
      {bool enabled = true, double size = 16}) {
    final displayColor = enabled ? iconColor : iconColor.withValues(alpha: 0.4);
    final displayBg = enabled ? bg : bg.withValues(alpha: 0.3);
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
              color: displayBg, borderRadius: BorderRadius.circular(4)),
          child: Icon(icon, size: size, color: displayColor)),
    );
  }

  Future<void> _openCardExpenses(Account account) async {
    if (account.month == null || account.year == null) return;
    final card = Account(
      id: account.id,
      typeId: account.typeId,
      description: account.description.replaceAll('Fatura: ', ''),
      value: 0,
      dueDay: account.dueDay,
      month: account.month,
      year: account.year,
      isRecurrent: account.isRecurrent,
      payInAdvance: account.payInAdvance,
      cardBrand: account.cardBrand,
      cardBank: account.cardBank,
      cardLimit: account.cardLimit,
      cardColor: account.cardColor,
    );
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CardExpensesScreen(
                card: card, month: account.month!, year: account.year!)));
    if (mounted) {
      _refresh();
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

  List<Widget> _buildRecurrenceValues(Account account, double valuePreviewSize, double valueMainSize, double smallTextSize) {
    // Para lançamentos de recorrência, mostrar Previsto e Lançado
    // Valor Previsto = estimatedValue (predicted/average value)
    double estimatedValue = account.estimatedValue ?? account.value;
    // Valor Lançado = value (actual launched value, 0 if not launched yet)
    double launchedValue = account.value;

    return [
      // Linha com Previsto à esquerda e Lançado à direita
      Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Valor previsto (cinza, tachado, menor)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                UtilBrasilFields.obterReal(estimatedValue),
                style: TextStyle(
                  fontSize: valuePreviewSize * 0.9,
                  color: Colors.grey.shade600,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: Colors.grey.shade400,
                ),
              ),
              Text(
                'Previsto',
                style: TextStyle(
                  fontSize: smallTextSize * 0.7,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          // Valor lançado (vermelho, normal, maior)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                UtilBrasilFields.obterReal(launchedValue),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: valueMainSize,
                  color: Colors.red.shade700,
                ),
              ),
              Text(
                'LANÇADO',
                style: TextStyle(
                  fontSize: smallTextSize * 0.8,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    ];
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
                style: TextStyle(color: Colors.grey.shade600),
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
                      icon: const Icon(Icons.content_copy),
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
            icon: const Icon(Icons.check),
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

                // Validação: valor não pode ser zero
                if (finalValue == 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Valor lançado não pode ser zero'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

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

                if (existingInstance != null) {
                  // ATUALIZAR a instância existente com o valor lançado
                  debugPrint('📝 Atualizando instância existente ID=${existingInstance.id} com valor $finalValue');
                  final updatedAccount = Account(
                    id: existingInstance.id,
                    typeId: existingInstance.typeId,
                    description: existingInstance.description,
                    value: finalValue,
                    estimatedValue: existingInstance.estimatedValue,
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
                    description: rule.description,
                    value: finalValue,
                    estimatedValue: rule.estimatedValue,
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

  Future<void> _showLaunchInvoiceDialog(Account card, double forecastValue) async {
    final valueController =
        TextEditingController(text: UtilBrasilFields.obterReal(forecastValue));
    DateTime initialDate = DateTime(card.year ?? _startDate.year,
        card.month ?? _startDate.month, card.dueDay);
    var check = HolidayService.adjustDateToBusinessDay(
        initialDate, PrefsService.cityNotifier.value);
    final dateController = TextEditingController(
        text: DateFormat('dd/MM/yyyy').format(check.date));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lançar Fatura do Cartão'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: valueController,
              decoration: buildOutlinedInputDecoration(
                label: 'Valor da Fatura (R\$)',
                icon: Icons.attach_money,
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CentavosInputFormatter(moeda: true),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dateController,
              readOnly: true,
              decoration: buildOutlinedInputDecoration(
                label: 'Data do Vencimento',
                icon: Icons.calendar_today,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Gravar'),
            onPressed: () async {
              if (valueController.text.isEmpty) return;
              DateTime finalDate = UtilData.obterDateTime(dateController.text);
              double finalValue = UtilBrasilFields.converterMoedaParaDouble(
                  valueController.text);

              try {
                final invoice = Account(
                  typeId: card.typeId,
                  description: 'Fatura: ${card.cardBank} - ${card.cardBrand}',
                  value: finalValue,
                  dueDay: finalDate.day,
                  month: finalDate.month,
                  year: finalDate.year,
                  isRecurrent: false,
                  payInAdvance: card.payInAdvance,
                  recurrenceId: card.id,
                  cardBrand: card.cardBrand,
                  cardBank: card.cardBank,
                  cardColor: card.cardColor,
                  cardLimit: card.cardLimit,
                  bestBuyDay: card.bestBuyDay,
                );

                await DatabaseHelper.instance.createAccount(invoice);

                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Fatura de ${UtilBrasilFields.obterReal(finalValue)} lançada'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  _refresh();
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erro ao lançar fatura: $e'),
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
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NewExpenseDialog(card: card)),
    );
    if (mounted) {
      _refresh();
    }
  }

  Future<void> _showPaymentDialog() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentDialog(
          startDate: _startDate,
          endDate: _endDate,
          isRecebimento: _isRecebimentosFilter,
        ),
      ),
    );
    if (mounted) {
      _refresh();
    }
  }

  Future<void> _showEditSpecificDialog(Account account) async {
    // Detectar se é recorrente (pai ou filha)
    final isRecurrentParent = account.isRecurrent && account.recurrenceId == null;
    final isRecurrentChild = account.recurrenceId != null;

    Widget screenToOpen;
    if (isRecurrentParent || isRecurrentChild) {
      // Abrir tela de edição de recorrentes
      screenToOpen = rec.RecurrentAccountEditScreen(
        account: account,
        isRecebimento: _isRecebimentosFilter,
      );
    } else {
      // Abrir tela normal de edição
      screenToOpen = AccountEditScreen(account: account);
    }

    setState(() => _isInlineEditing = true);
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => screenToOpen),
    );
    if (!mounted) return;
    setState(() => _isInlineEditing = false);
    _refresh();
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
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
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
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
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
              (maxWidth - (horizontalPadding * 2) - (spacing * 2)) / 3,
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
                        label: 'Lançar Conta',
                        color: Colors.blue.shade600,
                        size: tileSize,
                        iconSize: iconSize,
                        fontSize: fontSize,
                        onTap: () async {
                          Navigator.pop(ctx);
                          await showDialog(
                            context: context,
                            builder: (dialogContext) => Dialog(
                              insetPadding: EdgeInsets.zero,
                              backgroundColor: Colors.transparent,
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 700,
                                    maxHeight: 950,
                                  ),
                                  child: Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.3),
                                              blurRadius: 16,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: const SingleChildScrollView(
                                          child: AccountFormScreen(),
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: DialogCloseButton(
                                          onPressed: () => Navigator.pop(dialogContext),
                                        ),
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
                        icon: Icons.credit_card,
                        label: 'Despesa Cartão',
                        color: Colors.deepPurple.shade500,
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
                        icon: Icons.payments,
                        label: 'Lançar Pagamento',
                        color: Colors.green.shade600,
                        size: tileSize,
                        iconSize: iconSize,
                        fontSize: fontSize,
                        onTap: () {
                          Navigator.pop(ctx);
                          _showPaymentDialog();
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
  }) {
    final fg = foregroundColorFor(color);
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
          children: [
            Icon(icon, color: fg, size: iconSize),
            const SizedBox(height: 8),
            Text(
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
        final bankA = (a.cardBank ?? a.description).toLowerCase();
        final bankB = (b.cardBank ?? b.description).toLowerCase();
        return bankA.compareTo(bankB);
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
                      : Colors.purple.shade700;
                  final dueDay =
                      card.dueDay.toString().padLeft(2, '0');
                  return ListTile(
                    onTap: () => Navigator.pop(ctx, card),
                    leading: CircleAvatar(
                      backgroundColor: baseColor,
                      child: Icon(
                        Icons.credit_card,
                        color: foregroundColorFor(baseColor),
                      ),
                    ),
                    title: Text(card.cardBank ?? card.description),
                    subtitle: Text(
                      '${card.cardBrand ?? 'Cartão'} • Vencimento dia $dueDay',
                    ),
                    trailing: const Icon(Icons.chevron_right),
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
