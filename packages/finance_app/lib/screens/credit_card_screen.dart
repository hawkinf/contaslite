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
import '../utils/app_colors.dart';
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

  Widget _borderedIcon(
    IconData icon, {
    Color? iconColor,
    Color? borderColor,
    double size = 22,
    EdgeInsets padding = const EdgeInsets.all(6),
  }) {
    final cIcon = iconColor ?? Colors.white;
    final cBorder = borderColor ?? cIcon;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cBorder, width: 1.2),
      ),
      child: Icon(icon, color: cIcon, size: size),
    );
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
                backgroundColor: AppColors.cardPurple,
                foregroundColor: Colors.white,
                onPressed: () async {
                  await showDialog(context: context, builder: (_) => const CreditCardFormScreen());
                  _loadCards();
                },
                child: _borderedIcon(Icons.add, iconColor: Colors.white, borderColor: Colors.white),
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
  double _launchedTotal = 0.0;

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

  Future<void> _editCard() async {
    await showDialog(
      context: context,
      builder: (_) => CreditCardFormScreen(cardToEdit: widget.card),
    );
    if (!mounted) return;
    widget.onUpdateNeeded();
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
        _launchedTotal = sumInst + sumOneOff;
        _currentInvoice = _launchedTotal + sumSubs; // previsto = lançado + recorrentes ainda não lançadas
      });
    }
  }

  void _showNewExpenseDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NewExpenseDialog(card: widget.card),
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
    
    Color bgColor = (widget.card.cardColor != null) ? Color(widget.card.cardColor!) : AppColors.cardPurpleDark;
    final fgColor = foregroundColorFor(bgColor);

    final headerBlock = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTotalLine('Recorrentes', _subscriptionTotal, AppColors.subscription, fgColor),
              const SizedBox(height: 6),
              _buildTotalLine('Parcelados', _installmentTotal, AppColors.installment, fgColor),
              const SizedBox(height: 6),
              _buildTotalLine('À vista', _oneOffTotal, AppColors.oneOff, fgColor),
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    UtilBrasilFields.obterReal(_launchedTotal),
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Previsto: ${UtilBrasilFields.obterReal(_currentInvoice)}',
                    style: TextStyle(
                      color: fgColor.withOpacity(0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Total', style: TextStyle(color: fgColor.withOpacity(0.78), fontSize: 12, fontWeight: FontWeight.w700)),
            Text(
              UtilBrasilFields.obterReal(_currentInvoice),
              style: const TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ],
    );

    return GestureDetector(
      onTap: _openExpenses,
      onDoubleTap: _editCard,
      child: Card(
      elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(colors: [bgColor, bgColor.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight)), padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: headerBlock),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Conta Pai - Conta Filha
                    Text(
                      widget.card.description,
                      style: TextStyle(
                        color: fgColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Marca do Cartão (opcional)
                    if ((widget.card.cardBrand ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          widget.card.cardBrand ?? '',
                          style: TextStyle(
                            color: fgColor.withOpacity(0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    // Banco Emissor com logo
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (widget.card.cardBrand?.toUpperCase() == 'MASTERCARD')
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: SizedBox(
                              width: 28,
                              height: 18,
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFFEB001B),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFFF79E1B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (widget.card.cardBrand?.toUpperCase() == 'VISA')
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Container(
                              width: 32,
                              height: 18,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1434CB),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: 2,
                                    left: 2,
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFFA200),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if ((widget.card.cardBrand?.toUpperCase().contains('AMEX') ?? false) ||
                                 (widget.card.cardBrand?.toUpperCase().contains('AMERICAN') ?? false))
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Container(
                              width: 28,
                              height: 18,
                              decoration: BoxDecoration(
                                color: const Color(0xFF006FCF),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            widget.card.cardBank ?? 'Banco',
                            style: TextStyle(
                              color: fgColor.withOpacity(0.75),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (widget.card.cardLimit != null && widget.card.cardLimit! > 0) ...[
                      const SizedBox(height: 6),
                      Text('LIMITE', style: TextStyle(color: fgColor.withOpacity(0.8), fontSize: 9)),
                      Text(UtilBrasilFields.obterReal(widget.card.cardLimit!), style: TextStyle(color: fgColor.withOpacity(0.9), fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: fgColor.withOpacity(0.18), height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: fgColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: fgColor.withOpacity(0.1)),
                  ),
                  child: Text(
                    isAdjusted
                        ? 'Vencimento: ${DateFormat('dd/MM/yyyy').format(displayDueDate)} (Ajustado • Original: ${DateFormat('dd/MM/yyyy').format(dueDateBase)})'
                        : 'Vencimento: ${DateFormat('dd/MM/yyyy').format(dueDateBase)}',
                    style: TextStyle(color: fgColor.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _actionIcon(Icons.rocket_launch, 'Lançar despesa', _showNewExpenseDialog, fgColor),
                  const SizedBox(width: 6),
                  _actionIcon(Icons.edit, 'Editar Cartão', _editCard, fgColor),
                  const SizedBox(width: 6),
                  _actionIcon(Icons.delete, 'Excluir Cartão', _confirmDelete, fgColor),
                ],
              ),
            ],
          )
        ]))
      ),
    );
  }

  Widget _buildTotalLine(String label, double value, Color accent, Color baseColor) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: baseColor.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: baseColor.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: baseColor.withOpacity(0.12)),
            ),
            child: Text(
              UtilBrasilFields.obterReal(value),
              style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w800),
              textAlign: TextAlign.right,
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionIcon(IconData icon, String tooltip, VoidCallback onPressed, Color baseColor) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: baseColor.withOpacity(0.07),
        foregroundColor: baseColor.withOpacity(0.88),
        minimumSize: const Size(34, 34),
        padding: const EdgeInsets.all(7),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: baseColor.withOpacity(0.12))),
      ),
    );
  }
  
  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 48),
        title: const Text('Confirmar Exclusao'),
        content: Text('Tem certeza que deseja excluir o cartao "${widget.card.description}"?\n\nIsso apagara tambem TODOS os lancamentos vinculados a ele.\n\nEsta acao nao pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.error), onPressed: () => Navigator.pop(ctx, true), child: const Text('Sim, Apagar'))
        ]
      )
    );
    if (confirm == true && widget.card.id != null) { await DatabaseHelper.instance.deleteAccount(widget.card.id!); widget.onUpdateNeeded(); }
  }
}
// ignore_for_file: deprecated_member_use
