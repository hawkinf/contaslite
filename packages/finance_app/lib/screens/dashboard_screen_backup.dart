// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:brasil_fields/brasil_fields.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../services/prefs_service.dart';
import '../services/holiday_service.dart';
import '../utils/installment_utils.dart';
import '../widgets/app_input_decoration.dart';
import 'settings_screen.dart';
import 'account_form_screen.dart';
import 'account_types_screen.dart';
import 'credit_card_form.dart';
import 'card_expenses_screen.dart';
import 'account_edit_screen.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ... (Variáveis de estado mantidas)
  late DateTime _startDate;
  late DateTime _endDate;
  bool _datesInitialized = false;
  List<Account> _displayList = [];
  Map<int, String> _typeNames = {};
  bool _isLoading = true;
  double _totalPeriod = 0.0;

  @override
  void initState() { super.initState(); _initDates(); }
  Future<void> _initDates() async {
    final range = await PrefsService.loadDateRange();
    DateTime start = DateTime(range.start.year, range.start.month, 1);
    DateTime end = DateTime(range.start.year, range.start.month + 1, 0); 
    setState(() { _startDate = start; _endDate = end; _datesInitialized = true; });
    _loadData();
  }
  void _changeMonth(int offset) {
    DateTime newStart = DateTime(_startDate.year, _startDate.month + offset, 1);
    DateTime newEnd = DateTime(newStart.year, newStart.month + 1, 0);
    setState(() { _startDate = newStart; _endDate = newEnd; });
    PrefsService.saveDateRange(newStart, newEnd);
    _loadData();
  }
  void _refresh() => _loadData();

  Future<void> _loadData() async {
    if (!_datesInitialized) return;
    setState(() => _isLoading = true);
    
    final allAccounts = await DatabaseHelper.instance.readAllAccountsRaw();
    final types = await DatabaseHelper.instance.readAllTypes();
    final cards = await DatabaseHelper.instance.readAllCards(); 
    final typeMap = {for (var t in types) t.id!: t.name};

    List<Account> processedList = [];
    
    List<Account> recurrents = allAccounts.where((a) => a.isRecurrent && a.cardBrand == null && a.cardId == null).toList();
    List<Account> normalExpenses = allAccounts.where((a) => a.cardId == null && !a.isRecurrent && a.cardBrand == null).toList();

    DateTime current = _startDate;
    
    while (current.isBefore(_endDate) || DateUtils.isSameDay(current, _endDate)) {
      var specificForDay = normalExpenses.where((a) => a.dueDay == current.day && a.month == current.month && a.year == current.year).toList();
      processedList.addAll(specificForDay);
      
      var recurrentsForDay = recurrents.where((a) => a.dueDay == current.day).toList();
      for (var rec in recurrentsForDay) {
        bool isLaunched = normalExpenses.any((s) => s.recurrenceId == rec.id && s.month == current.month && s.year == current.year);
        if (!isLaunched) {
          processedList.add(Account(
            id: rec.id, typeId: rec.typeId, description: rec.description, value: 0.0, dueDay: rec.dueDay, isRecurrent: true, payInAdvance: rec.payInAdvance, month: current.month, year: current.year,
          ));
        }
      }
      current = current.add(const Duration(days: 1));
    }

    for (var card in cards) {
      var launchedInvoices = allAccounts.where((a) => 
         a.recurrenceId == card.id && 
         !a.isRecurrent && 
         a.cardBrand != null &&
         a.month == _startDate.month && 
         a.year == _startDate.year
      ).toList();
      
      processedList.addAll(launchedInvoices);

      if (launchedInvoices.isEmpty) {
          var expenses = await DatabaseHelper.instance.getCardExpensesForMonth(card.id!, _startDate.month, _startDate.year);
          final db = await DatabaseHelper.instance.database;
          final recurringRes = await db.query('accounts', where: 'cardId = ? AND isRecurrent = 1', whereArgs: [card.id]);
          List<Account> subs = recurringRes.map((e) => Account.fromMap(e)).toList();

          double totalForecast = 0.0; double sumInst = 0.0; double sumOneOff = 0.0; double sumSubs = 0.0;

          for (var exp in expenses) { totalForecast += exp.value; if (exp.description.contains(RegExp(r'\(\d+/\d+\)'))) {
            sumInst += exp.value;
          } else {
            sumOneOff += exp.value;
          } }
          for (var sub in subs) { if (!expenses.any((e) => e.recurrenceId == sub.id)) { bool show = true; if (sub.year != null && sub.month != null) { int startTotal = sub.year! * 12 + sub.month!; int currentTotal = _startDate.year * 12 + _startDate.month; if (currentTotal < startTotal) show = false; } if (show) { totalForecast += sub.value; sumSubs += sub.value; } } }

          String breakdown = 'T:${totalForecast.toStringAsFixed(2)};P:${sumInst.toStringAsFixed(2)};V:${sumOneOff.toStringAsFixed(2)};A:${sumSubs.toStringAsFixed(2)}';
          
          processedList.add(Account(
            id: card.id, typeId: card.typeId, description: 'Fatura: ${card.cardBank} - ${card.cardBrand}', 
            value: 0.0, dueDay: card.dueDay, month: _startDate.month, year: _startDate.year, 
            isRecurrent: true, payInAdvance: card.payInAdvance, cardBrand: card.cardBrand, 
            cardBank: card.cardBank, cardLimit: card.cardLimit, bestBuyDay: card.bestBuyDay,
            observation: breakdown, cardColor: card.cardColor,
          ));
      }
    }

    processedList.sort((a, b) => a.dueDay.compareTo(b.dueDay));
    double total = processedList.fold(0, (sum, item) => item.isRecurrent ? sum : sum + item.value);

    setState(() {
      _displayList = processedList;
      _typeNames = typeMap;
      _totalPeriod = total;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
      if (!_datesInitialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final headerColor = isDark ? Colors.grey.shade900 : Colors.blue.shade50;
      final totalColor = isDark ? Colors.greenAccent : Colors.blue.shade900;
      String monthLabel = DateFormat('MMMM yyyy', 'pt_BR').format(_startDate).toUpperCase();

      return Scaffold(
        appBar: AppBar(toolbarHeight: 80, title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Contas a Pagar', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)), Text('by Aguinaldo Liesack Baptistini', style: TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic))]), actions: [
          IconButton(icon: const Icon(Icons.category), tooltip: 'Tabelas', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountTypesScreen())).then((_) => _refresh())),
          IconButton(icon: const Icon(Icons.credit_card), tooltip: 'Novo Cartão', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreditCardFormScreen())).then((_) => _refresh())),
          IconButton(icon: const Icon(Icons.settings), onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())); setState(() {}); })
        ]),
        body: Column(children: [
            Container(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8), color: headerColor, child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(icon: const Icon(Icons.chevron_left, size: 32), onPressed: () => _changeMonth(-1)), Text(monthLabel, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)), IconButton(icon: const Icon(Icons.chevron_right, size: 32), onPressed: () => _changeMonth(1))]), const SizedBox(height: 10), Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withOpacity(0.3)), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0,2))]), child: Column(children: [const Text('TOTAL REALIZADO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)), Text(UtilBrasilFields.obterReal(_totalPeriod), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: totalColor))]))])),
            Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : _displayList.isEmpty ? const Center(child: Text('Nenhuma conta para este mês.')) : ListView.builder(padding: const EdgeInsets.fromLTRB(0, 0, 0, 100), itemCount: _displayList.length, itemBuilder: (context, index) { return _buildAccountCard(_displayList[index]); })),
        ]),
        floatingActionButton: FloatingActionButton(heroTag: 'btnAdd', tooltip: 'Lançar Conta', backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white, child: const Icon(Icons.add), onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountFormScreen())); _refresh(); }),
      );
  }

  Widget _buildAccountCard(Account account) {
    // Tratamento de Data
    int year = account.year ?? _startDate.year;
    int month = account.month ?? _startDate.month;
    int day = account.dueDay;
    int maxDays = DateUtils.getDaysInMonth(year, month);
    if (day > maxDays) day = maxDays;
    final originalDate = DateTime(year, month, day);
    final isWeekend = HolidayService.isWeekend(originalDate);
    final isHoliday = HolidayService.isHoliday(originalDate, PrefsService.cityNotifier.value);
    final isAlertDay = isWeekend || isHoliday;
    DateTime effectiveDate = originalDate;
    if (isAlertDay) { if (account.payInAdvance) { while(HolidayService.isWeekend(effectiveDate) || HolidayService.isHoliday(effectiveDate, PrefsService.cityNotifier.value)) { effectiveDate = effectiveDate.subtract(const Duration(days: 1)); } } else { while(HolidayService.isWeekend(effectiveDate) || HolidayService.isHoliday(effectiveDate, PrefsService.cityNotifier.value)) { effectiveDate = effectiveDate.add(const Duration(days: 1)); } } }
    
    final weekdayName = DateFormat('EEEE', 'pt_BR').format(effectiveDate); // Dia da Semana
    
    // Configurações de Cor e Estilo
    bool isCard = account.cardBrand != null;
    bool isRecurrent = account.isRecurrent;

    Color containerBg;
    Color cardColor;
    Color textColor;
    Color moneyColor;
    Color subTextColor;

    if (isCard) {
      Color userColor = (account.cardColor != null) ? Color(account.cardColor!) : Colors.purple.shade900;
      cardColor = userColor;
      containerBg = Colors.transparent; 
      textColor = (userColor.computeLuminance() > 0.5) ? Colors.black : Colors.white;
      subTextColor = textColor.withOpacity(0.8);
      moneyColor = textColor;
    } else {
      containerBg = isAlertDay ? Colors.red.shade800 : Colors.transparent;
      cardColor = isAlertDay ? Colors.white : Theme.of(context).cardColor;
      textColor = isAlertDay ? Colors.black87 : (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black);
      subTextColor = Colors.grey.shade600;
      if (isRecurrent) {
        moneyColor = Colors.grey;
      } else {
        moneyColor = Colors.green.shade700;
      }
      if (Theme.of(context).brightness == Brightness.dark && !isRecurrent) moneyColor = Colors.lightGreenAccent;
      if (isAlertDay && !isRecurrent) moneyColor = Colors.red.shade900;
    }

    // Dados para Cartão
    double t = 0;
    if (isCard && account.observation != null && account.observation!.startsWith('T:')) {
      try { t = double.parse(account.observation!.split(';')[0].split(':')[1]); } catch (_) {}
    }
    String statusText = isRecurrent ? 'PREVISÃO (RECORRENTE)' : 'LANÇADO';
    Color statusColor = isRecurrent ? Colors.deepOrange : Colors.green;
    if (isCard) { statusText = isRecurrent ? 'PREVISÃO' : 'FATURA FECHADA'; statusColor = isRecurrent ? Colors.white : Colors.black; }
    final cleanedDescription =
        cleanAccountDescription(account).replaceAll('Fatura: ', '');
    final installmentDisplay = resolveInstallmentDisplay(account);

    return Container(
      color: isCard ? null : containerBg,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Card(
        color: cardColor,
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          onTap: () async {
            if (isCard) {
              final realCard = Account(
                id: account.id,
                typeId: account.typeId,
                description: account.description.replaceAll('Fatura: ', ''),
                value: 0,
                dueDay: account.dueDay,
                cardColor: account.cardColor,
              );
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CardExpensesScreen(card: realCard, month: account.month!, year: account.year!),
                ),
              );
              _refresh();
            } else {
              _showEditSpecificDialog(account);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 1. COLUNA DATA
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(effectiveDate.day.toString().padLeft(2, '0'), style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: textColor, height: 1.0)),
                    if (isAlertDay) Padding(padding: const EdgeInsets.only(top: 4), child: Text("(Orig. ${DateFormat('dd/MM').format(originalDate)})", style: TextStyle(fontSize: 10, color: isCard ? Colors.white70 : Colors.red.shade700, fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(width: 12),
                
                // 2. COLUNA STATUS E NOME
                SizedBox(width: 100, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(weekdayName, style: TextStyle(fontSize: 13, color: subTextColor)), if (isHoliday) const Text('FERIADO', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)), if (isWeekend && !isHoliday) const Text('FIM DE SEMANA', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)), const SizedBox(height: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: (isCard ? Colors.white : statusColor).withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(statusText, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isCard ? textColor : statusColor)))]
                )),
                
                Container(height: 50, width: 1, color: isCard ? textColor.withOpacity(0.3) : Colors.grey.withOpacity(0.3)),
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
                          style: TextStyle(fontSize: 12, color: subTextColor)),
                      Text(cleanedDescription,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: textColor),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: installmentDisplay.isInstallment
                                  ? Colors.deepPurple.shade50
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(installmentDisplay.labelText,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: installmentDisplay.isInstallment
                                      ? Colors.deepPurple.shade700
                                      : Colors.green.shade700))),
                    ])),

                // 4. COLUNA VALOR E BOTÕES
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(UtilBrasilFields.obterReal(isCard && isRecurrent ? t : account.value), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: moneyColor)), 
                    const SizedBox(height: 8), 
                    Row(mainAxisSize: MainAxisSize.min, children: [
                        if (isCard) ...[
                           InkWell(onTap: () async { final realCard = Account(id: account.id, typeId: account.typeId, description: account.description.replaceAll('Fatura: ', ''), value: 0, dueDay: account.dueDay, cardColor: account.cardColor); await Navigator.push(context, MaterialPageRoute(builder: (_) => CardExpensesScreen(card: realCard, month: account.month!, year: account.year!))); _refresh(); }, child: _actionIcon(Icons.list_alt, textColor.withOpacity(0.2), textColor)),
                           const SizedBox(width: 6),
                           if (isRecurrent) InkWell(onTap: () => _showLaunchDialog(account, defaultVal: t), child: _actionIcon(Icons.rocket_launch, Colors.green.shade800, Colors.white)) else InkWell(onTap: () => _confirmDelete(account), child: _actionIcon(Icons.delete, Colors.red.shade800, Colors.white)),
                           PopupMenuButton<String>(icon: Icon(Icons.more_vert, color: textColor, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onSelected: (val) { if (val == 'edit') Navigator.push(context, MaterialPageRoute(builder: (_) => CreditCardFormScreen(cardToEdit: account))).then((_) => _refresh()); }, itemBuilder: (context) => [const PopupMenuItem(value: 'edit', child: Text('Editar Cartão'))])
                        ] 
                        else ...[
                          if (isRecurrent) InkWell(onTap: () => _showLaunchDialog(account), child: _actionIcon(Icons.rocket_launch, Colors.green.shade50, Colors.green.shade800)),
                          if (!isRecurrent) ...[
                            const SizedBox(width: 8),
                            InkWell(onTap: () => _confirmDelete(account), child: _actionIcon(Icons.delete, Colors.red.shade50, Colors.red.shade800)),
                          ],
                        ]
                    ]),
                ]),
              ]),
            ),
          ),
        ),
      );
  }

  Widget _actionIcon(IconData icon, Color bg, Color iconColor) { return Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)), child: Icon(icon, size: 16, color: iconColor)); }

  // ... (Diálogos mantidos)
  Future<void> _showLaunchDialog(Account rule, {double defaultVal = 0.0}) async {
    final valueController = TextEditingController(text: UtilBrasilFields.obterReal(defaultVal));
    DateTime initialDate = DateTime(rule.year ?? _startDate.year, rule.month ?? _startDate.month, rule.dueDay);
    var check = HolidayService.adjustDateToBusinessDay(initialDate, PrefsService.cityNotifier.value);
    final dateController = TextEditingController(text: DateFormat('dd/MM/yyyy').format(check.date));
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pagar Fatura'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: valueController,
              decoration: buildOutlinedInputDecoration(
                label: 'Valor Real (R\$)',
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
                label: 'Data Pagamento',
                icon: Icons.calendar_today,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('CONFIRMAR'),
            onPressed: () async {
              if (valueController.text.isEmpty) return;
              DateTime finalDate = UtilData.obterDateTime(dateController.text);
              double finalValue = UtilBrasilFields.converterMoedaParaDouble(valueController.text);
              final specificAccount = Account(
                typeId: rule.typeId,
                description: rule.description,
                value: finalValue,
                dueDay: finalDate.day,
                month: finalDate.month,
                year: finalDate.year,
                isRecurrent: false,
                payInAdvance: rule.payInAdvance,
                recurrenceId: rule.id,
                cardBrand: rule.cardBrand,
                cardColor: rule.cardColor,
                cardBank: rule.cardBank,
              );
              await DatabaseHelper.instance.createAccount(specificAccount);
              Navigator.pop(ctx);
              _refresh();
            },
          )
        ],
      ),
    );
  }
  // Método removido devido a refatoração de expense_categories
  // Future<void> _showExpenseDialog(Account card) async { ... }

  Future<void> _showEditSpecificDialog(Account account) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AccountEditScreen(account: account),
      ),
    );

    if (result == true && mounted) {
      _refresh();
    }
  }
  Future<void> _confirmDelete(Account acc) async { final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Excluir?'), content: Text("Apagar '${acc.description}'?"), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir'))])); if (confirm == true && acc.id != null) { await DatabaseHelper.instance.deleteAccount(acc.id!); _refresh(); } }
}
// ignore_for_file: deprecated_member_use
