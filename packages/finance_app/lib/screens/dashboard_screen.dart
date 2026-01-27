// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:brasil_fields/brasil_fields.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../services/prefs_service.dart';
import '../services/holiday_service.dart';
import '../services/default_account_categories_service.dart';
import '../utils/color_contrast.dart';
import 'card_expenses_screen.dart';
import '../utils/app_colors.dart';
import '../utils/installment_utils.dart';
import '../widgets/app_input_decoration.dart';
import '../widgets/new_expense_dialog.dart';
import '../widgets/payment_dialog.dart';
import '../widgets/single_day_app_bar.dart';
import '../utils/card_utils.dart';
import 'account_form_screen.dart';
import 'recebimento_form_screen.dart';
import 'credit_card_form.dart';
import '../ui/theme/app_colors.dart' as app_tokens;
import '../ui/theme/app_spacing.dart';
import '../ui/components/filter_bar.dart';
import '../ui/widgets/date_pill.dart';
import '../ui/components/entry_card.dart';
import '../ui/widgets/mini_chip.dart';
import '../ui/components/summary_card.dart';
import '../ui/components/action_banner.dart';
import '../ui/components/standard_modal_shell.dart';
import '../ui/components/section_header.dart';
import '../ui/components/period_header.dart';

enum DashboardFilter { all, pagar, receber, cartoes }

class _QuickActionItem {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });
}

class _MenuAction {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _MenuAction({required this.label, required this.icon, this.onTap});
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
  // Page stack for internal navigation (replaces single inline widget)
  final List<Widget> _pageStack = [];
  bool _isNavigating = false;

  // ScrollController for the main list
  final ScrollController _listScrollController = ScrollController();

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
  Map<int, String> _categoryNames = {};
  Map<int, String> _categoryLogos = {};
  Map<int, String> _categoryParentNames = {}; // categoria ID -> nome da categoria pai

  bool _isLoading = false;
  double _totalPeriod = 0.0;
  double _totalForecast = 0.0;
  double _totalPrevistoPagar = 0.0;
  double _totalPrevistoReceber = 0.0;
  // Totais para visão combinada
  double _totalLancadoPagar = 0.0;
  double _totalLancadoReceber = 0.0;
  Map<int, Map<String, dynamic>> _paymentInfo = {};
  final Map<int, double> _recurrenceParentValues = {}; // Mapeia recurrence ID -> valor previsto
  DashboardFilter _categoryFilter = DashboardFilter.all;
  
  // Novos filtros
  bool _hidePaidAccounts = true; // Ocultar contas pagas/recebidas (true = oculta)
  String _periodFilter = 'month'; // 'today', 'tomorrow', 'yesterday', 'currentWeek', 'nextWeek', 'month'
  // Controle do FAB durante scroll
  bool _isFabVisible = true;
  
  // Estado de seleção de card
  final ValueNotifier<Account?> _selectedConta = ValueNotifier<Account?>(null);

  bool _handleScrollNotification(UserScrollNotification notification) {
    final direction = notification.direction;
    if (direction == ScrollDirection.reverse && _isFabVisible) {
      setState(() => _isFabVisible = false);
    } else if (direction == ScrollDirection.forward && !_isFabVisible) {
      setState(() => _isFabVisible = true);
    }
    return false;
  }


  @override
  void dispose() {
    PrefsService.dateRangeNotifier.removeListener(_dateRangeListener);
    _selectedConta.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.typeNameFilter != widget.typeNameFilter ||
        oldWidget.excludeTypeNameFilter != widget.excludeTypeNameFilter) {
      _clearSelection();
    }
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
    _clearSelection();
    PrefsService.saveDateRange(newStart, newEnd);
  }

  Future<void> _pickMonthYear() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Selecionar mês',
    );
    if (picked == null) return;
    final newStart = DateTime(picked.year, picked.month, 1);
    final newEnd = DateTime(newStart.year, newStart.month + 1, 0);
    _clearSelection();
    PrefsService.saveDateRange(newStart, newEnd);
  }

  void _clearSelection() {
    if (_selectedConta.value == null) return;
    setState(() => _selectedConta.value = null);
  }

  String _formatMonthYear(DateTime date) {
    final label = DateFormat('MMMM yyyy', 'pt_BR').format(date);
    if (label.isEmpty) return label;
    return label[0].toUpperCase() + label.substring(1);
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
      case 'today':
        start = DateTime(now.year, now.month, now.day);
        end = start;
        break;
      case 'tomorrow':
        start = DateTime(now.year, now.month, now.day + 1);
        end = start;
        break;
      case 'yesterday':
        start = DateTime(now.year, now.month, now.day - 1);
        end = start;
        break;
      case 'currentWeek':
        // Semana corrente (segunda a domingo)
        final weekdayIndex = now.weekday - 1; // Segunda = 0
        start = DateTime(now.year, now.month, now.day - weekdayIndex);
        end = start.add(const Duration(days: 6));
        break;
      case 'nextWeek':
        // Próxima semana (segunda a domingo)
        final weekdayIndex = now.weekday - 1;
        final nextMonday = DateTime(now.year, now.month, now.day - weekdayIndex + 7);
        start = nextMonday;
        end = start.add(const Duration(days: 6));
        break;
      case 'month':
      default:
        // Mês atual
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0);
        break;
    }

    setState(() {
      _startDate = start;
      _endDate = end;
    });
    _loadData();
  }

  bool get _isCombinedView => widget.typeNameFilter == null && widget.excludeTypeNameFilter == null;

  Widget _buildTopControlsBar() {
    return FilterBar(
      selected: _mapDashboardFilter(_categoryFilter),
      onSelected: (value) {
        setState(() => _categoryFilter = _mapAccountFilter(value));
        _clearSelection();
        _loadData();
      },
      showPaid: _hidePaidAccounts,
      onShowPaidChanged: (value) {
        setState(() => _hidePaidAccounts = value);
        _clearSelection();
        _loadData();
      },
      periodValue: _periodFilter,
      onPeriodChanged: (value) {
        setState(() => _periodFilter = value);
        _clearSelection();
        _applyPeriodFilter(value);
      },
    );
  }

  AccountFilterType _mapDashboardFilter(DashboardFilter filter) {
    switch (filter) {
      case DashboardFilter.pagar:
        return AccountFilterType.pagar;
      case DashboardFilter.receber:
        return AccountFilterType.receber;
      case DashboardFilter.cartoes:
        return AccountFilterType.cartoes;
      case DashboardFilter.all:
        return AccountFilterType.all;
    }
  }

  DashboardFilter _mapAccountFilter(AccountFilterType filter) {
    switch (filter) {
      case AccountFilterType.pagar:
        return DashboardFilter.pagar;
      case AccountFilterType.receber:
        return DashboardFilter.receber;
      case AccountFilterType.cartoes:
        return DashboardFilter.cartoes;
      case AccountFilterType.all:
        return DashboardFilter.all;
    }
  }

  Widget _buildMonthNavBar(String label) {
    return PeriodHeader(
      label: label,
      onPrevious: () => _changeMonth(-1),
      onNext: () => _changeMonth(1),
      onTap: _pickMonthYear,
    );
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
      final categoryMap = {
        for (final c in categories)
          if (c.id != null) c.id!: c.categoria,
      };
      // Mapa de logos diretos das categorias (do banco)
      final directLogoMap = <int, String>{
        for (final c in categories)
          if (c.id != null && (c.logo?.trim().isNotEmpty ?? false))
            c.id!: c.logo!.trim(),
      };

      // Construir mapa inverso: subcategoria nome → categoria pai nome
      // usando os dados do DefaultAccountCategoriesService
      final subcategoryToParentMap = <String, String>{};
      final service = DefaultAccountCategoriesService.instance;
      final allCategoryDefs = service.getDefaultCategories();
      for (final catDef in allCategoryDefs) {
        final parentName = catDef.category;
        for (final subName in catDef.subcategories) {
          subcategoryToParentMap[subName.toLowerCase()] = parentName;
        }
      }
      // Também incluir subcategorias de Recebimentos (pai||filho)
      final recebimentosChildDefs = service.getRecebimentosChildDefaults();
      for (final entry in recebimentosChildDefs.entries) {
        final recebimentosPai = entry.key; // ex: "Salário/Pró-Labore"
        for (final filho in entry.value) {
          // Para Recebimentos, o pai imediato é a subcategoria de Recebimentos
          subcategoryToParentMap[filho.toLowerCase()] = recebimentosPai;
          // E a subcategoria de Recebimentos tem "Recebimentos" como avô
          subcategoryToParentMap[recebimentosPai.toLowerCase()] = 'Recebimentos';
        }
      }

      // Mapa de categoria ID -> nome da categoria pai
      final categoryParentNameMap = <int, String>{};
      // Mapa final de logos
      final categoryLogoMap = <int, String>{};

      for (final c in categories) {
        if (c.id == null) continue;
        final catName = c.categoria.trim();
        final catNameLower = catName.toLowerCase();

        // Tratar formato especial "Parent||Child" (Recebimentos)
        final bool hasRecSeparator = catName.contains('||');
        String? recParentName;
        String? recChildName;
        if (hasRecSeparator) {
          final parts = catName.split('||');
          if (parts.length >= 2) {
            recParentName = parts[0].trim();
            recChildName = parts[1].trim();
          }
        }

        // Verificar se é uma categoria pai (existe em categoryLogos)
        final isParentCategory = DefaultAccountCategoriesService.categoryLogos.containsKey(catName);

        if (hasRecSeparator && recParentName != null) {
          // Categoria com formato "||" - o pai é recParentName
          categoryParentNameMap[c.id!] = recParentName;
        } else if (!isParentCategory) {
          // É uma subcategoria normal - encontrar o pai pelo nome
          final parentName = subcategoryToParentMap[catNameLower];
          if (parentName != null) {
            categoryParentNameMap[c.id!] = parentName;
          }
        }

        // Determinar logo para esta categoria
        if (directLogoMap.containsKey(c.id)) {
          // Tem logo próprio no banco
          categoryLogoMap[c.id!] = directLogoMap[c.id]!;
        } else if (hasRecSeparator && recParentName != null && recChildName != null) {
          // Categoria com formato "||" - usar logo do filho de Recebimentos
          final childLogo = DefaultAccountCategoriesService.getLogoForRecebimentosFilho(recParentName, recChildName);
          categoryLogoMap[c.id!] = childLogo;
        } else if (isParentCategory) {
          // É categoria pai - usar logo do serviço
          final logo = DefaultAccountCategoriesService.categoryLogos[catName];
          if (logo != null) {
            categoryLogoMap[c.id!] = logo;
          }
        } else {
          // É subcategoria normal - tentar logo do serviço baseado no pai
          final parentName = categoryParentNameMap[c.id!];
          if (parentName != null) {
            // Primeiro tenta o logo específico da subcategoria
            final subLogo = DefaultAccountCategoriesService.getLogoForSubcategoryInCategory(parentName, catName);
            categoryLogoMap[c.id!] = subLogo;
          }
        }
      }

      debugPrint('📋 Tipos no banco: ${types.map((t) => '${t.name}(id: ${t.id})').join(', ')}');
      debugPrint('📋 Total de contas: ${allAccounts.length}');
      debugPrint('🔗 categoryParentNameMap: $categoryParentNameMap');

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

      if (_isCombinedView && _categoryFilter != DashboardFilter.all) {
        final beforeFilter = processedList.length;
        processedList = processedList.where((account) {
          final isCard = account.cardBrand != null;
          final typeName = typeMap[account.typeId]?.toLowerCase() ?? '';
          final isRecebimento = typeName.contains('receb');
          final isPagar = !isCard && !isRecebimento;
          switch (_categoryFilter) {
            case DashboardFilter.pagar:
              return isPagar;
            case DashboardFilter.receber:
              return isRecebimento;
            case DashboardFilter.cartoes:
              return isCard;
            case DashboardFilter.all:
              return true;
          }
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
        // Calcular effectiveDate para ambos considerando redirecionamentos
        final aEffective = _resolveEffectiveDate(a, _startDate);
        final bEffective = _resolveEffectiveDate(b, _startDate);
        
        // Ordenar por effectiveDate (ano, mês, dia)
        final dateCompare = aEffective.compareTo(bEffective);
        if (dateCompare != 0) return dateCompare;
        
        // Tie-breaker: tipo (cartões primeiro, depois a pagar, depois a receber)
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
        final rankCompare = aRank.compareTo(bRank);
        if (rankCompare != 0) return rankCompare;
        
        // Tie-breaker final: ID
        return (a.id ?? 0).compareTo(b.id ?? 0);
      });
      
      final double totalForecast = processedList.fold(0.0, (sum, item) {
        if (item.cardBrand != null && item.isRecurrent) {
          final breakdown = CardBreakdown.parse(item.observation);
          return sum + breakdown.total;
        }
        return sum + item.value;
      });

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
          _categoryNames = categoryMap;
          _categoryLogos = categoryLogoMap;
          _categoryParentNames = categoryParentNameMap;
          _totalPeriod = totalPaid;
          _totalForecast = totalRemaining;
          _totalPrevistoPagar = previstoPagar;
          _totalPrevistoReceber = previstoReceber;
          _totalLancadoPagar = lancadoPagar;
          _totalLancadoReceber = lancadoReceber;
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
        final totalColor = widget.totalLabelOverride != null
          ? (isDark ? Colors.brown.shade200 : Colors.brown.shade700)
          : (_isRecebimentosFilter
            ? (isDark ? AppColors.primaryLight : AppColors.primary)
            : (isDark ? AppColors.errorLight : AppColors.error));
        final totalLabel = widget.totalLabelOverride ?? (_isRecebimentosFilter ? 'TOTAL RECEBIDO' : 'TOTAL PAGO');
        final emptyText = widget.emptyTextOverride ??
          (_isRecebimentosFilter
            ? 'Nenhuma conta a receber para este mês.'
            : 'Nenhuma conta a pagar para este mês.');
        final appBarBg = widget.appBarColorOverride ??
          (_isRecebimentosFilter ? AppColors.success : AppColors.error);
        const appBarFg = Colors.white;
      final isSingleDayFilter = DateUtils.isSameDay(_startDate, _endDate);
      final monthLabel = _formatMonthYear(_startDate);
      final PreferredSizeWidget? appBarWidget = isSingleDayFilter
          ? (SingleDayAppBar(
              date: _startDate,
              city: PrefsService.cityNotifier.value,
              backgroundColor: appBarBg,
              foregroundColor: appBarFg,
            ) as PreferredSizeWidget)
          : null;
      final dashboardBody = SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
              const headerPadding = EdgeInsets.symmetric(
                vertical: AppSpacing.xs,
                horizontal: AppSpacing.md,
              );

              final headerWidget = Padding(
                padding: headerPadding,
                child: isCombined
                    ? Row(
                        children: [
                          Expanded(
                            child: SummaryCard(
                              title: 'A RECEBER',
                              value: UtilBrasilFields.obterReal(_totalLancadoReceber),
                              forecast: UtilBrasilFields.obterReal(_totalPrevistoReceber),
                              statusColor: app_tokens.AppColors.success,
                              icon: Icons.trending_up_rounded,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: SummaryCard(
                              title: 'A PAGAR',
                              value: UtilBrasilFields.obterReal(_totalLancadoPagar),
                              forecast: UtilBrasilFields.obterReal(_totalPrevistoPagar),
                              statusColor: app_tokens.AppColors.error,
                              icon: Icons.trending_down_rounded,
                            ),
                          ),
                        ],
                      )
                    : SummaryCard(
                        title: totalLabel,
                        value: UtilBrasilFields.obterReal(_totalPeriod),
                        forecast: UtilBrasilFields.obterReal(_totalForecast),
                        statusColor: totalColor,
                        icon: _isRecebimentosFilter ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      ),
              );

              // Widget de indicação de seleção
              Widget? selectionBanner;
              if (_selectedConta.value != null) {
                final selectedAccount = _selectedConta.value;
                if (selectedAccount != null) {
                  final valueStr = UtilBrasilFields.obterReal(selectedAccount.value);
                  final categoryStr = _typeNames[selectedAccount.typeId] ?? 'Outro';
                  final descStr = selectedAccount.description.isNotEmpty 
                      ? selectedAccount.description 
                      : 'Sem descrição';
                  final bool isPaid = selectedAccount.id != null && _paymentInfo.containsKey(selectedAccount.id!);
                  final bool isCard = selectedAccount.cardBrand != null;
                  final bool isCardInvoice = isCard && selectedAccount.recurrenceId != null;
                  final bool isRecebimento = _isRecebimentosFilter || (_typeNames[selectedAccount.typeId]?.toLowerCase().contains('receb') ?? false);
                  final colorScheme = Theme.of(context).colorScheme;
                  final bool isNarrow = media.size.width < 600;
                  final bool canPay = !isPaid;
                  String? launchLabel;
                  VoidCallback? onLaunch;

                  if (isCard) {
                    if (!isCardInvoice) {
                      launchLabel = 'Lançar fatura';
                      onLaunch = () => _showCartaoValueDialog(selectedAccount);
                    }
                  } else if (isRecebimento) {
                    launchLabel = 'Lançar recebimento';
                    onLaunch = () => _showRecebimentoValueDialog(selectedAccount);
                  } else if (selectedAccount.isRecurrent && selectedAccount.recurrenceId == null) {
                    launchLabel = 'Lançar despesa';
                    onLaunch = () async {
                      Account parentRecurrence = selectedAccount;
                      if (selectedAccount.recurrenceId != null) {
                        final parentId = selectedAccount.recurrenceId!;
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
                    };
                  } else if (selectedAccount.isRecurrent &&
                      selectedAccount.recurrenceId != null &&
                      selectedAccount.value == 0) {
                    launchLabel = 'Lançar despesa';
                    onLaunch = () => _showDespesaValueDialog(selectedAccount);
                  }

                  final String payLabel = isCard
                      ? 'Pagar fatura'
                      : (isRecebimento ? 'Receber' : 'Pagar');
                  
                  selectionBanner = Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    child: ActionBanner(
                      leadingIcon: isCard ? Icons.credit_card : Icons.info_outline,
                      text: '$categoryStr – $descStr – $valueStr',
                      actions: [
                        if (isCard)
                          Tooltip(
                            message: 'Nova despesa',
                            child: IconButton(
                              onPressed: () => _showExpenseDialog(selectedAccount),
                              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                              icon: Icon(Icons.add_shopping_cart, color: colorScheme.primary),
                            ),
                          ),
                        if (onLaunch != null)
                          Tooltip(
                            message: launchLabel ?? 'Lançar',
                            child: IconButton(
                              onPressed: onLaunch,
                              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                              icon: Icon(Icons.rocket_launch, color: colorScheme.primary),
                            ),
                          ),
                        if (canPay)
                          Tooltip(
                            message: payLabel,
                            child: IconButton(
                              onPressed: () => _handlePayAction(selectedAccount),
                              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                              icon: Icon(
                                isRecebimento ? Icons.trending_up : Icons.attach_money,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        if (isNarrow)
                          PopupMenuButton<String>(
                            tooltip: 'Mais ações',
                            icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
                            onSelected: (value) async {
                              switch (value) {
                                case 'edit':
                                  if (isCard) {
                                    await _openCardEditor(selectedAccount);
                                  } else {
                                    await _showEditSpecificDialog(selectedAccount);
                                  }
                                  break;
                                case 'delete':
                                  _confirmDelete(selectedAccount);
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Text('Editar')),
                              const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                            ],
                          )
                        else ...[
                          Tooltip(
                            message: 'Editar',
                            child: IconButton(
                              onPressed: () async {
                                if (isCard) {
                                  await _openCardEditor(selectedAccount);
                                } else {
                                  await _showEditSpecificDialog(selectedAccount);
                                }
                              },
                              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                              icon: Icon(Icons.edit, color: colorScheme.onSurfaceVariant),
                            ),
                          ),
                          Tooltip(
                            message: 'Excluir',
                            child: IconButton(
                              onPressed: () => _confirmDelete(selectedAccount),
                              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                              icon: Icon(
                                Icons.delete_outline,
                                color: colorScheme.error.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ],
                        IconButton(
                          tooltip: 'Fechar',
                          onPressed: () => setState(() => _selectedConta.value = null),
                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }
              }

              // Fixed header section (FIG1) - NEVER scrolls
              final fixedHeader = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pageStack.isEmpty && !isSingleDayFilter)
                    _buildMonthNavBar(monthLabel),
                  if (_pageStack.isEmpty) _buildTopControlsBar(),
                  headerWidget,
                  if (selectionBanner != null) selectionBanner,
                ],
              );

              // Scrollable content - ONLY this scrolls
              final scrollableContent = _isLoading
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
                      : NotificationListener<UserScrollNotification>(
                          onNotification: _handleScrollNotification,
                          child: Scrollbar(
                            controller: _listScrollController,
                            thumbVisibility: true,
                            interactive: true,
                            child: ListView.builder(
                              controller: _listScrollController,
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: ClampingScrollPhysics(),
                              ),
                              primary: false,
                              shrinkWrap: false,
                              padding: const EdgeInsets.fromLTRB(0, 8, 0, 110),
                              itemCount: _displayList.length,
                              itemBuilder: (context, index) {
                                    try {
                                      final account = _displayList[index];
                                      final colorScheme = Theme.of(context).colorScheme;

                                      // Usar effectiveDate (após redirecionamentos) para agrupamento
                                      final currentEffectiveDate = _resolveEffectiveDate(account, _startDate);

                                      // Verificar se é o primeiro item ou se a data mudou
                                      bool showDateSeparator = index == 0;
                                      if (index > 0) {
                                        final prevAccount = _displayList[index - 1];
                                        final prevEffectiveDate = _resolveEffectiveDate(prevAccount, _startDate);
                                        showDateSeparator = !DateUtils.isSameDay(currentEffectiveDate, prevEffectiveDate);
                                      }

                                      // Contar itens com a mesma data efetiva
                                      int itemCount = 0;
                                      if (showDateSeparator) {
                                        for (int i = index; i < _displayList.length; i++) {
                                          final itemDate = _resolveEffectiveDate(_displayList[i], _startDate);
                                          if (DateUtils.isSameDay(itemDate, currentEffectiveDate)) {
                                            itemCount++;
                                          } else {
                                            break;
                                          }
                                        }
                                      }

                                      // Formato padronizado: dd/MM/yyyy • DIA_SEMANA
                                      final dateLabel = DateFormat('dd/MM/yyyy').format(currentEffectiveDate);
                                      final dayOfWeek = DateFormat('EEEE', 'pt_BR').format(currentEffectiveDate).toUpperCase();

                                      return Column(
                                        children: [
                                          if (showDateSeparator)
                                            SectionHeader(
                                              icon: Icons.calendar_today,
                                              title: '$dateLabel • $dayOfWeek',
                                              trailing: MiniChip(
                                                label: itemCount == 1 ? '1 item' : '$itemCount itens',
                                                backgroundColor: colorScheme.surfaceContainerHighest,
                                                textColor: colorScheme.onSurfaceVariant,
                                                borderColor: colorScheme.outlineVariant.withValues(alpha: 0.6),
                                              ),
                                            ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
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
                              ),
                            );

              // Return Column with fixed header + scrollable content in Expanded
              return Column(
                children: [
                  fixedHeader,
                  Expanded(child: scrollableContent),
                ],
              );
          },
        ),
      );

      return Scaffold(
        appBar: _pageStack.isNotEmpty ? null : appBarWidget,
        body: _pageStack.isNotEmpty
            ? _pageStack.last
            : dashboardBody,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
        floatingActionButton: _pageStack.isNotEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(right: fabRight, bottom: fabBottom),
                  child: AnimatedSlide(
                    offset: _isFabVisible ? Offset.zero : const Offset(0, 0.2),
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
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          centerTitle: true,
          title: Text(
            DateFormat('MMMM yyyy', 'pt_BR').format(_startDate).toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
    final String? typeName = _typeNames[account.typeId]?.toLowerCase();
    bool isCard = account.cardBrand != null || (typeName?.contains('cart') ?? false);
    bool isRecurrent = account.isRecurrent || account.recurrenceId != null;
    final bool isRecebimento = _isRecebimentosFilter || (typeName != null && typeName.contains('receb'));
    final colorScheme = Theme.of(context).colorScheme;
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
    // Nome da categoria direta da conta
    final rawCategory = (account.categoryId != null)
        ? _categoryNames[account.categoryId!]
        : null;

    // Tratar formato especial de Recebimentos: "Parent||Child"
    final bool hasRecebimentosSeparator = rawCategory?.contains('||') ?? false;
    String? parsedParentName;
    String? parsedChildName;
    if (hasRecebimentosSeparator && rawCategory != null) {
      final parts = rawCategory.split('||');
      if (parts.length >= 2) {
        parsedParentName = parts[0].trim(); // Ex: "Aposentadoria/Benefícios"
        parsedChildName = parts[1].trim();  // Ex: "INSS"
      }
    }

    // Descobrir categoria pai:
    // 1. Se tem formato "||", usar parsedParentName
    // 2. Senão, usar _categoryParentNames (mapeamento por nome)
    final String? parentCategoryName = hasRecebimentosSeparator
        ? parsedParentName
        : ((account.categoryId != null) ? _categoryParentNames[account.categoryId!] : null);
    final bool hasParent = parentCategoryName != null;

    // Nome da categoria filha:
    // 1. Se tem formato "||", usar parsedChildName
    // 2. Senão, usar rawCategory
    final String? childCategoryName = hasRecebimentosSeparator
        ? parsedChildName
        : rawCategory;

    // Logo da categoria pai (do serviço estático)
    String? parentCategoryLogo;
    if (hasParent) {
      // Primeiro tenta o mapa principal de categorias
      parentCategoryLogo = DefaultAccountCategoriesService.categoryLogos[parentCategoryName];
      // Se não encontrou e é Recebimentos, tenta o mapa de subcategorias pai de Recebimentos
      if (parentCategoryLogo == null && hasRecebimentosSeparator) {
        parentCategoryLogo = DefaultAccountCategoriesService.getLogoForRecebimentosPai(parentCategoryName);
      }
    }

    // Logo da categoria filha (do mapa _categoryLogos ou do serviço)
    String? childCategoryLogo = (account.categoryId != null)
        ? _categoryLogos[account.categoryId!]
        : null;
    // Se não tem logo no mapa e é Recebimentos com formato "||", buscar do serviço
    if (childCategoryLogo == null && hasRecebimentosSeparator && parsedParentName != null && parsedChildName != null) {
      childCategoryLogo = DefaultAccountCategoriesService.getLogoForRecebimentosFilho(parsedParentName, parsedChildName);
    }

    // Fallback para TIPO quando categoria não tem pai nos defaults
    final String? typeDisplayName = _typeNames[account.typeId]; // Nome original (case-sensitive)
    final String? typeEmoji = (typeDisplayName != null)
        ? DefaultAccountCategoriesService.categoryLogos[typeDisplayName]
        : null;

    // Título: prioridade: 1) pai da categoria, 2) parsedParentName (||), 3) nome do TIPO
    final String? categoryParentForTitle = hasParent
        ? parentCategoryName
        : (hasRecebimentosSeparator ? parsedParentName : typeDisplayName);

    // Determinar emojis para título e subtítulo
    String? titleEmoji;
    if (hasParent && parentCategoryLogo != null) {
      // Tem pai com logo definido
      titleEmoji = parentCategoryLogo;
    } else if (hasRecebimentosSeparator && parentCategoryLogo != null) {
      // Formato "||" com logo do pai
      titleEmoji = parentCategoryLogo;
    } else if (!hasParent && !hasRecebimentosSeparator && typeEmoji != null) {
      // Sem pai, usar emoji do TIPO
      titleEmoji = typeEmoji;
    } else if (isCard) {
      titleEmoji = '💳';
    }

    // subtitleEmoji: emoji da categoria/filho
    String? subtitleEmoji;
    if (account.logo?.trim().isNotEmpty == true) {
      subtitleEmoji = account.logo!.trim();
    } else if (childCategoryLogo != null) {
      // Mostra logo da categoria
      subtitleEmoji = childCategoryLogo;
    } else if (isCard) {
      subtitleEmoji = '💳';
    }
    debugPrint('🔍 Account: ${account.description}, parentName: $parentCategoryName, typeName: $typeDisplayName, childName: $childCategoryName, titleEmoji: $titleEmoji, subtitleEmoji: $subtitleEmoji');

    // Nome da categoria filha para exibição (sem "||")
    final sanitizedCategoryChild = (childCategoryName ?? rawCategory)
        ?.replaceAll(RegExp(r'^Fatura:\s*'), '').trim();
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
            ? '$cardBankLabel • $cardBrandLabel'
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
    final bool isPaid =
        account.id != null && _paymentInfo.containsKey(account.id!);

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
    
    final installmentDisplay = resolveInstallmentDisplay(account);
    final Color parceladoFillColor =
        isRecebimento ? Colors.green.shade600 : Colors.red.shade600;
    // Identificar se é parcela única (não recorrente, não parcelada, total == 1)
    final bool isSinglePayment = !hasRecurrence && !installmentDisplay.isInstallment && !isCard;
    // Badge de parcelamento - único chip colorido (status)
    final Widget installmentBadge = MiniChip(
      label: installmentDisplay.labelText,
      textColor: parceladoFillColor,
    );
    // Badge para parcela única (chip informativo neutro)
    final Widget singlePaymentBadge = const MiniChip(label: 'Parcela única');

    final List<Widget> chips = [];
    // Chips sem redundância: não repetir título/subtítulo
    // Título = categoryParentForTitle ?? accountTypeName, Subtítulo = middleLineText
    final String? accountTypeName = _typeNames[account.typeId];
    final bool titleIsAccountType = categoryParentForTitle == null;
    // Tipo: só adicionar se categoryParentForTitle existe (título não é accountTypeName)
    if (accountTypeName != null && accountTypeName.isNotEmpty && !titleIsAccountType) {
      chips.add(MiniChip(
        label: accountTypeName,
        backgroundColor: colorScheme.surfaceContainerHighest,
        textColor: colorScheme.onSurfaceVariant,
        borderColor: colorScheme.outlineVariant.withValues(alpha: 0.6),
      ));
    }
    // Categoria: só adicionar se não está no subtítulo
    final bool categoryInSubtitle = sanitizedCategoryChild != null &&
        (middleLineText == sanitizedCategoryChild ||
         middleLineText.toLowerCase().contains(sanitizedCategoryChild.toLowerCase()));
    if (sanitizedCategoryChild != null && sanitizedCategoryChild.isNotEmpty && !categoryInSubtitle) {
      chips.add(MiniChip(
        label: sanitizedCategoryChild,
        backgroundColor: colorScheme.surfaceContainerHighest,
        textColor: colorScheme.onSurfaceVariant,
        borderColor: colorScheme.outlineVariant.withValues(alpha: 0.6),
      ));
    }
    // State chips: prioridade após tipo e categoria
    final List<Widget> stateChips = [];
    if (isPaid) {
      stateChips.add(MiniChip(
        label: _isRecebimentosFilter ? 'Recebido' : 'Pago',
        icon: Icons.check_circle,
        iconColor: app_tokens.AppColors.textSecondary,
      ));
    }
    if (isSinglePayment) {
      stateChips.add(singlePaymentBadge);
    }
    if (hasRecurrence && !isCard) {
      stateChips.add(const MiniChip(label: 'Recorrência'));
    }
    if (installmentDisplay.isInstallment) {
      stateChips.add(installmentBadge);
    }
    if (showPrevisto) {
      stateChips.add(MiniChip(label: 'Previsto: $previstoDisplay'));
    }
    if (isCard) {
      stateChips.add(MiniChip(label: 'Próx.: $cardNextDueLabel'));
    }
    // Limitar a 3 chips no total (tipo → categoria → estado)
    final int remaining = 3 - chips.length;
    if (remaining > 0) {
      chips.addAll(stateChips.take(remaining));
    }

    final bool canLaunchPayment = !isPaid;
    final List<_MenuAction> menuActions = [
      _MenuAction(
        label: 'Editar',
        icon: Icons.edit,
        onTap: () => isCard ? _openCardEditor(account) : _showEditSpecificDialog(account),
      ),
    ];

    if (isCard) {
      menuActions.add(_MenuAction(
        label: 'Pagar fatura',
        icon: Icons.attach_money,
        onTap: canLaunchPayment ? () => _handlePayAction(account) : null,
      ));
    } else {
      menuActions.add(_MenuAction(
        label: isRecebimento ? 'Receber' : 'Pagar',
        icon: Icons.attach_money,
        onTap: canLaunchPayment ? () => _handlePayAction(account) : null,
      ));
    }

    if (account.id != null) {
      menuActions.add(_MenuAction(
        label: 'Excluir',
        icon: Icons.delete_outline,
        onTap: () => _confirmDelete(account),
      ));
    }

    if (isCard) {
      // Nova despesa fica no ActionBanner quando houver seleção
    }

    if (isPaid) {
      menuActions.add(_MenuAction(
        label: 'Desfazer pagamento',
        icon: Icons.undo,
        onTap: () => _undoPayment(account),
      ));
    }

    final Color accentColor = isRecebimento
        ? app_tokens.AppColors.success
        : (isCard ? app_tokens.AppColors.primary : app_tokens.AppColors.error);
    final Color valueColor = accentColor;

    final selectedId = _selectedConta.value?.id;
    final bool isSelected = account.id != null && selectedId == account.id;

    final Color borderColor = isSelected
        ? colorScheme.primary.withValues(alpha: 0.5)
        : colorScheme.outlineVariant.withValues(alpha: 0.6);
    final Color baseTint = Color.alphaBlend(
      accentColor.withValues(alpha: 0.04),
      colorScheme.surface,
    );
    final Color effectiveCardColor = isSelected
        ? Color.alphaBlend(
            colorScheme.primary.withValues(alpha: 0.04),
            baseTint,
          )
        : baseTint;
    final List<BoxShadow> boxShadows = [
      const BoxShadow(
        color: Colors.transparent,
        blurRadius: 0,
        offset: Offset(0, 0),
      ),
    ];

    final String dayLabel = effectiveDate.day.toString().padLeft(2, '0');
    final String weekdayLabel = DateFormat('EEE', 'pt_BR')
        .format(effectiveDate)
        .replaceAll('.', '')
        .toUpperCase();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Opacity(
        opacity: isPaid ? 0.6 : 1.0,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: sp(4), horizontal: sp(8)),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                if (isCard) {
                  await _openCardExpenses(account, selectedDate: effectiveDate);
                } else {
                  await _showEditSpecificDialog(account);
                }
              },
              onLongPress: () {
                if (isSelected) {
                  setState(() => _selectedConta.value = null);
                } else {
                  setState(() => _selectedConta.value = account);
                }
              },
              splashColor: app_tokens.AppColors.primary.withValues(alpha: 0.08),
              highlightColor: app_tokens.AppColors.primary.withValues(alpha: 0.04),
              child: EntryCard(
                datePill: DatePill(
                  day: dayLabel,
                  weekday: weekdayLabel,
                  accentColor: accentColor,
                ),
                titleEmoji: titleEmoji,
                subtitleEmoji: subtitleEmoji,
                subtitleIcon: isCard ? _buildCardBrandIcon(account.cardBrand) : null,
                title: categoryParentForTitle ?? _typeNames[account.typeId] ?? 'Outro',
                subtitle: middleLineText,
                value: lancadoDisplay,
                valueColor: valueColor,
                chips: chips,
                accentColor: accentColor,
                trailing: _buildActionButtons(
                  menuActions: menuActions,
                  scale: scale,
                ),
                backgroundColor: effectiveCardColor,
                borderColor: borderColor,
                boxShadow: boxShadows,
                padding: const EdgeInsets.all(AppSpacing.lg),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons({
    required List<_MenuAction> menuActions,
    required double scale,
  }) {
    double sp(double value) => value * scale;
    final double buttonSize = sp(48);
    final double iconSize = sp(20);
    Offset? tapPosition;
    final Color iconColor = Theme.of(context).colorScheme.onSurfaceVariant;

    if (menuActions.isEmpty) {
      return const SizedBox.shrink();
    }

    final editAction = menuActions.firstWhere(
      (action) => action.label == 'Editar',
      orElse: () => const _MenuAction(label: '', icon: Icons.more_vert),
    );
    final otherActions = menuActions
        .where((action) => action.label != 'Editar' && action.onTap != null)
        .toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (editAction.onTap != null)
          SizedBox(
            width: buttonSize,
            height: buttonSize,
            child: IconButton(
              onPressed: editAction.onTap,
              iconSize: iconSize,
              padding: EdgeInsets.zero,
              icon: Icon(editAction.icon, color: iconColor),
            ),
          ),
        if (otherActions.isNotEmpty) ...[
          SizedBox(width: sp(6)),
          SizedBox(
            width: buttonSize,
            height: buttonSize,
            child: Builder(
              builder: (context) => GestureDetector(
                onTapDown: (details) => tapPosition = details.globalPosition,
                child: IconButton(
                  onPressed: () async {
                    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
                    final position = tapPosition ?? const Offset(0, 0);
                    final selected = await showMenu<int>(
                      context: context,
                      position: RelativeRect.fromRect(
                        Rect.fromPoints(position, position),
                        Offset.zero & overlay.size,
                      ),
                      items: [
                        for (int i = 0; i < otherActions.length; i++)
                          PopupMenuItem<int>(
                            value: i,
                            child: Row(
                              children: [
                                Icon(otherActions[i].icon, size: 18, color: iconColor),
                                const SizedBox(width: 8),
                                Text(otherActions[i].label),
                              ],
                            ),
                          ),
                      ],
                    );
                    if (selected != null) {
                      otherActions[selected].onTap?.call();
                    }
                  },
                  iconSize: iconSize,
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.more_vert, color: iconColor),
                ),
              ),
            ),
          ),
        ],
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

  /// Constrói o ícone da bandeira do cartão para uso no EntryCard (tamanho pequeno)
  Widget? _buildCardBrandIcon(String? brand) {
    final normalized = (brand ?? '').trim().toUpperCase();
    if (normalized.isEmpty) return null;

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
        fit: BoxFit.contain,
      );
    }

    return null;
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

  Future<void> _openCardExpenses(Account account, {DateTime? selectedDate}) async {
    if (_isNavigating) return;
    _isNavigating = true;

    final int targetMonth = account.month ?? _startDate.month;
    final int targetYear = account.year ?? _startDate.year;
    Account resolvedCard = account;
    final int? resolvedCardId = account.recurrenceId ?? account.cardId;
    if (resolvedCardId != null && resolvedCardId != account.id) {
      try {
        final cards = await DatabaseHelper.instance.readAllCards();
        resolvedCard = cards.firstWhere(
          (card) => card.id == resolvedCardId,
          orElse: () => account,
        );
      } catch (_) {
        resolvedCard = account;
      }
    }

    // Use pageStack navigation to keep header fixed
    _pushPage(CardExpensesScreen(
      card: resolvedCard,
      month: targetMonth,
      year: targetYear,
      selectedDate: selectedDate,
      inline: true,
      onClose: _popPage,
    ));
    _isNavigating = false;
  }

  /// Push a page onto the internal navigation stack
  void _pushPage(Widget page) {
    setState(() {
      _pageStack.add(page);
    });
  }

  /// Pop the top page from the internal navigation stack
  void _popPage() {
    if (_pageStack.isEmpty) return;
    setState(() {
      _pageStack.removeLast();
    });
    _refresh();
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

  Future<void> _showEditSpecificDialog(Account account) async {
    if (_isNavigating) return;
    _isNavigating = true;

    // Determinar se a conta editada é recebimento pelo tipo da conta
    final isRecebimento = _isRecebimentoAccount(account);

    // Usar AccountFormScreen para todos os tipos de conta, passando isRecebimento corretamente
    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => AccountEditDialog(
        accountToEdit: account,
        isRecebimento: isRecebimento,
      ),
    );
    _isNavigating = false;
    if (mounted) _refresh();
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
      isScrollControlled: false,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final colorScheme = Theme.of(context).colorScheme;
            final maxWidth = constraints.maxWidth;
            final crossAxisCount = maxWidth < 600 ? 2 : 4;
            const spacing = 12.0;

            final items = <_QuickActionItem>[
              _QuickActionItem(
                icon: Icons.receipt_long,
                label: 'Pagar',
                accent: colorScheme.error,
                onTap: () async {
                  Navigator.pop(ctx);
                  await showDialog(
                    context: context,
                    builder: (dialogContext) => StandardModalShell(
                      title: 'Nova Conta a Pagar',
                      onClose: () => Navigator.pop(dialogContext),
                      maxWidth: 700,
                      maxHeight: 850,
                      scrollBody: false,
                      bodyPadding: EdgeInsets.zero,
                      body: const AccountFormScreen(showAppBar: false),
                    ),
                  );
                  _refresh();
                },
              ),
              _QuickActionItem(
                icon: Icons.account_balance_wallet,
                label: 'Receber',
                accent: Colors.green.shade700,
                onTap: () {
                  Navigator.pop(ctx);
                  _openRecebimentoForm();
                },
              ),
              _QuickActionItem(
                icon: Icons.credit_card,
                label: 'Desp. Cartão',
                accent: colorScheme.primary,
                onTap: () {
                  Navigator.pop(ctx);
                  _startCardExpenseFlow();
                },
              ),
              _QuickActionItem(
                icon: Icons.add_card,
                label: 'Novo Cartão',
                accent: colorScheme.secondary,
                onTap: () async {
                  Navigator.pop(ctx);
                  await showDialog(
                    context: context,
                    builder: (_) => const CreditCardFormScreen(),
                  );
                  _refresh();
                },
              ),
            ];

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Novo lançamento',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Escolha o tipo',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                      childAspectRatio: maxWidth < 600 ? 1.05 : 1.1,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildQuickActionTile(item);
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuickActionTile(_QuickActionItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: item.accent.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.icon, size: 22, color: item.accent),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                  ),
                ],
              ),
            ],
          ),
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
