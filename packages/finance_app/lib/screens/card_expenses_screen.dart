import 'dart:math' as math;

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
import '../utils/app_colors.dart';
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
    // Quando o scroll termina, sempre mostra o FAB
    if (notification is ScrollEndNotification) {
      if (!_isFabVisible) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) setState(() => _isFabVisible = true);
        });
      }
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
        _categoryById = {};
        _installmentById = {};
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isCompactFab = media.size.height < 640 || media.size.width < 360;
    final fabRight = math.max(8.0, math.min(24.0, media.size.width * 0.02));
    final fabBottom = math.max(16.0, math.min(48.0, media.size.height * 0.08));

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
      child: Container(
        color: const Color(0xFFECF0F5),
        child: Column(
          children: [
            // Botão voltar para modo inline
            if (widget.inline)
              Container(
                color: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: widget.onClose ?? () => Navigator.pop(context),
                      tooltip: 'Voltar',
                    ),
                      const Expanded(
                        child: Text(
                          'Despesas do Cartão',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(width: 48), // Balancear o layout
                  ],
                ),
              ),
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
                        child: _buildGroupedExpenseList(),
                      ),
          ),
        ],
        ),
      ),
    );

    if (widget.inline) {
      final bottomInset = media.viewInsets.bottom + media.padding.bottom;
      final rightInset = media.padding.right;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: media.size.width,
            height: media.size.height,
            child: body,
          ),
          Positioned(
            right: fabRight + rightInset,
            bottom: fabBottom + bottomInset,
            child: AnimatedScale(
              scale: _isFabVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: AnimatedOpacity(
                opacity: _isFabVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: FloatingActionButton(
                  heroTag: 'fabNewCardExpenseInline',
                  tooltip: 'Lançar despesa',
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  onPressed: _isFabVisible ? _openNewExpense : null,
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
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Voltar',
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
      floatingActionButton: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            right: fabRight,
            bottom: fabBottom + media.viewInsets.bottom,
          ),
          child: AnimatedScale(
            scale: _isFabVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: AnimatedOpacity(
              opacity: _isFabVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: FloatingActionButton(
                heroTag: 'fabNewCardExpense',
                tooltip: 'Lançar despesa',
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                onPressed: _isFabVisible ? _openNewExpense : null,
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
    final cardBank = widget.card.cardBank?.trim() ?? '';

    // Calcular datas de fechamento e vencimento  
    final closingDay = widget.card.dueDay - 7;
    DateTime closingDate = DateTime(_currentYear, _currentMonth, closingDay);
    DateTime dueDate = DateTime(_currentYear, _currentMonth, widget.card.dueDay);

    final Color cardColor = widget.card.cardColor != null 
        ? Color(widget.card.cardColor!) 
        : Colors.deepOrange;

    // Calcular totais
    double totalGeral = 0;
    for (final e in _expenses) {
      totalGeral += e.value;
    }

    // Calcular contraste automático baseado na luminância
    final luminance = cardColor.computeLuminance();
    final isDark = luminance < 0.5;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black.withValues(alpha: 0.6);
    final overlayColor = isDark ? Colors.black.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.08);

    // Dimensões fixas
    const verticalPadding = 8.0;
    const brandFontSize = 12.0;
    const bankFontSize = 9.0;
    const labelFontSize = 8.0;
    const valueFontSize = 19.0;
    const previstoFontSize = 10.0;
    const logoSize = 48.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        constraints: const BoxConstraints(minHeight: 110),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Overlay sutil para legibilidade
            Container(
              decoration: BoxDecoration(
                color: overlayColor,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            // Conteúdo principal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: verticalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (brand.isNotEmpty)
                              Text(
                                brand.toUpperCase(),
                                softWrap: true,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: brandFontSize,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                  letterSpacing: 0.6,
                                  height: 1.1,
                                ),
                              ),
                            if (cardBank.isNotEmpty) const SizedBox(height: 4),
                            if (cardBank.isNotEmpty)
                              Opacity(
                                opacity: 0.75,
                                child: Text(
                                  cardBank,
                                  softWrap: true,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: bankFontSize,
                                    color: textColor,
                                    fontWeight: FontWeight.w500,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              'TOTAL DA FATURA',
                              softWrap: true,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: labelFontSize,
                                fontWeight: FontWeight.w600,
                                color: subtitleColor,
                                letterSpacing: 0.6,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 56),
                    ],
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      UtilBrasilFields.obterReal(_invoiceLaunchedTotal),
                      style: TextStyle(
                        fontSize: valueFontSize,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Previsto: ${UtilBrasilFields.obterReal(totalGeral)}',
                    softWrap: true,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: previstoFontSize,
                      color: subtitleColor,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildDateChip(
                        'Fech.',
                        DateFormat('dd/MM').format(closingDate),
                        Icons.event_note,
                        textColor,
                        isDark,
                      ),
                      _buildDateChip(
                        'Venc.',
                        DateFormat('dd/MM').format(dueDate),
                        Icons.event_available,
                        textColor,
                        isDark,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (brand.isNotEmpty)
              Positioned(
                top: 12,
                right: 12,
                child: _buildBrandBadge(
                  cardColor: cardColor,
                  size: logoSize,
                  child: _buildCardBrandIcon(brand),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateChip(String label, String value, IconData icon, Color textColor, bool isDark) {
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark 
          ? Colors.white.withValues(alpha: 0.15)
          : Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark 
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor.withValues(alpha: 0.8)),
          const SizedBox(width: 4),
          Text(
            '$label $value',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandBadge({
    required Color cardColor,
    required Widget child,
    double size = 48,
  }) {
    final luminance = cardColor.computeLuminance();
    final bool isLightCard = luminance > 0.6;

    final Color backgroundColor = isLightCard
        ? const Color(0xFF111111).withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.28);
    final Color borderColor = isLightCard
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.white.withValues(alpha: 0.35);

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
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
        width: 44,
        height: 32,
        fit: BoxFit.contain,
      );
    }

    return const Icon(Icons.credit_card, size: 28);
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
    // Calcular totais por tipo
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          // Cards de totais por tipo
          Row(
            children: [
              _buildTotalCard('Recorrência', totalSubs, Colors.purple.shade600, Icons.autorenew, 'recorrencia'),
              const SizedBox(width: 8),
              _buildTotalCard('À Vista', totalVista, Colors.green.shade600, Icons.attach_money, 'avista'),
              const SizedBox(width: 8),
              _buildTotalCard('Parcelado', totalParcel, Colors.orange.shade700, Icons.view_agenda, 'parcelado'),
            ],
          ),
          const SizedBox(height: 10),
          // Linha de filtros
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip('Todos', null, Icons.grid_view),
              _buildFilterChip('Recorrência', 'recorrencia', Icons.autorenew),
              _buildFilterChip('À Vista', 'avista', Icons.attach_money),
              _buildFilterChip('Parcelado', 'parcelado', Icons.view_agenda),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(String label, double value, Color color, IconData icon, String filterKey) {
    final isActive = _activeFilters.contains(filterKey);
    const cardHeight = 48.0;
    const iconSize = 18.0;
    const labelSize = 11.0;
    const valueSize = 15.0;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          if (_activeFilters.contains(filterKey)) {
            _activeFilters.remove(filterKey);
          } else {
            _activeFilters.add(filterKey);
          }
        }),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: cardHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive ? color : color.withValues(alpha: 0.2),
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: isActive ? [
              BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: iconSize),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: labelSize,
                        fontWeight: FontWeight.w600,
                        color: color,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        UtilBrasilFields.obterReal(value),
                        style: TextStyle(
                          fontSize: valueSize,
                          fontWeight: FontWeight.w700,
                          color: color,
                          height: 1.0,
                        ),
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

  Widget _buildFilterChip(String label, String? filterKey, IconData icon) {
    final isAll = filterKey == null;
    final isActive = isAll ? _activeFilters.isEmpty : _activeFilters.contains(filterKey);
    
    final chipHeight = 30.0;
    final chipPadding = 12.0;
    final chipFontSize = 12.0;
    final iconSize = 15.0;
    
    // Definir cor por tipo
    Color chipColor;
    if (isAll) {
      chipColor = Colors.blue.shade600;
    } else if (filterKey == 'recorrencia') {
      chipColor = Colors.purple.shade600;
    } else if (filterKey == 'avista') {
      chipColor = Colors.green.shade600;
    } else {
      chipColor = Colors.orange.shade700;
    }
    
    return InkWell(
      onTap: () => setState(() {
        if (isAll) {
          _activeFilters.clear();
        } else {
          if (_activeFilters.contains(filterKey)) {
            _activeFilters.remove(filterKey);
          } else {
            _activeFilters.add(filterKey);
          }
        }
      }),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: chipHeight,
        padding: EdgeInsets.symmetric(horizontal: chipPadding, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? chipColor : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? chipColor : chipColor.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: isActive ? [
            BoxShadow(
              color: chipColor.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: isActive ? Colors.white : chipColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: chipFontSize,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : chipColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedExpenseList() {
    // Agrupar despesas por data
    final Map<String, List<Account>> groupedByDate = {};
    for (final expense in _visibleExpenses) {
      DateTime? date;
      if (expense.purchaseDate != null) {
        try {
          date = DateTime.parse(expense.purchaseDate!);
        } catch (_) {}
      }
      date ??= DateTime(_currentYear, _currentMonth, expense.dueDay);
      
      final dateKey = DateFormat('dd/MM/yyyy').format(date);
      groupedByDate.putIfAbsent(dateKey, () => []).add(expense);
    }

    // Ordenar datas
    final sortedDates = groupedByDate.keys.toList()
      ..sort((a, b) {
        final dateA = DateFormat('dd/MM/yyyy').parse(a);
        final dateB = DateFormat('dd/MM/yyyy').parse(b);
        return dateA.compareTo(dateB);
      });

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateKey = sortedDates[index];
        final expenses = groupedByDate[dateKey]!;
        final date = DateFormat('dd/MM/yyyy').parse(dateKey);
        final dayOfWeek = DateFormat('EEEE', 'pt_BR').format(date).toUpperCase();
        
        // Dimensões do separador (confortável)
        const separatorMarginTop = 10.0;
        const separatorPadding = 6.0;
        const separatorIconSize = 14.0;
        const separatorFontSize = 12.0;
        const badgeSize = 20.0;
        const badgeFontSize = 10.5;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Separador de data
            Container(
              margin: const EdgeInsets.fromLTRB(16, separatorMarginTop, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: separatorPadding),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade600,
                    Colors.blue.shade700,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.20),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.white, size: separatorIconSize),
                  const SizedBox(width: 8),
                  Text(
                    '$dateKey • $dayOfWeek',
                    style: const TextStyle(
                      fontSize: separatorFontSize,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: badgeSize,
                    height: badgeSize,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${expenses.length}',
                        style: const TextStyle(
                          fontSize: badgeFontSize,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Items do dia
            ...expenses.map((expense) => _buildExpenseItem(expense)),
          ],
        );
      },
    );
  }

  Widget _buildExpenseItem(Account expense) {
    debugPrint('🔍 BUILD ITEM: "${expense.description}" | value: ${expense.value} | isRecurrent: ${expense.isRecurrent} | installmentIndex: ${expense.installmentIndex} | cardColor: ${expense.cardColor}');
    
    final bool isSubscription = expense.isRecurrent;
    final bool isParcel = _isParcel(expense);
    
    // Ignorar cardColor se for branco ou muito claro (invisível no fundo branco)
    Color? customColor;
    if (expense.cardColor != null) {
      final color = Color(expense.cardColor!);
      // Verificar se a cor é muito clara (luminância > 0.9)
      if (color.computeLuminance() < 0.9) {
        customColor = color;
      }
    }

    DateTime? purchaseDate;
    if (expense.purchaseDate != null) {
      try {
        purchaseDate = DateTime.parse(expense.purchaseDate!);
      } catch (_) {}
    }
    purchaseDate ??= (expense.year != null && expense.month != null)
        ? DateTime(expense.year!, expense.month!, expense.dueDay)
        : null;

    Color typeColor = isSubscription ? Colors.purple : (isParcel ? Colors.orange.shade700 : Colors.green.shade700);
    final Color accentColor = customColor ?? typeColor;

    // Debug: verificar valores
    if (expense.value == 0) {
      debugPrint('⚠️ Item sem valor: ${expense.description} - value: ${expense.value}');
    }

    final InstallmentDisplay installmentDisplay = _installmentDisplayFor(expense);
    final String baseDescription = cleanInstallmentDescription(expense.description);

    // Categoria
    String categoryText = '';
    if (expense.categoryId != null) {
      final cat = _categoryById[expense.categoryId];
      if (cat != null) categoryText = cat.categoria;
    }

    // Dimensões responsivas dos itens (confortável)
    const itemHeight = 52.0;
    const itemPadding = 6.0;
    const badgeSize = 32.0;
    const badgeIconSize = 14.0;
    const itemSpacing = 8.0;
    const titleFontSize = 14.5;
    const metadataFontSize = 11.5;

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: 1.5,
        horizontal: 16,
      ),
      clipBehavior: Clip.none,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade50, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showEditDialog(expense),
        onLongPress: () => _showDetailsPopup(expense),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // Stripe vertical colorida
            Container(
              width: 5,
              height: itemHeight,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, itemPadding, 8, itemPadding),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Badge circular com ícone
                    Container(
                      width: badgeSize,
                      height: badgeSize,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        isSubscription ? Icons.autorenew : (isParcel ? Icons.view_agenda : Icons.attach_money),
                        color: accentColor,
                        size: badgeIconSize,
                      ),
                    ),
                    const SizedBox(width: itemSpacing),
                    // Coluna com título e data/categoria
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Linha 1: Título
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  baseDescription,
                                  style: const TextStyle(
                                    fontSize: titleFontSize,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (installmentDisplay.isInstallment)
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(color: Colors.orange.shade200, width: 0.5),
                                  ),
                                  child: Text(
                                    '${installmentDisplay.index}/${installmentDisplay.total}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange.shade700,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Linha 2: Data + Categoria
                          Row(
                            children: [
                              if (purchaseDate != null) ...[
                                Icon(Icons.calendar_today, size: 11, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('dd/MM').format(purchaseDate),
                                  style: TextStyle(
                                    fontSize: metadataFontSize,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                              if (categoryText.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '•',
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    categoryText,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Badge com valor - padronizado
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.65),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        UtilBrasilFields.obterReal(expense.value),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                          height: 1.0,
                        ),
                      ),
                    ),
                    // Menu discreto
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade400),
                      padding: EdgeInsets.zero,
                      onSelected: (value) {
                        if (value == 'editar') {
                          _showEditDialog(expense);
                        } else if (value == 'mover') {
                          _showMoveDialog(expense);
                        } else if (value == 'detalhes') {
                          _showDetailsPopup(expense);
                        } else if (value == 'excluir') {
                          _confirmDelete(expense);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'editar', child: Text('Editar')),
                        const PopupMenuItem(value: 'mover', child: Text('Mover para outra fatura')),
                        const PopupMenuItem(value: 'detalhes', child: Text('Ver detalhes')),
                        const PopupMenuItem(value: 'excluir', child: Text('Excluir')),
                      ],
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

