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
import '../utils/installment_utils.dart';
import '../widgets/new_expense_dialog.dart';
import '../ui/components/entry_card.dart';
import '../ui/components/action_banner.dart';
import '../ui/components/section_header.dart';
import '../ui/widgets/date_pill.dart';
import '../ui/widgets/mini_chip.dart';

class CardExpensesScreen extends StatefulWidget {
  final Account card; 
  final int month;
  final int year;
  final DateTime? selectedDate;
  final bool inline;
  final VoidCallback? onClose;
  const CardExpensesScreen({
    super.key,
    required this.card,
    required this.month,
    required this.year,
    this.selectedDate,
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
  Account? _selectedExpense;

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

  void _changeMonth(int offset) {
    PrefsService.shiftDateRange(offset);
  }

  Future<void> _pickMonthYear() async {
    final initialDate = DateTime(_currentYear, _currentMonth, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Selecionar mês',
    );
    if (picked == null) return;
    final newStart = DateTime(picked.year, picked.month, 1);
    final newEnd = DateTime(newStart.year, newStart.month + 1, 0);
    PrefsService.saveDateRange(newStart, newEnd);
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
    final colorScheme = Theme.of(context).colorScheme;

    final filteredExpenses = _applySelectedDateFilter(_visibleExpenses);
    final headerRow = _buildCardHeaderRow(context);
    final selectionBanner = _selectedExpense == null
        ? null
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ActionBanner(
              leadingIcon: Icons.credit_card,
              text: '${cleanInstallmentDescription(_selectedExpense!.description)} – ${UtilBrasilFields.obterReal(_selectedExpense!.value)}',
              actions: [
                Tooltip(
                  message: 'Editar',
                  child: IconButton(
                    onPressed: () => _showEditDialog(_selectedExpense!),
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    icon: Icon(Icons.edit, color: colorScheme.primary),
                  ),
                ),
                Tooltip(
                  message: 'Excluir',
                  child: IconButton(
                    onPressed: () => _confirmDelete(_selectedExpense!),
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    icon: Icon(Icons.delete_outline, color: colorScheme.error.withValues(alpha: 0.85)),
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: () => setState(() => _selectedExpense = null),
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          );
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
        color: Theme.of(context).colorScheme.surface,
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
            if (selectionBanner != null) selectionBanner,
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredExpenses.isEmpty
                      ? Center(
                          child: Text(
                            widget.selectedDate != null
                                ? 'Nenhuma despesa neste dia.'
                                : 'Nenhuma despesa nesta fatura.',
                          ),
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: _handleScrollNotification,
                          child: _buildGroupedExpenseList(filteredExpenses),
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
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
        title: const Text('Despesas do Cartão'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
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
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
    final colorScheme = Theme.of(context).colorScheme;
    final monthLabel = DateFormat('MMMM yyyy', 'pt_BR').format(range.start);
    final formattedMonth = monthLabel.isEmpty
        ? monthLabel
        : monthLabel[0].toUpperCase() + monthLabel.substring(1);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: Center(
        child: _buildMonthHeaderPill(label: formattedMonth),
      ),
    );
  }

  Widget _buildMonthHeaderPill({
    required String label,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: colorScheme.onSurfaceVariant, size: 18),
            splashRadius: 18,
            onPressed: () => _changeMonth(-1),
            tooltip: 'Mês anterior',
          ),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: _pickMonthYear,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 18),
            splashRadius: 18,
            onPressed: () => _changeMonth(1),
            tooltip: 'Próximo mês',
          ),
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

    final colorScheme = Theme.of(context).colorScheme;
    final Color cardColor = widget.card.cardColor != null
      ? Color(widget.card.cardColor!)
      : colorScheme.primary;

    // Calcular totais
    double totalGeral = 0;
    for (final e in _expenses) {
      totalGeral += e.value;
    }

    final cardTitle = [cardBank, brand].where((t) => t.isNotEmpty).join(' • ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: cardColor.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          cardTitle.isEmpty ? 'Cartão' : cardTitle,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.credit_card, color: cardColor, size: 20),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    UtilBrasilFields.obterReal(_invoiceLaunchedTotal),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Previsto: ${UtilBrasilFields.obterReal(totalGeral)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Transform.scale(
                        scale: 0.92,
                        alignment: Alignment.centerLeft,
                        child: MiniChip(
                          label: 'Fech. ${DateFormat('dd/MM').format(closingDate)}',
                          icon: Icons.event_note,
                          iconColor: colorScheme.onSurfaceVariant,
                          textColor: colorScheme.onSurfaceVariant,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          borderColor: colorScheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      Transform.scale(
                        scale: 0.92,
                        alignment: Alignment.centerLeft,
                        child: MiniChip(
                          label: 'Venc. ${DateFormat('dd/MM').format(dueDate)}',
                          icon: Icons.event_available,
                          iconColor: colorScheme.onSurfaceVariant,
                          textColor: colorScheme.onSurfaceVariant,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          borderColor: colorScheme.outlineVariant.withValues(alpha: 0.6),
                        ),
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


  List<Account> get _visibleExpenses {
    if (_activeFilters.isEmpty) return _expenses;
    return _expenses.where((e) => _activeFilters.contains(_expenseTypeKey(e))).toList();
  }

  List<Account> _applySelectedDateFilter(List<Account> source) {
    final selectedDate = widget.selectedDate;
    if (selectedDate == null) return source;
    final filtered = source.where((expense) {
      DateTime? date;
      if (expense.purchaseDate != null) {
        try {
          date = DateTime.parse(expense.purchaseDate!);
        } catch (_) {}
      }
      date ??= DateTime(_currentYear, _currentMonth, expense.dueDay);
      return DateUtils.isSameDay(date, selectedDate);
    }).toList();
    return filtered.isEmpty ? source : filtered;
  }

  String _expenseTypeKey(Account e) {
    if (e.isRecurrent) return 'recorrencia';
    if (_isParcel(e)) return 'parcelado';
    return 'avista';
  }

  Widget _buildSummaryStrip() {
    final colorScheme = Theme.of(context).colorScheme;
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              _buildTotalCard(
                'Recorrência',
                totalSubs,
                colorScheme.secondary,
                Icons.autorenew,
                'recorrencia',
              ),
              const SizedBox(width: 8),
              _buildTotalCard(
                'À Vista',
                totalVista,
                colorScheme.primary,
                Icons.attach_money,
                'avista',
              ),
              const SizedBox(width: 8),
              _buildTotalCard(
                'Parcelado',
                totalParcel,
                colorScheme.tertiary,
                Icons.view_agenda,
                'parcelado',
              ),
            ],
          ),
          const SizedBox(height: 8),
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
    const cardHeight = 52.0;
    const iconSize = 18.0;
    const labelSize = 11.0;
    const valueSize = 14.0;
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          if (_activeFilters.contains(filterKey)) {
            _activeFilters.remove(filterKey);
          } else {
            _activeFilters.add(filterKey);
          }
        }),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: cardHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.surfaceContainerHighest
                : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? colorScheme.primary.withValues(alpha: 0.6)
                  : colorScheme.outlineVariant.withValues(alpha: 0.6),
              width: 1,
            ),
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
                        color: colorScheme.onSurfaceVariant,
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
    final colorScheme = Theme.of(context).colorScheme;
    final chipHeight = 30.0;
    final chipPadding = 12.0;
    final chipFontSize = 12.0;
    final iconSize = 15.0;

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
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: chipHeight,
        padding: EdgeInsets.symmetric(horizontal: chipPadding, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? colorScheme.primaryContainer : colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: isActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: chipFontSize,
                fontWeight: FontWeight.w600,
                color: isActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedExpenseList(List<Account> expensesToRender) {
    // Agrupar despesas por data
    final Map<String, List<Account>> groupedByDate = {};
    for (final expense in expensesToRender) {
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
      physics: const ClampingScrollPhysics(),
      primary: false,
      shrinkWrap: false,
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateKey = sortedDates[index];
        final expenses = groupedByDate[dateKey]!;
        final date = DateFormat('dd/MM/yyyy').parse(dateKey);
        final dayOfWeek = DateFormat('EEEE', 'pt_BR').format(date).toUpperCase();
        
        final colorScheme = Theme.of(context).colorScheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Separador de data
            SectionHeader(
              icon: Icons.calendar_today,
              title: '$dateKey • $dayOfWeek',
              trailing: MiniChip(
                label: expenses.length == 1
                    ? '1 item'
                    : '${expenses.length} itens',
                backgroundColor: colorScheme.surfaceContainerHighest,
                textColor: colorScheme.onSurfaceVariant,
                borderColor: colorScheme.outlineVariant.withValues(alpha: 0.6),
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

    final colorScheme = Theme.of(context).colorScheme;
    final bool isSubscription = expense.isRecurrent;
    final bool isParcel = _isParcel(expense);

    Color? customColor;
    if (expense.cardColor != null) {
      final color = Color(expense.cardColor!);
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

    final Color typeColor = isSubscription
      ? Colors.purple.shade400
      : (isParcel ? Colors.orange.shade700 : Colors.green.shade700);
    final Color cardAccent = customColor ?? colorScheme.primary;

    final InstallmentDisplay installmentDisplay = _installmentDisplayFor(expense);
    final String baseDescription = cleanInstallmentDescription(expense.description);

    String categoryText = '';
    if (expense.categoryId != null) {
      final cat = _categoryById[expense.categoryId];
      if (cat != null) categoryText = cat.categoria;
    }

    final String day = purchaseDate != null
        ? DateFormat('dd').format(purchaseDate)
        : expense.dueDay.toString().padLeft(2, '0');
    final String weekday = purchaseDate != null
        ? DateFormat('EEE', 'pt_BR').format(purchaseDate).replaceAll('.', '').toUpperCase()
        : '';

    final chips = <Widget>[
      MiniChip(
        label: isSubscription
            ? 'Recorrência'
            : (isParcel ? 'Parcelado' : 'À vista'),
        backgroundColor: colorScheme.surfaceContainerHighest,
        textColor: colorScheme.onSurfaceVariant,
        borderColor: colorScheme.outlineVariant.withValues(alpha: 0.6),
      ),
      if (installmentDisplay.isInstallment)
        MiniChip(
          label: '${installmentDisplay.index}/${installmentDisplay.total}',
          backgroundColor: colorScheme.surfaceContainerHighest,
          textColor: colorScheme.onSurfaceVariant,
          borderColor: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      if (categoryText.isNotEmpty)
        MiniChip(
          label: categoryText,
          backgroundColor: colorScheme.surfaceContainerHighest,
          textColor: colorScheme.onSurfaceVariant,
          borderColor: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () => _showEditDialog(expense),
        onLongPress: () {
          setState(() {
            if (_selectedExpense?.id == expense.id) {
              _selectedExpense = null;
            } else {
              _selectedExpense = expense;
            }
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: EntryCard(
          datePill: DatePill(
            day: day,
            weekday: weekday.isEmpty ? ' ' : weekday,
            accentColor: cardAccent,
          ),
          title: baseDescription,
          subtitle: purchaseDate != null
              ? DateFormat('dd/MM').format(purchaseDate)
              : 'Vencimento: ${expense.dueDay.toString().padLeft(2, '0')}',
          value: UtilBrasilFields.obterReal(expense.value),
          valueColor: typeColor,
          chips: chips,
          accentColor: typeColor,
          trailing: PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 18, color: colorScheme.onSurfaceVariant),
            padding: EdgeInsets.zero,
            onSelected: (value) {
              if (value == 'editar') {
                _showEditDialog(expense);
              } else if (value == 'excluir') {
                _confirmDelete(expense);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'editar', child: Text('Editar')),
              const PopupMenuItem(value: 'excluir', child: Text('Excluir')),
            ],
          ),
        ),
      ),
    );
  }

  // --- DIÁLOGO DE MOVER (COM TABELA DE SIMULAÇÃO RESTAURADA) ---
  // ignore: unused_element
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

  // ignore: unused_element
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

