import 'package:flutter/material.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../models/account_category.dart';
import '../models/account_type.dart';
import '../services/prefs_service.dart';
import '../services/holiday_service.dart';
import '../utils/color_contrast.dart';
import '../utils/installment_utils.dart';
import '../widgets/new_expense_dialog.dart';

class CardExpensesScreen extends StatefulWidget {
  final Account card; 
  final int month;
  final int year;
  final bool inline;
  final VoidCallback? onClose;
  const CardExpensesScreen({
    super.key,
    required this.card,
    required this.month,
    required this.year,
    this.inline = false,
    this.onClose,
  });
  @override
  State<CardExpensesScreen> createState() => _CardExpensesScreenState();
}

class _CardExpensesScreenState extends State<CardExpensesScreen> {
  late int _currentMonth;
  late int _currentYear;
  List<Account> _expenses = [];
  double _invoiceLaunchedTotal = 0;
  Map<int, AccountType> _typeById = {};
  Map<int, AccountCategory> _categoryById = {};
  bool _isLoading = true;
  Map<int, InstallmentDisplay> _installmentById = {};
  final Set<String> _activeFilters = {};
  late final VoidCallback _dateRangeListener;
  bool _isFabVisible = true;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.month;
    _currentYear = widget.year;
    _dateRangeListener = () {
      final range = PrefsService.dateRangeNotifier.value;
      final month = range.start.month;
      final year = range.start.year;
      if (month == _currentMonth && year == _currentYear) return;
      setState(() {
        _currentMonth = month;
        _currentYear = year;
      });
      _loadExpenses();
    };
    PrefsService.dateRangeNotifier.addListener(_dateRangeListener);
    _loadExpenses();
  }

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

  Future<void> _openNewExpense() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NewExpenseDialog(card: widget.card),
    );
    if (result == true && mounted) {
      await _loadExpenses();
    }
  }

  bool _isParcel(Account expense) {
    if (expense.isRecurrent) return false;
    final display = _installmentDisplayFor(expense);
    return display.isInstallment;
  }

  InstallmentDisplay _installmentDisplayFor(Account expense) {
    final display = resolveInstallmentDisplay(expense);
    if (!display.isInstallment && expense.id != null) {
      final fallback = _installmentById[expense.id!];
      if (fallback != null) return fallback;
    }
    return display;
  }


  DateTime? _getAdjustedDueDate() {
    try {
      DateTime adjusted = DateTime(_currentYear, _currentMonth, widget.card.dueDay);
      final String city = PrefsService.cityNotifier.value;
      while (HolidayService.isWeekend(adjusted) || HolidayService.isHoliday(adjusted, city)) {
        adjusted = adjusted.add(Duration(days: widget.card.payInAdvance ? -1 : 1));
      }
      return adjusted;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    if (widget.card.id == null) {
      if (!mounted) return;
      setState(() {
        _expenses = [];
        _invoiceLaunchedTotal = 0;
        _typeById = {};
        _categoryById = {};
        _installmentById = {};
        _isLoading = false;
      });
      return;
    }

    try {
      final expenses = await DatabaseHelper.instance.getCardExpensesForMonth(widget.card.id!, _currentMonth, _currentYear);
      final db = await DatabaseHelper.instance.database;
      final recurringRes = await db.query('accounts', where: 'cardId = ? AND isRecurrent = 1', whereArgs: [widget.card.id]);
      List<Account> subscriptions = recurringRes.map((e) => Account.fromMap(e)).toList();

      double invoiceLaunchedTotal = 0;
      final invoiceRows = await db.query(
        'accounts',
        where: 'recurrenceId = ? AND month = ? AND year = ? AND isRecurrent = 0 AND description LIKE ?',
        whereArgs: [widget.card.id, _currentMonth, _currentYear, 'Fatura:%'],
      );
      for (final row in invoiceRows) {
        final acc = Account.fromMap(row);
        invoiceLaunchedTotal += acc.value;
      }

    List<Account> displayList = [...expenses];

    // Criar set de recurrenceIds para busca O(1) em vez de O(n)
    final launchedRecurrenceIds = <int?>{};
    for (var exp in expenses) {
      if (exp.recurrenceId != null) {
        launchedRecurrenceIds.add(exp.recurrenceId);
      }
    }

    for (var sub in subscriptions) {
      bool alreadyLaunched = launchedRecurrenceIds.contains(sub.id);
      if (!alreadyLaunched) {
        bool show = true;
        if (sub.year != null && sub.month != null) {
           int subStart = sub.year! * 12 + sub.month!;
           int currentView = _currentYear * 12 + _currentMonth;
           if (currentView < subStart) show = false;
        }
        if (show) {
          displayList.add(Account(id: sub.id, typeId: sub.typeId, categoryId: sub.categoryId, description: sub.description, value: sub.value, dueDay: widget.card.dueDay, month: _currentMonth, year: _currentYear, isRecurrent: true, payInAdvance: sub.payInAdvance, cardId: sub.cardId, observation: sub.observation, recurrenceId: sub.id, purchaseDate: sub.purchaseDate, creationDate: sub.creationDate));
        }
      }
    }
    displayList.sort((a, b) => a.dueDay.compareTo(b.dueDay));
    final Map<int, InstallmentDisplay> installmentMap = {};

    final List<Map<String, Object?>> byUuidRows = await db.query('accounts', where: 'purchaseUuid IS NOT NULL');
    final Map<String, List<Account>> groupedUuid = {};
    for (final row in byUuidRows) {
      final acc = Account.fromMap(row);
      if (acc.purchaseUuid == null) continue;
      groupedUuid.putIfAbsent(acc.purchaseUuid!, () => []).add(acc);
    }
    groupedUuid.forEach((uuid, list) {
      if (list.length <= 1) return;
      list.sort((a, b) {
        int byYear = (a.year ?? 0).compareTo(b.year ?? 0);
        if (byYear != 0) return byYear;
        int byMonth = (a.month ?? 0).compareTo(b.month ?? 0);
        if (byMonth != 0) return byMonth;
        int byDay = a.dueDay.compareTo(b.dueDay);
        if (byDay != 0) return byDay;
        return (a.id ?? 0).compareTo(b.id ?? 0);
      });
      for (int i = 0; i < list.length; i++) {
        if (list[i].id != null) {
          installmentMap[list[i].id!] = InstallmentDisplay(index: i + 1, total: list.length);
        }
      }
    });

      final neededTypeIds = displayList.map((e) => e.typeId).toSet();
      final neededCategoryIds = displayList
          .map((e) => e.categoryId)
          .whereType<int>()
          .toSet();
      final Map<int, AccountType> typeMap = {};
      final Map<int, AccountCategory> categoryMap = {};

      if (neededTypeIds.isNotEmpty) {
        final types = await DatabaseHelper.instance.readAllTypes();
        for (final t in types) {
          if (t.id != null && neededTypeIds.contains(t.id)) {
            typeMap[t.id!] = t;
          }
        }
        for (final typeId in neededTypeIds) {
          final cats = await DatabaseHelper.instance.readAccountCategories(typeId);
          for (final cat in cats) {
            if (cat.id != null && (neededCategoryIds.isEmpty || neededCategoryIds.contains(cat.id))) {
              categoryMap[cat.id!] = cat;
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _expenses = displayList;
        _invoiceLaunchedTotal = invoiceLaunchedTotal;
        _typeById = typeMap;
        _categoryById = categoryMap;
        _installmentById = installmentMap;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('🔧 CardExpensesScreen: erro ao carregar despesas: $e');
      if (!mounted) return;
      setState(() {
        _expenses = [];
        _invoiceLaunchedTotal = 0;
        _typeById = {};
        _categoryById = {};
        _installmentById = {};
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final headerRow = _buildCardHeaderRow(context);
    final body = Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          if (widget.inline && widget.onClose != null) {
            widget.onClose!();
          } else {
            Navigator.of(context).maybePop();
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          if (widget.inline)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 6),
              child: headerRow,
            )
          else ...[
            _buildSharedMonthHeader(),
            headerRow,
          ],
          _buildSummaryStrip(),
          const SizedBox(height: 2),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _visibleExpenses.isEmpty
                    ? const Center(child: Text('Nenhuma despesa nesta fatura.'))
                    : NotificationListener<ScrollNotification>(
                        onNotification: _handleScrollNotification,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          itemCount: _visibleExpenses.length,
                          itemBuilder: (context, index) {
                            return _buildExpenseItem(_visibleExpenses[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );

    if (widget.inline) {
      final size = MediaQuery.of(context).size;
      return Stack(
        children: [
          SizedBox(
            width: size.width,
            height: size.height,
            child: body,
          ),
          Positioned(
            right: 32,
            bottom: 64,
            child: AnimatedScale(
              scale: _isFabVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: AnimatedOpacity(
                opacity: _isFabVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Material(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 4,
                  child: InkWell(
                    onTap: _isFabVisible ? _openNewExpense : null,
                    borderRadius: BorderRadius.circular(12),
                    child: const SizedBox(
                      width: 70,
                      height: 70,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.credit_card, color: Colors.white, size: 24),
                          SizedBox(height: 4),
                          Text(
                            'Lançar\nDespesa',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      floatingActionButton: AnimatedScale(
        scale: _isFabVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: AnimatedOpacity(
          opacity: _isFabVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: FloatingActionButton.extended(
            heroTag: 'fabNewCardExpense',
            onPressed: _isFabVisible ? _openNewExpense : null,
            backgroundColor: Colors.deepPurple,
            icon: const Icon(Icons.rocket_launch),
            label: const Text('Lançar despesa'),
          ),
        ),
      ),
      body: body,
    );
  }

  Widget _buildSharedMonthHeader() {
    final range = PrefsService.dateRangeNotifier.value;
    final headerColor = Theme.of(context).colorScheme.primary;
    final headerTextColor = Theme.of(context).colorScheme.onPrimary;
    final monthLabel = DateFormat('MMMM yyyy', 'pt_BR').format(range.start).toUpperCase();

    return Container(
      color: headerColor,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        children: [
          const SizedBox(width: 48),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: headerTextColor),
                  onPressed: () => PrefsService.shiftDateRange(-1),
                  tooltip: 'Mês anterior',
                ),
                Text(
                  monthLabel,
                  style: TextStyle(
                    color: headerTextColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: headerTextColor),
                  onPressed: () => PrefsService.shiftDateRange(1),
                  tooltip: 'Próximo mês',
                ),
              ],
            ),
          ),
          const SizedBox(width: 48), // Espaço para balancear o layout
        ],
      ),
    );
  }

  Widget _buildCardHeaderRow(BuildContext context) {
    final brand = widget.card.cardBrand?.trim() ?? '';
    final cardName = widget.card.description.trim().isNotEmpty
        ? widget.card.description.trim()
        : 'Cartão de Crédito';
    final cardDescription = (widget.card.cardBank?.trim().isNotEmpty == true)
        ? widget.card.cardBank!.trim()
        : cardName;

    final Color headerBg = widget.card.cardColor != null
        ? Color(widget.card.cardColor!)
        : Theme.of(context).cardColor;
    final Color headerFg = foregroundColorFor(headerBg);
    final Color headerSubtle = headerFg.withValues(alpha: 0.75);

    double totalPrevisto = 0;
    for (final e in _expenses) {
      totalPrevisto += e.value;
    }
    final double totalLancado = _invoiceLaunchedTotal;

    Widget buildTotalAPagarCard(double lancado, double previsto) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.red.shade500,
              Colors.red.shade800,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.red.shade400.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.credit_card,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'TOTAL A PAGAR',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                UtilBrasilFields.obterReal(lancado),
                style: const TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Previsto: ${UtilBrasilFields.obterReal(previsto)}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 0, bottom: 0, left: 12, right: 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Seta de voltar
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () {
                if (widget.inline && widget.onClose != null) {
                  widget.onClose!();
                } else {
                  Navigator.of(context).maybePop();
                }
              },
              tooltip: 'Voltar',
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: headerBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.card.dueDay.toString().padLeft(2, '0'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: (Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) * 1.45,
                              fontWeight: FontWeight.w800,
                              color: headerFg,
                            ),
                      ),
                      const SizedBox(width: 8),
                      _buildCardBrandIcon(brand),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              brand.isNotEmpty ? brand : cardName,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: headerFg,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              cardDescription,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: headerSubtle),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: buildTotalAPagarCard(totalLancado, totalPrevisto)),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBrandIcon(String brand) {
    final normalized = brand.trim().toUpperCase();
    String? assetPath;
    if (normalized == 'VISA') {
      assetPath = 'assets/icons/cc_visa.png';
    } else if (normalized == 'AMEX' ||
        normalized == 'AMERICAN EXPRESS' ||
        normalized == 'AMERICANEXPRESS') {
      assetPath = 'assets/icons/cc_amex.png';
    } else if (normalized == 'MASTER' ||
        normalized == 'MASTERCARD' ||
        normalized == 'MASTER CARD') {
      assetPath = 'assets/icons/cc_mc.png';
    } else if (normalized == 'ELO') {
      assetPath = 'assets/icons/cc_elo.png';
    }

    if (assetPath != null) {
      return Image.asset(
        assetPath,
        package: 'finance_app',
        width: 36,
        height: 24,
        fit: BoxFit.contain,
      );
    }

    return const Icon(Icons.credit_card, size: 24);
  }

  List<Account> get _visibleExpenses {
    if (_activeFilters.isEmpty) return _expenses;
    return _expenses.where((e) => _activeFilters.contains(_expenseTypeKey(e))).toList();
  }

  String _expenseTypeKey(Account e) {
    if (e.isRecurrent) return 'recorrencia';
    if (_isParcel(e)) return 'parcelado';
    return 'avista';
  }

  Widget _buildSummaryStrip() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    double totalSubs = 0, totalVista = 0, totalParcel = 0;
    for (final e in _expenses) {
      if (e.isRecurrent) {
        totalSubs += e.value;
      } else if (_isParcel(e)) {
        totalParcel += e.value;
      } else {
        totalVista += e.value;
      }
    }
    const assinaturaColor = Colors.purple;
    final vistaColor = Colors.green.shade700;
    final parceladoColor = Colors.orange.shade700;

    Widget buildSummaryCard(String label, double value, Color color, IconData icon, {String? filterKey}) {
      final bool isActive = filterKey != null && _activeFilters.contains(filterKey);
      // Criar gradiente baseado na cor
      final Color gradientStart = color.withValues(alpha: 0.85);
      final Color gradientEnd = HSLColor.fromColor(color).withLightness(
        (HSLColor.fromColor(color).lightness * 0.7).clamp(0.0, 1.0)
      ).toColor();

      final card = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [gradientStart, gradientEnd],
          ),
          borderRadius: BorderRadius.circular(14),
          border: isActive ? Border.all(color: Colors.white, width: 2.5) : null,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: Colors.white, size: 14),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                UtilBrasilFields.obterReal(value),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      );
      if (filterKey == null) return Expanded(child: card);
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() {
            if (_activeFilters.contains(filterKey)) {
              _activeFilters.remove(filterKey);
            } else {
              _activeFilters.add(filterKey);
            }
          }),
          child: card,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: cs.surface,
      child: Row(
        children: [
          buildSummaryCard(
            'Recorrência',
            totalSubs,
            assinaturaColor,
            Icons.autorenew,
            filterKey: 'recorrencia',
          ),
          const SizedBox(width: 8),
          buildSummaryCard('À Vista', totalVista, vistaColor, Icons.attach_money, filterKey: 'avista'),
          const SizedBox(width: 8),
          buildSummaryCard('Parcelado', totalParcel, parceladoColor, Icons.view_agenda, filterKey: 'parcelado'),
        ],
      ),
    );
  }

  Widget _buildExpenseItem(Account expense) {
    final bool isSubscription = expense.isRecurrent;
    final bool isParcel = _isParcel(expense);
    final Color? customColor = expense.cardColor != null ? Color(expense.cardColor!) : null;

    DateTime? purchaseDate;
    if (expense.purchaseDate != null) {
      try {
        purchaseDate = DateTime.parse(expense.purchaseDate!);
      } catch (_) {}
    }
    purchaseDate ??= (expense.year != null && expense.month != null)
        ? DateTime(expense.year!, expense.month!, expense.dueDay)
        : null;

    IconData typeIcon = isSubscription
      ? Icons.autorenew
      : (isParcel ? Icons.view_agenda : Icons.attach_money);
    Color typeColor = isSubscription ? Colors.purple : (isParcel ? Colors.orange.shade700 : Colors.green.shade700);
    final Color accentColor = customColor ?? typeColor;

    final InstallmentDisplay installmentDisplay = _installmentDisplayFor(expense);
    final double totalPurchase = installmentDisplay.isInstallment ? expense.value * installmentDisplay.total : 0;
    final double remainingPurchase = installmentDisplay.isInstallment
      ? (totalPurchase - (expense.value * installmentDisplay.index)).clamp(0, totalPurchase)
      : 0;
    final String baseDescription = cleanInstallmentDescription(expense.description);

    // Criar gradiente para a barra lateral
    final Color gradientStart = accentColor;
    final Color gradientEnd = HSLColor.fromColor(accentColor).withLightness(
      (HSLColor.fromColor(accentColor).lightness * 0.6).clamp(0.0, 1.0)
    ).toColor();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showEditDialog(expense),
        onLongPress: () => _showDetailsPopup(expense),
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            // Barra lateral com gradiente
            Container(
              width: 6,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [gradientStart, gradientEnd],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            // Conteúdo principal
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Linha superior: Badge tipo + Data + Descrição + Valor
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Badge de tipo (Parcelado, Recorrência, À Vista)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [accentColor, gradientEnd],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.25),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(typeIcon, color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                isSubscription ? 'Recorrência' : (isParcel ? 'Parcelado' : 'À Vista'),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Data da compra
                        Text(
                          purchaseDate != null
                            ? DateFormat('dd/MM/yyyy', 'pt_BR').format(purchaseDate)
                            : '--/--/----',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Descrição
                        Expanded(
                          child: Text(
                            baseDescription,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Valor
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [accentColor, gradientEnd],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            UtilBrasilFields.obterReal(expense.value),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Linha inferior: Categoria + Parcelas/Ações
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Categoria (Conta Pai > Conta Filha)
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_typeById[expense.typeId]?.logo?.isNotEmpty == true)
                                Text(_typeById[expense.typeId]!.logo!, style: const TextStyle(fontSize: 12))
                              else
                                Icon(Icons.folder_outlined, size: 12, color: Colors.grey.shade600),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  _typeById[expense.typeId]?.name ?? '',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (expense.categoryId != null) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(Icons.chevron_right, size: 12, color: Colors.grey.shade400),
                                ),
                                if (_categoryById[expense.categoryId!]?.logo?.isNotEmpty == true)
                                  Text(_categoryById[expense.categoryId!]!.logo!, style: const TextStyle(fontSize: 12))
                                else
                                  Icon(Icons.label_outline, size: 12, color: Colors.grey.shade600),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    _categoryById[expense.categoryId!]?.categoria ?? '',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Parcelas (se aplicável) + Botões de ação
                        if (installmentDisplay.isInstallment) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${installmentDisplay.index}/${installmentDisplay.total}',
                                  style: TextStyle(
                                    color: typeColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Restam ${UtilBrasilFields.obterReal(remainingPurchase)}',
                                  style: TextStyle(
                                    color: typeColor.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Botões de ação
                        if (!isSubscription)
                          _buildActionButton(
                            icon: Icons.drive_file_move_outline,
                            color: Colors.orange.shade600,
                            onTap: () => _showMoveDialog(expense),
                            tooltip: 'Mover',
                          ),
                        const SizedBox(width: 4),
                        _buildActionButton(
                          icon: Icons.delete_outline,
                          color: Colors.red.shade600,
                          onTap: () => _confirmDelete(expense),
                          tooltip: 'Excluir',
                        ),
                      ],
                    ),
                    // Barra de progresso para parcelados
                    if (installmentDisplay.isInstallment)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: installmentDisplay.total == 0
                                ? 0
                                : installmentDisplay.index / installmentDisplay.total,
                            minHeight: 4,
                            backgroundColor: typeColor.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(typeColor),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }

  // --- DIÁLOGO DE MOVER (COM TABELA DE SIMULAÇÃO RESTAURADA) ---
  Future<void> _showMoveDialog(Account expense) async {
    // 1. Carrega a série ANTES de abrir o diálogo
    List<Account> seriesPreview = [];
    bool isParcel = _isParcel(expense);

    if (isParcel) {
       if (expense.purchaseUuid != null) {
          seriesPreview = await DatabaseHelper.instance.readInstallmentSeriesByUuid(expense.purchaseUuid!);
       } else if (expense.cardId != null) {
          String baseDesc = expense.description.split('(')[0].trim();
          seriesPreview = await DatabaseHelper.instance.readInstallmentSeries(
            expense.cardId!,
            baseDesc,
            installmentTotal: expense.installmentTotal,
          );
       }
    } else {
      seriesPreview = [expense];
    }

    if (!mounted) return;

    int selectedMoveMonth = _currentMonth;
    int selectedMoveYear = _currentYear;
    String currentInvoiceStr = DateFormat('MM/yyyy').format(DateTime(_currentYear, _currentMonth));

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          
          String newDateStr = DateFormat('MM/yyyy').format(DateTime(selectedMoveYear, selectedMoveMonth));
          bool isDifferent = newDateStr != currentInvoiceStr;
          
          int currentTotalMonths = _currentYear * 12 + _currentMonth;
          int newTotalMonths = selectedMoveYear * 12 + selectedMoveMonth;
          int offset = newTotalMonths - currentTotalMonths;

          // --- TABELA DE SIMULAÇÃO DA SÉRIE ---
          Widget buildSeriesSummary() {
             if (!isDifferent) return const SizedBox.shrink();
             
             return Container(
               margin: const EdgeInsets.only(top: 10),
               height: 200, 
               decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
               child: Column(
                 children: [
                   Container(
                     padding: const EdgeInsets.all(8),
                     color: const Color(0xFFBBDEFB),
                     child: const Row(children: [Expanded(child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold))), Expanded(child: Text('De', style: TextStyle(fontWeight: FontWeight.bold))), Expanded(child: Text('Para', style: TextStyle(fontWeight: FontWeight.bold)))]),
                   ),
                   Expanded(
                     child: ListView.builder(
                       shrinkWrap: true,
                       itemCount: seriesPreview.length,
                       itemBuilder: (ctx, idx) {
                         final item = seriesPreview[idx];
                         // Calcula novo mês para este item específico
                         DateTime oldDate = DateTime(item.year!, item.month!);
                         DateTime newDate = DateTime(oldDate.year, oldDate.month + offset);
                         
                         return Container(
                           color: idx % 2 == 0 ? Colors.white : Colors.grey.shade50,
                           padding: const EdgeInsets.all(8),
                           child: Row(
                             children: [
                               Expanded(child: Text(item.description, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)),
                               Expanded(child: Text(DateFormat('MM/yyyy').format(oldDate), style: const TextStyle(fontSize: 11))),
                               Expanded(child: Text(DateFormat('MM/yyyy').format(newDate), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue))),
                             ],
                           ),
                         );
                       },
                     ),
                   ),
                 ],
               ),
             );
          }

          return AlertDialog(
            title: const Text('Mover Despesa(s)'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Selecione o NOVO início:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(flex: 3, child: DropdownButtonFormField<int>(initialValue: selectedMoveMonth, decoration: const InputDecoration(labelText: 'Mês', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0)), items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(DateFormat('MMMM', 'pt_BR').format(DateTime(2022, i + 1)).toUpperCase(), style: const TextStyle(fontSize: 13)))), onChanged: (val) => setStateDialog(() => selectedMoveMonth = val!))),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: DropdownButtonFormField<int>(initialValue: selectedMoveYear, decoration: const InputDecoration(labelText: 'Ano', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0)), items: List.generate(10, (i) => DropdownMenuItem(value: 2024 + i, child: Text('${2024 + i}'))), onChanged: (val) => setStateDialog(() => selectedMoveYear = val!))),
                    ],
                  ),
                  if (isParcel) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Esta ação moverá TODAS as parcelas da série.', style: TextStyle(fontSize: 11, color: Colors.deepOrange, fontStyle: FontStyle.italic))),
                  
                  // AQUI ESTÁ A TABELA RESTAURADA
                  buildSeriesSummary(),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Confirmar'),
                onPressed: (!isDifferent) ? null : () async {
                  try {
                    int offset = (selectedMoveYear * 12 + selectedMoveMonth) - (_currentYear * 12 + _currentMonth);
                    // Move em Bloco
                    if (isParcel && expense.purchaseUuid != null) {
                       await DatabaseHelper.instance.moveInstallmentSeriesByUuid(expense.purchaseUuid!, offset);
                    } else if (isParcel && expense.cardId != null) {
                       String baseDesc = expense.description.split('(')[0].trim();
                       await DatabaseHelper.instance.moveInstallmentSeries(expense.cardId!, baseDesc, offset);
                    } else {
                       await DatabaseHelper.instance.moveAccount(expense.id!, selectedMoveMonth, selectedMoveYear);
                    }
                    if (!mounted || !ctx.mounted) return;
                    Navigator.pop(ctx);
                    await _loadExpenses();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Movimentação realizada!'), backgroundColor: Colors.green));
                  } catch (e) {
                    // ignore: avoid_catches_without_on_clauses
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao mover: $e'), backgroundColor: Colors.red));
                    }
                  }
              })
            ],
          );
      }));
  }

  void _showDetailsPopup(Account expense) {
    String purchased = expense.purchaseDate != null ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(expense.purchaseDate!)) : '-';

    DateTime? adjustedDueDate = _getAdjustedDueDate();
    if (adjustedDueDate == null && expense.year != null && expense.month != null) {
      adjustedDueDate = DateTime(expense.year!, expense.month!, expense.dueDay);
    }
    String weekday = adjustedDueDate != null ? DateFormat.EEEE('pt_BR').format(adjustedDueDate) : '';
    String dueLabel = adjustedDueDate != null
        ? DateFormat('dd/MM/yyyy').format(adjustedDueDate)
        : '${expense.dueDay.toString().padLeft(2, '0')}/${expense.month}/${expense.year}';

    double totalSubs = 0, totalVista = 0, totalParcel = 0;
    for (final e in _expenses) {
      if (e.isRecurrent) {
        totalSubs += e.value;
      } else if (_isParcel(e)) {
        totalParcel += e.value;
      } else {
        totalVista += e.value;
      }
    }
    double totalAll = totalSubs + totalVista + totalParcel;

    bool isSubscription = expense.isRecurrent;
    bool isParcel = RegExp(r'\(\d+/\d+\)').hasMatch(expense.description);
    IconData typeIcon = isSubscription ? Icons.loop : (isParcel ? Icons.layers : Icons.check_circle_outline);
    Color typeColor = isSubscription ? Colors.purple : (isParcel ? Colors.orange : Colors.green);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Detalhes da Despesa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$dueLabel ${weekday.isNotEmpty ? "($weekday)" : ""}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Text('Assinatura ${UtilBrasilFields.obterReal(totalSubs)}', style: const TextStyle(color: Colors.purple)),
                Text('À Vista ${UtilBrasilFields.obterReal(totalVista)}', style: TextStyle(color: Colors.green.shade700)),
                Text('Parcelado ${UtilBrasilFields.obterReal(totalParcel)}', style: TextStyle(color: Colors.orange.shade700)),
                Text('Total ${UtilBrasilFields.obterReal(totalAll)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(typeIcon, color: typeColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Data compra: $purchased', style: const TextStyle(fontSize: 12)),
                      Text(expense.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Text(
                  UtilBrasilFields.obterReal(expense.value),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
        ],
      ),
    );
  }
  Future<void> _showEditDialog(Account expense) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => NewExpenseDialog(card: widget.card, expenseToEdit: expense),
    );

    // Se retornou true, recarregar a lista de despesas
    if (result == true && mounted) {
      await _loadExpenses();
    }
  }
  Future<void> _confirmDelete(Account expense) async {
    final bool isParcel = (expense.installmentTotal ?? 1) > 1 || expense.purchaseUuid != null;
    final bool isSubscription = expense.recurrenceId != null || expense.isRecurrent;

    if (isSubscription) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Excluir Recorrência?'),
          content: const Text('Como você deseja excluir esta recorrência?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                // Confirmar antes de apagar
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx2) => AlertDialog(
                    icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
                    title: const Text('Confirmar Exclusão'),
                    content: Text('Tem certeza que deseja apagar somente esta conta "${expense.description}"?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx2, false), child: const Text('Cancelar')),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(ctx2, true),
                        child: const Text('Sim, Apagar'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                await DatabaseHelper.instance.deleteAccount(expense.id!);
                await _loadExpenses();
              },
              child: const Text('Apagar somente essa conta', style: TextStyle(color: Colors.orange)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                // Confirmar antes de apagar
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx2) => AlertDialog(
                    icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
                    title: const Text('Confirmar Exclusão'),
                    content: Text('Tem certeza que deseja apagar "${expense.description}" e todas as recorrências futuras?\n\nEsta ação não pode ser desfeita.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx2, false), child: const Text('Cancelar')),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(ctx2, true),
                        child: const Text('Sim, Apagar'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                // Apagar essa e futuras
                try {
                  final allAccounts =
                      await DatabaseHelper.instance.readAllAccountsRaw();
                  final currentDate = DateTime(expense.year ?? DateTime.now().year,
                      expense.month ?? DateTime.now().month, 1);
                  final parentId = expense.recurrenceId ?? expense.id;

                  final futureAccounts = allAccounts.where((a) {
                    if (a.recurrenceId != parentId) return false;
                    final accDate =
                        DateTime(a.year ?? DateTime.now().year, a.month ?? 1, 1);
                    return accDate.isAtSameMomentAs(currentDate) ||
                        accDate.isAfter(currentDate);
                  }).toList();

                  for (final future in futureAccounts) {
                    if (future.id != null) {
                      await DatabaseHelper.instance.deleteAccount(future.id!);
                    }
                  }

                  await _loadExpenses();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao excluir: $e')),
                  );
                }
              },
              child: const Text('Apagar essa e futuras', style: TextStyle(color: Colors.deepOrange)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(ctx);
                // Confirmar antes de apagar
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx2) => AlertDialog(
                    icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
                    title: const Text('Confirmar Exclusão'),
                    content: Text('Tem certeza que deseja apagar TODAS as recorrências de "${expense.description}"?\n\nEsta ação não pode ser desfeita.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx2, false), child: const Text('Cancelar')),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(ctx2, true),
                        child: const Text('Sim, Apagar'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                
                if (expense.recurrenceId != null) {
                  await DatabaseHelper.instance.deleteSubscriptionSeries(expense.recurrenceId!);
                } else if (expense.isRecurrent) {
                  // Apagar toda a recorrência
                  try {
                    final allAccounts =
                        await DatabaseHelper.instance.readAllAccountsRaw();
                    final relatedAccounts = allAccounts
                        .where((a) => a.recurrenceId == expense.id)
                        .toList();

                    for (final related in relatedAccounts) {
                      if (related.id != null) {
                        await DatabaseHelper.instance.deleteAccount(related.id!);
                      }
                    }

                    await DatabaseHelper.instance.deleteAccount(expense.id!);
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao excluir: $e')),
                    );
                    return;
                  }
                }
                await _loadExpenses();
              },
              child: const Text('Apagar todas as recorrências'),
            ),
          ],
        ),
      );
      return;
    }

    if (isParcel) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Excluir Parcelamento?'),
          content: const Text('Esta é uma compra parcelada.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final confirmed = await _confirmSimpleDelete('somente esta parcela', expense.description);
                if (confirmed != true) return;
                await DatabaseHelper.instance.deleteAccount(expense.id!);
                await _loadExpenses();
              },
              child: const Text('Somente esta', style: TextStyle(color: Colors.orange)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final confirmed = await _confirmSimpleDelete('esta e futuras', expense.description);
                if (confirmed != true) return;
                if (expense.purchaseUuid != null) {
                  final series = await DatabaseHelper.instance.readInstallmentSeriesByUuid(expense.purchaseUuid!);
                  for (final acc in series) {
                    final idx = acc.installmentIndex ?? 1;
                    final currentIdx = expense.installmentIndex ?? 1;
                    if (idx < currentIdx) continue;
                    if (acc.id != null) {
                      await DatabaseHelper.instance.deleteAccount(acc.id!);
                    }
                  }
                } else {
                  final baseDesc = expense.description.split('(')[0].trim();
                  final series = await DatabaseHelper.instance.readInstallmentSeries(expense.cardId!, baseDesc, installmentTotal: expense.installmentTotal);
                  for (final acc in series) {
                    final idx = acc.installmentIndex ?? 1;
                    final currentIdx = expense.installmentIndex ?? 1;
                    if (idx < currentIdx) continue;
                    if (acc.id != null) {
                      await DatabaseHelper.instance.deleteAccount(acc.id!);
                    }
                  }
                }
                await _loadExpenses();
              },
              child: const Text('Essa e futuras'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(ctx);
                final confirmed = await _confirmSimpleDelete('todas as parcelas', expense.description, strong: true);
                if (confirmed != true) return;
                if (expense.purchaseUuid != null) {
                  await DatabaseHelper.instance.deleteInstallmentSeriesByUuid(expense.purchaseUuid!);
                } else {
                  String baseDesc = expense.description.split('(')[0].trim();
                  await DatabaseHelper.instance.deleteInstallmentSeries(expense.cardId!, baseDesc);
                }
                await _loadExpenses();
              },
              child: const Text('Todas as parcelas'),
            ),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja excluir "${expense.description}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sim, Apagar'),
          ),
        ],
      ),
    );
    if (confirm == true && expense.id != null) {
      await DatabaseHelper.instance.deleteAccount(expense.id!);
      if (!mounted) return;
      await _loadExpenses();
    }
  }

  Future<bool?> _confirmSimpleDelete(String scope, String description, {bool strong = false}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx2) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: strong ? Colors.red : Colors.orange, size: 48),
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja apagar $scope de "$description"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx2, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: strong ? Colors.red : Colors.orange),
            onPressed: () => Navigator.pop(ctx2, true),
            child: const Text('Sim, Apagar'),
          ),
        ],
      ),
    );
  }
}
// ignore_for_file: use_build_context_synchronously
