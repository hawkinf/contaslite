// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:brasil_fields/brasil_fields.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../services/prefs_service.dart';
import '../services/holiday_service.dart';
import '../utils/color_contrast.dart';
import 'credit_card_form.dart';
import 'card_expenses_screen.dart';
import '../widgets/new_expense_dialog.dart'; // CORRIGIDO O IMPORT

class CreditCardScreen extends StatefulWidget {
  const CreditCardScreen({super.key});

  @override
  State<CreditCardScreen> createState() => _CreditCardScreenState();
}

class _CreditCardScreenState extends State<CreditCardScreen> {
  List<Account> _cards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() => _isLoading = true);
    final list = await DatabaseHelper.instance.readAllCards();
    setState(() {
      _cards = list;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTimeRange>(
      valueListenable: PrefsService.dateRangeNotifier,
      builder: (context, range, _) {
        final media = MediaQuery.of(context);
        final fabRight = math.max(8.0, math.min(24.0, media.size.width * 0.02));
        final fabBottom = math.max(16.0, math.min(48.0, media.size.height * 0.08));
        final monthLabel = DateFormat('MMMM yyyy', 'pt_BR')
            .format(range.start)
            .toUpperCase();
        final headerColor = Theme.of(context).colorScheme.primary;
        final headerTextColor = Theme.of(context).colorScheme.onPrimary;
        return Scaffold(
          floatingActionButton: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(right: fabRight, bottom: fabBottom),
              child: FloatingActionButton(
              backgroundColor: Colors.purple.shade700,
              foregroundColor: Colors.white,
              onPressed: () async {
                await showDialog(context: context, builder: (_) => const CreditCardFormScreen());
                _loadCards();
              },
              child: const Icon(Icons.add),
              ),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: [
          Container(
            color: headerColor,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                    fontSize: 24,
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _cards.isEmpty
                    ? const Center(child: Text('Nenhum cartão cadastrado.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _cards.length,
                        itemBuilder: (context, index) {
                          return CreditCardItemWidget(
                            card: _cards[index],
                            onUpdateNeeded: _loadCards,
                            referenceDate: range.start,
                          );
                        },
                      ),
          ),
        ],
      ),
        );
      },
    );
  }
}

class CreditCardItemWidget extends StatefulWidget {
  final Account card;
  final VoidCallback onUpdateNeeded;
  final DateTime referenceDate;

  const CreditCardItemWidget({
    super.key,
    required this.card,
    required this.onUpdateNeeded,
    required this.referenceDate,
  });

  @override
  State<CreditCardItemWidget> createState() => _CreditCardItemWidgetState();
}

class _CreditCardItemWidgetState extends State<CreditCardItemWidget> {
  late DateTime _viewDate;
  double _currentInvoice = 0.0;
  double _installmentTotal = 0.0;
  double _oneOffTotal = 0.0;
  double _subscriptionTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _viewDate = widget.referenceDate;
    _loadTotals();
  }
  @override
  void didUpdateWidget(CreditCardItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.referenceDate != widget.referenceDate) {
      _viewDate = widget.referenceDate;
      _loadTotals();
    }
  }



  Future<void> _openExpenses() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardExpensesScreen(card: widget.card, month: _viewDate.month, year: _viewDate.year),
      ),
    );
    _loadTotals();
  }

  // MÉTODO _changeMonth RESTAURADO AQUI
  void _changeMonth(int offset) {
    PrefsService.shiftDateRange(offset);
  }

  Future<void> _loadTotals() async {
    final expenses = await DatabaseHelper.instance.getCardExpensesForMonth(widget.card.id!, _viewDate.month, _viewDate.year);
    final db = await DatabaseHelper.instance.database;
    final recurringRes = await db.query('accounts', where: 'cardId = ? AND isRecurrent = 1', whereArgs: [widget.card.id]);
    List<Account> subscriptions = recurringRes.map((e) => Account.fromMap(e)).toList();

    double sumInst = 0.0; double sumOneOff = 0.0; double sumSubs = 0.0;

    for (var exp in expenses) {
      if (exp.description.contains(RegExp(r'\(\d+/\d+\)'))) {
        sumInst += exp.value;
      } else {
        sumOneOff += exp.value;
      }
    }

    for (var sub in subscriptions) {
      bool alreadyLaunched = expenses.any((e) => e.recurrenceId == sub.id);
      if (!alreadyLaunched) {
         bool show = true;
         if (sub.year != null && sub.month != null) {
            int startTotal = sub.year! * 12 + sub.month!;
            int currentTotal = _viewDate.year * 12 + _viewDate.month;
            if (currentTotal < startTotal) show = false;
         }
         if (show) sumSubs += sub.value;
      }
    }

    // Carregar informações de pagamento para despesas do mês
    final paymentInfo = <int, Map<String, dynamic>>{};
    for (var expense in expenses) {
      final info = await DatabaseHelper.instance.getAccountPaymentInfo(expense.id!);
      if (info != null) {
        paymentInfo[expense.id!] = info;
      }
    }

    if (mounted) {
      setState(() {
        _installmentTotal = sumInst;
        _oneOffTotal = sumOneOff;
        _subscriptionTotal = sumSubs;
        _currentInvoice = sumInst + sumOneOff + sumSubs;
      });
    }
  }

  void _showNewExpenseDialog() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NewExpenseDialog(card: widget.card)),
    );

    if (result == true) {
      _loadTotals();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lançado com sucesso!'), backgroundColor: Colors.green),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    // ... (restante do build widget)
    DateTime dueDateBase = DateTime(_viewDate.year, _viewDate.month, widget.card.dueDay);
    var check = HolidayService.adjustDateToBusinessDay(dueDateBase, PrefsService.cityNotifier.value);
    DateTime displayDueDate = check.date;
    final bool isAdjusted = check.warning != null && !DateUtils.isSameDay(dueDateBase, displayDueDate);
    String monthName = DateFormat('MMMM yyyy', 'pt_BR').format(_viewDate).toUpperCase();
    
    Color bgColor = (widget.card.cardColor != null) ? Color(widget.card.cardColor!) : Colors.purple.shade900;
    final fgColor = foregroundColorFor(bgColor);

    List<Widget> detailsChildren = [
        _buildDetailRow('Parcelado:', _installmentTotal, Colors.orangeAccent, fgColor),
        const SizedBox(height: 2),
        _buildDetailRow('À Vista:', _oneOffTotal, Colors.lightBlueAccent, fgColor)
    ];
    if (_subscriptionTotal > 0) {
        detailsChildren.add(const SizedBox(height: 2));
        detailsChildren.add(_buildDetailRow('Assinaturas:', _subscriptionTotal, Colors.purpleAccent, fgColor));
    }
    detailsChildren.add(const SizedBox(height: 6));
    detailsChildren.add(Text('PREVISÃO FATURA', style: TextStyle(color: fgColor, fontSize: 10, fontWeight: FontWeight.bold)));
    detailsChildren.add(Text(UtilBrasilFields.obterReal(_currentInvoice), style: TextStyle(color: fgColor, fontSize: 24, fontWeight: FontWeight.bold)));

    return GestureDetector(
      onTap: _openExpenses,
      onDoubleTap: () {
        showDialog(
          context: context,
          builder: (_) => CreditCardFormScreen(cardToEdit: widget.card),
        ).then((_) => widget.onUpdateNeeded());
      },
      child: Card(
      elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(colors: [bgColor, bgColor.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight)), padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [IconButton(icon: Icon(Icons.chevron_left, color: fgColor), onPressed: () => _changeMonth(-1), padding: EdgeInsets.zero, constraints: const BoxConstraints()), const SizedBox(width: 8), Text(monthName, style: TextStyle(color: fgColor, fontWeight: FontWeight.bold, fontSize: 14)), const SizedBox(width: 8), IconButton(icon: Icon(Icons.chevron_right, color: fgColor), onPressed: () => _changeMonth(1), padding: EdgeInsets.zero, constraints: const BoxConstraints())]), Expanded(child: Text(widget.card.cardBank ?? 'Banco', style: TextStyle(color: fgColor, fontWeight: FontWeight.bold, fontSize: 20), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis))]), 
          Align(alignment: Alignment.centerRight, child: Text(widget.card.cardBrand ?? '', style: TextStyle(color: fgColor.withOpacity(0.8), fontSize: 12, fontStyle: FontStyle.italic))), 
          const SizedBox(height: 15), 
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: detailsChildren), if (widget.card.cardLimit != null && widget.card.cardLimit! > 0) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('LIMITE', style: TextStyle(color: fgColor.withOpacity(0.8), fontSize: 10)), Text(UtilBrasilFields.obterReal(widget.card.cardLimit!), style: TextStyle(color: fgColor.withOpacity(0.9), fontSize: 14))])]), 
          const SizedBox(height: 15), Divider(color: fgColor.withOpacity(0.2)), 
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('VENCIMENTO', style: TextStyle(color: fgColor.withOpacity(0.8), fontSize: 10)), Text('Original: ${DateFormat('dd/MM/yyyy').format(dueDateBase)}', style: TextStyle(color: fgColor.withOpacity(0.95), fontSize: 12)), if (isAdjusted) Text('Ajustada: ${DateFormat('dd/MM/yyyy').format(displayDueDate)}', style: TextStyle(color: fgColor, fontSize: 12, fontWeight: FontWeight.bold))]), 
          Row(children: [
            IconButton(icon: Icon(Icons.list_alt, color: fgColor, size: 24), tooltip: 'Ver Despesas', onPressed: _openExpenses), 
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: fgColor, foregroundColor: bgColor, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0), minimumSize: const Size(30, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap), onPressed: _showNewExpenseDialog, child: const Icon(Icons.add_shopping_cart, size: 18)), 
            PopupMenuButton<String>(icon: Icon(Icons.more_vert, color: fgColor.withOpacity(0.8)), onSelected: (val) { if (val == 'edit') { showDialog(context: context, builder: (_) => CreditCardFormScreen(cardToEdit: widget.card)).then((_) => widget.onUpdateNeeded()); } else if (val == 'delete') { _confirmDelete(); } }, itemBuilder: (context) => [const PopupMenuItem(value: 'edit', child: Text('Editar Cartão')), const PopupMenuItem(value: 'delete', child: Text('Excluir Cartão', style: TextStyle(color: Colors.red)))])
          ])
      ])]))
      ),
    );
  }

  Widget _buildDetailRow(String label, double value, Color color, Color baseColor) {
    return Row(children: [Text(label, style: TextStyle(color: baseColor.withOpacity(0.8), fontSize: 11)), const SizedBox(width: 6), Text(UtilBrasilFields.obterReal(value), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold))]);
  }
  
  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Excluir Cartão?'), content: Text('Deseja excluir o cartão ${widget.card.description}? Isso apagará também os lançamentos vinculados a ele.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir'))]));
    if (confirm == true && widget.card.id != null) { await DatabaseHelper.instance.deleteAccount(widget.card.id!); widget.onUpdateNeeded(); }
  }
}
// ignore_for_file: deprecated_member_use
