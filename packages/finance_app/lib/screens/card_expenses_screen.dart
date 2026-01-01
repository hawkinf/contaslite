import 'package:flutter/material.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../services/prefs_service.dart';
import '../services/holiday_service.dart';
import '../utils/color_contrast.dart';
import '../utils/installment_utils.dart';
import '../widgets/new_expense_dialog.dart';
import 'card_expense_edit_screen.dart';
import '../widgets/date_range_app_bar.dart';

class CardExpensesScreen extends StatefulWidget {
  final Account card; 
  final int month;
  final int year;
  const CardExpensesScreen({super.key, required this.card, required this.month, required this.year});
  @override
  State<CardExpensesScreen> createState() => _CardExpensesScreenState();
}

class _CardExpensesScreenState extends State<CardExpensesScreen> {
  late int _currentMonth;
  late int _currentYear;
  List<Account> _expenses = [];
  bool _isLoading = true;
  Map<int, InstallmentDisplay> _installmentById = {};

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.month;
    _currentYear = widget.year;
    _loadExpenses();
  }

  void _changeMonth(int offset) {
    DateTime newDate = DateTime(_currentYear, _currentMonth + offset, 1);
    setState(() {
      _currentMonth = newDate.month;
      _currentYear = newDate.year;
    });
    _loadExpenses();
  }

  Future<void> _openNewExpense() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NewExpenseDialog(card: widget.card)),
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
    final expenses = await DatabaseHelper.instance.getCardExpensesForMonth(widget.card.id!, _currentMonth, _currentYear);
    final db = await DatabaseHelper.instance.database;
    final recurringRes = await db.query('accounts', where: 'cardId = ? AND isRecurrent = 1', whereArgs: [widget.card.id]);
    List<Account> subscriptions = recurringRes.map((e) => Account.fromMap(e)).toList();

    List<Account> displayList = [...expenses];
    for (var sub in subscriptions) {
      bool alreadyLaunched = expenses.any((e) => e.recurrenceId == sub.id);
      if (!alreadyLaunched) {
        bool show = true;
        if (sub.year != null && sub.month != null) {
           int subStart = sub.year! * 12 + sub.month!;
           int currentView = _currentYear * 12 + _currentMonth;
           if (currentView < subStart) show = false; 
        }
        if (show) {
          displayList.add(Account(id: sub.id, typeId: sub.typeId, description: sub.description, value: sub.value, dueDay: widget.card.dueDay, month: _currentMonth, year: _currentYear, isRecurrent: true, payInAdvance: sub.payInAdvance, cardId: sub.cardId, observation: sub.observation, recurrenceId: sub.id, purchaseDate: sub.purchaseDate, creationDate: sub.creationDate));
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

    setState(() {
      _expenses = displayList;
      _installmentById = installmentMap;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final DateTime? adjustedDate = _getAdjustedDueDate();
    final String weekdayLabel = adjustedDate != null ? DateFormat('EEEE', 'pt_BR').format(adjustedDate) : '';
    final String dateLabel = adjustedDate != null
        ? DateFormat("dd 'de' MMMM yyyy", 'pt_BR').format(adjustedDate)
        : DateFormat('MMMM yyyy', 'pt_BR').format(DateTime(_currentYear, _currentMonth));
    Color bgColor = (widget.card.cardColor != null) ? Color(widget.card.cardColor!) : Colors.purple.shade700;
    final fgColor = foregroundColorFor(bgColor);

    return ValueListenableBuilder<DateTimeRange>(
      valueListenable: PrefsService.dateRangeNotifier,
      builder: (context, range, _) {
        return Scaffold(
      appBar: DateRangeAppBar(
          title: widget.card.description,
          range: range,
          onPrevious: () => PrefsService.shiftDateRange(-1),
          onNext: () => PrefsService.shiftDateRange(1),
          backgroundColor: bgColor,
          foregroundColor: fgColor,
        ),
        floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fabNewCardExpense',
        onPressed: _openNewExpense,
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Lançar despesa'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade50,
                  Colors.blue.shade100.withValues(alpha: 0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.chevron_left, color: Colors.blue.shade700),
                    onPressed: () => _changeMonth(-1),
                    constraints: const BoxConstraints(minHeight: 40, minWidth: 40),
                    padding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.blue, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            dateLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      if (weekdayLabel.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              weekdayLabel.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.chevron_right, color: Colors.blue.shade700),
                    onPressed: () => _changeMonth(1),
                    constraints: const BoxConstraints(minHeight: 40, minWidth: 40),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          _buildSummaryStrip(),
          Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : _expenses.isEmpty ? const Center(child: Text('Nenhuma despesa nesta fatura.')) : ListView.builder(padding: const EdgeInsets.all(8), itemCount: _expenses.length, itemBuilder: (context, index) { return _buildExpenseItem(_expenses[index]); })),
        ],
      ),
        );
      },
    );
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
    double totalAll = totalSubs + totalVista + totalParcel;

    const assinaturaColor = Colors.purple;
    final vistaColor = Colors.green.shade700;
    final parceladoColor = Colors.orange.shade700;
    const totalColor = Colors.blue;

    Widget buildSummaryCard(String label, double value, Color color, IconData icon) {
      return Expanded(
        child: Card(
          elevation: 1,
          color: theme.cardTheme.color ?? cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: color.withValues(alpha: 0.25), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  UtilBrasilFields.obterReal(value),
                  style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: cs.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              buildSummaryCard('Assinatura', totalSubs, assinaturaColor, Icons.autorenew),
              const SizedBox(width: 8),
              buildSummaryCard('À Vista', totalVista, vistaColor, Icons.attach_money),
              const SizedBox(width: 8),
              buildSummaryCard('Parcelado', totalParcel, parceladoColor, Icons.view_agenda),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [totalColor.withValues(alpha: 0.12), totalColor.withValues(alpha: 0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: totalColor.withValues(alpha: 0.3), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL FATURA',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: totalColor),
                ),
                Text(
                  UtilBrasilFields.obterReal(totalAll),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: totalColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseItem(Account expense) {
    final bool isSubscription = expense.isRecurrent;
    final bool isParcel = _isParcel(expense);

    DateTime? purchaseDate;
    if (expense.purchaseDate != null) {
      try {
        purchaseDate = DateTime.parse(expense.purchaseDate!);
      } catch (_) {}
    }
    purchaseDate ??= (expense.year != null && expense.month != null)
        ? DateTime(expense.year!, expense.month!, expense.dueDay)
        : null;
    final String purchaseLabel = purchaseDate != null ? DateFormat('dd/MM/yyyy').format(purchaseDate) : 'Data indefinida';

    IconData typeIcon = isSubscription
        ? Icons.autorenew
        : (isParcel ? Icons.view_agenda : Icons.attach_money);
    String typeLabel = isSubscription ? 'Assinatura' : (isParcel ? 'Parcelado' : 'À Vista');
    Color typeColor = isSubscription ? Colors.purple : (isParcel ? Colors.orange.shade700 : Colors.green.shade700);
    Color borderColor = isSubscription ? Colors.purple : (isParcel ? Colors.orange.shade700 : Colors.green.shade700);

    final InstallmentDisplay installmentDisplay = _installmentDisplayFor(expense);
    final int? currentInstallment = installmentDisplay.isInstallment ? installmentDisplay.index : null;
    final int? installmentTotal = installmentDisplay.isInstallment ? installmentDisplay.total : null;
    double? totalPurchase = installmentDisplay.isInstallment ? expense.value * installmentDisplay.total : null;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 3),
      ),
      color: isSubscription ? Colors.purple.shade50 : Colors.white,
      child: InkWell(
        onTap: () => _showEditDialog(expense),
        onLongPress: () => _showDetailsPopup(expense),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: typeColor.withValues(alpha: 0.1),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(typeIcon, color: typeColor, size: 18),
                        const SizedBox(width: 6),
                        Text(typeLabel, style: TextStyle(color: typeColor, fontWeight: FontWeight.w700, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 13, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(purchaseLabel, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(expense.description,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: installmentDisplay.isInstallment ? typeColor.withValues(alpha: 0.15) : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  installmentDisplay.badgeText,
                                  style: TextStyle(
                                    color: installmentDisplay.isInstallment ? typeColor : Colors.green.shade800,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Progress bar para parcelamentos
                        if (isParcel && currentInstallment != null && installmentTotal != null && installmentTotal > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: currentInstallment / installmentTotal,
                                minHeight: 3,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: AlwaysStoppedAnimation<Color>(typeColor),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        UtilBrasilFields.obterReal(expense.value),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      if (totalPurchase != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Total ${UtilBrasilFields.obterReal(totalPurchase)}',
                              style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isSubscription)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.drive_file_move_outline, color: Colors.orange.shade700, size: 18),
                        tooltip: 'Mover Fatura',
                        onPressed: () => _showMoveDialog(expense),
                        constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red.shade700, size: 18),
                      tooltip: 'Excluir',
                      onPressed: () => _confirmDelete(expense),
                      constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
                      padding: EdgeInsets.zero,
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
                     color: Colors.blue.shade100,
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
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CardExpenseEditScreen(
          expense: expense,
          card: widget.card,
        ),
      ),
    );

    // Se retornou true, recarregar a lista de despesas
    if (result == true && mounted) {
      await _loadExpenses();
    }
  }
  Future<void> _confirmDelete(Account expense) async {
    bool isParcel = RegExp(r'\(\d+/\d+\)').hasMatch(expense.description);
    bool isSubscription = expense.recurrenceId != null || expense.isRecurrent;

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
                await DatabaseHelper.instance.deleteAccount(expense.id!);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                await _loadExpenses();
              },
              child: const Text('Apagar somente essa conta', style: TextStyle(color: Colors.orange)),
            ),
            TextButton(
              onPressed: () async {
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

                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  await _loadExpenses();
                } catch (e) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Erro ao excluir: $e')),
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Apagar essa e futuras', style: TextStyle(color: Colors.deepOrange)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
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
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Erro ao excluir: $e')),
                    );
                    Navigator.pop(ctx);
                    return;
                  }
                }
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
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
                await DatabaseHelper.instance.deleteAccount(expense.id!);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                await _loadExpenses();
              },
              child: const Text('Só esta parcela', style: TextStyle(color: Colors.orange)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                if (expense.purchaseUuid != null) {
                  await DatabaseHelper.instance.deleteInstallmentSeriesByUuid(expense.purchaseUuid!);
                } else {
                  String baseDesc = expense.description.split('(')[0].trim();
                  await DatabaseHelper.instance.deleteInstallmentSeries(expense.cardId!, baseDesc);
                }
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                await _loadExpenses();
              },
              child: const Text('Apagar Compra Inteira'),
            ),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir?'),
        content: Text("Apagar '${expense.description}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
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
}
// ignore_for_file: use_build_context_synchronously
