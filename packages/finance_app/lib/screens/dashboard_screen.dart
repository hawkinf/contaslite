// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
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
import '../utils/card_utils.dart';
import 'account_form_screen.dart';
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
  Map<int, _InstallmentSummary> _installmentSummaries = {};
  Map<int, Map<String, dynamic>> _paymentInfo = {};
  final Map<int, double> _recurrenceParentValues = {}; // Mapeia recurrence ID -> valor previsto

  @override
  void initState() {
    super.initState();
    _initDates();
  }

  Future<void> _initDates() async {
    final range = await PrefsService.loadDateRange();
    DateTime start = DateTime(range.start.year, range.start.month, 1);
    DateTime end = DateTime(range.start.year, range.start.month + 1, 0);
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
    setState(() {
      _startDate = newStart;
      _endDate = newEnd;
    });
    PrefsService.saveDateRange(newStart, newEnd);
    _loadData();
  }

  void _refresh() => _loadData();

  bool _hasRecurrenceStarted(Account rec, DateTime current) {
    final hasStartDate = rec.year != null && rec.month != null;
    if (!hasStartDate) return true;
    return rec.year! < current.year || (rec.year == current.year && rec.month! <= current.month);
  }

  Future<void> _loadData() async {
    if (!_datesInitialized) return;
    setState(() => _isLoading = true);

    try {
      final allAccounts = await DatabaseHelper.instance.readAllAccountsRaw();
      final types = await DatabaseHelper.instance.readAllTypes();
      final cards = await DatabaseHelper.instance.readAllCards();
      final typeMap = {for (var t in types) t.id!: t.name};

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
      // Filtrar APENAS lançamentos normais (não instâncias auto-geradas de recorrências)
      // Instâncias auto-geradas: isRecurrent=false mas recurrenceId!=null (mostradas como "previstas")
      final normalExpenses = allAccounts
          .where((a) => a.cardId == null && !a.isRecurrent && a.cardBrand == null && a.recurrenceId == null)
          .toList();

      // Pré-computar índice de lançamentos para busca rápida
      final launchedIndex = <int, Set<String>>{};
      for (final exp in normalExpenses) {
        if (exp.recurrenceId != null) {
          final key = '${exp.recurrenceId}_${exp.year}_${exp.month}';
          launchedIndex.putIfAbsent(exp.recurrenceId!, () => {}).add(key);
        }
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
          processedList.addAll(accountsByMonth[monthKey] ?? []);

          // Adicionar recorrências não lançadas neste mês
          for (var rec in recurrents) {
            if (!_hasRecurrenceStarted(rec, current)) continue;

            final launchKey = '${rec.id}_${current.year}_${current.month}';
            if (!(launchedIndex[rec.id]?.contains(launchKey) ?? false)) {
              processedList.add(Account(
                id: rec.id,
                typeId: rec.typeId,
                description: rec.description,
                value: rec.value,
                dueDay: rec.dueDay,
                isRecurrent: true,
                payInAdvance: rec.payInAdvance,
                month: current.month,
                year: current.year,
              ));
            }
          }
        }

        current = current.add(const Duration(days: 1));
      }

      // Processar cartões: fazer queries apenas uma vez
      final db = await DatabaseHelper.instance.database;
      final cardExpensesByCardId = <int, List<Account>>{};
      final cardSubscriptionsByCardId = <int, List<Account>>{};

      for (var card in cards) {
        if (card.id == null) continue;

        // Query única para despesas do cartão
        final expenses = await DatabaseHelper.instance.getCardExpensesForMonth(
            card.id!, _startDate.month, _startDate.year);
        cardExpensesByCardId[card.id!] = expenses;

        // Query única para subscrições do cartão
        final recurringRes = await db.query('accounts',
            where: 'cardId = ? AND isRecurrent = 1',
            whereArgs: [card.id]);
        cardSubscriptionsByCardId[card.id!] =
            recurringRes.map((e) => Account.fromMap(e)).toList();
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

      processedList.sort((a, b) => a.dueDay.compareTo(b.dueDay));
      double total = processedList.fold(
          0, (sum, item) => item.isRecurrent ? sum : sum + item.value);
      final installmentSummaries =
          await _buildInstallmentSummaries(processedList);

      // Carregar informações de pagamento
      final paymentIds = processedList
          .where((account) => account.id != null)
          .map((account) => account.id!)
          .toList();
      final paymentInfo = paymentIds.isEmpty
          ? <int, Map<String, dynamic>>{}
          : await DatabaseHelper.instance.getPaymentsForAccountsByMonth(
              paymentIds, _startDate.month, _startDate.year);

      if (mounted) {
        setState(() {
          _displayList = processedList;
          _typeNames = typeMap;
          _totalPeriod = total;
          _installmentSummaries = installmentSummaries;
          _paymentInfo = paymentInfo;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao carregar dados: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar dados: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      if (!_datesInitialized) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final headerColor = isDark ? Colors.grey.shade900 : Colors.blue.shade50;
      final totalColor = isDark ? Colors.greenAccent : Colors.blue.shade900;
      String monthLabel =
          DateFormat('MMMM yyyy', 'pt_BR').format(_startDate).toUpperCase();

        return Scaffold(
        body: Column(children: [
        Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            color: headerColor,
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconButton(
                    icon: const Icon(Icons.chevron_left, size: 32),
                    onPressed: () => _changeMonth(-1)),
                Text(monthLabel,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color)),
                IconButton(
                    icon: const Icon(Icons.chevron_right, size: 32),
                    onPressed: () => _changeMonth(1))
              ]),
              const SizedBox(height: 10),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2))
                      ]),
                  child: Column(children: [
                    const Text('TOTAL REALIZADO',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.grey)),
                    Text(UtilBrasilFields.obterReal(_totalPeriod),
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: totalColor))
                  ]))
            ])),
        Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _displayList.isEmpty
                    ? const Center(child: Text('Nenhuma conta para este mês.'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
                        itemCount: _displayList.length,
                        itemBuilder: (context, index) {
                          try {
                            return _buildAccountCard(_displayList[index]);
                          } catch (e) {
                            debugPrint('❌ Erro ao renderizar card $index: $e');
                            return Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.all(8),
                              color: Colors.red.shade50,
                              child: Text('Erro ao renderizar: $e'),
                            );
                          }
                        })),
      ]),
      floatingActionButton: FloatingActionButton(
        heroTag: 'btnAdd',
        tooltip: 'Novo lançamento',
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        onPressed: _showQuickActions,
        child: const Icon(Icons.add),
      ),
    );
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao renderizar DashboardScreen: $e');
      debugPrintStack(stackTrace: stackTrace);
      return Scaffold(
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
    bool isRecurrent = account.isRecurrent;

    Color containerBg;
    Color cardColor;
    Color textColor;
    Color moneyColor;
    Color subTextColor;
    final Color? customAccent =
        !isCard && account.cardColor != null ? Color(account.cardColor!) : null;

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
        moneyColor = Colors.green.shade700;
      }
      if (Theme.of(context).brightness == Brightness.dark && !isRecurrent) {
        moneyColor = Colors.lightGreenAccent;
      }
      if (isAlertDay && !isRecurrent) {
        moneyColor = Colors.red.shade900;
      }
    }

    // Dados para Cartão
    final breakdown = isCard ? CardBreakdown.parse(account.observation) : const CardBreakdown(total: 0, installments: 0, oneOff: 0, subscriptions: 0);
    final t = breakdown.total;
    String statusText = isRecurrent ? 'PREVISÃO (RECORRENTE)' : 'LANÇADO';
    Color statusColor = isRecurrent ? Colors.deepOrange : Colors.green;
    if (isCard) {
      statusText = isRecurrent ? 'PREVISÃO' : 'FATURA FECHADA';
      statusColor = isRecurrent ? Colors.white : Colors.black;
    }
    
    // Diferenciador: se recorrenceId != null, foi lançado
    bool isLaunched = account.recurrenceId != null;
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
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: installmentBadgeTextColor)));

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
              await _openCardExpenses(account);
            } else {
              await _showEditSpecificDialog(account);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              if (customAccent != null) ...[
                Container(
                  width: 4,
                  height: 64,
                  decoration: BoxDecoration(
                    color: customAccent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              // 1. COLUNA DATA
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(effectiveDate.day.toString().padLeft(2, '0'),
                      style: TextStyle(
                          fontSize: 34,
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
                            fontSize: 10,
                            color: isCard ? subTextColor : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isAlertDay)
                          Text(
                            "Ajust. ${DateFormat('dd/MM').format(effectiveDate)}",
                            style: TextStyle(
                              fontSize: 10,
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
                                TextStyle(fontSize: 13, color: subTextColor)),
                        if (isHoliday)
                          const Text('FERIADO',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold)),
                        if (isWeekend && !isHoliday)
                          const Text('FIM DE SEMANA',
                              style: TextStyle(
                                  fontSize: 10,
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
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isCard ? textColor : statusColor)))
                      ])),

              Container(
                  height: 50,
                  width: 1,
                  color: isCard
                      ? textColor.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.3)),
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
                                      fontSize: 11,
                                      color: textColor.withValues(alpha: 0.85),
                                      fontWeight: FontWeight.w600)),
                              Text(
                                  'Restam: ${UtilBrasilFields.obterReal(installmentSummary.remainingAmount)}',
                                  style: TextStyle(
                                      fontSize: 11,
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
                  if (isLaunched) ..._buildRecurrenceValues(account) else ...[
                    // Recorrência prevista (não lançada)
                    Text(
                      UtilBrasilFields.obterReal(account.value),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'PREVISTO',
                      style: TextStyle(
                        fontSize: 10,
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
                          fontSize: 18,
                          color: moneyColor)),
                ],
                // Indicador de pagamento
                if (account.id != null && _paymentInfo.containsKey(account.id))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '*** PAGO ***',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'via ${_paymentInfo[account.id!]?['method_name'] ?? ''}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 10,
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
                          await rec.Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CreditCardFormScreen(cardToEdit: account),
                            ),
                          );
                          _refresh();
                        },
                        child: _actionIcon(Icons.edit,
                            textColor.withValues(alpha: 0.2), textColor)),
                    const SizedBox(width: 6),
                    InkWell(
                        onTap: isPaid ? null : () => _handlePayAction(account),
                        child: _actionIcon(Icons.payments, Colors.blue.shade50,
                          Colors.blue.shade800,
                          enabled: !isPaid)),
                    const SizedBox(width: 6),
                    InkWell(
                        onTap: () => _showExpenseDialog(account),
                        child: _actionIcon(Icons.add_shopping_cart,
                            textColor.withValues(alpha: 0.2), textColor)),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _showLaunchInvoiceDialog(account, t),
                      child: _actionIcon(Icons.description,
                          Colors.orange.shade50, Colors.orange.shade700),
                    ),
                    const SizedBox(width: 6),
                    if (account.id != null)
                      InkWell(
                        onTap: () => _confirmDelete(account),
                        child: _actionIcon(
                            Icons.delete, Colors.red.shade50, Colors.red.shade800),
                      ),
                  ] else ...[
                    InkWell(
                        onTap: isPaid ? null : () => _handlePayAction(account),
                        child: _actionIcon(Icons.payments, Colors.blue.shade50,
                            Colors.blue.shade800,
                            enabled: !isPaid)),
                    const SizedBox(width: 8),
                    if (isRecurrent && !isLaunched)
                      InkWell(
                          onTap: () => _showLaunchDialog(account),
                          child: _actionIcon(Icons.rocket_launch,
                              Colors.green.shade50, Colors.green.shade800)),
                    if (isRecurrent && !isLaunched)
                      const SizedBox(width: 8),
                    InkWell(
                        onTap: () => _confirmDelete(account),
                        child: _actionIcon(Icons.delete, Colors.red.shade50,
                            Colors.red.shade800)),
                  ]
                ]),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _handlePayAction(Account account) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentDialog(
          startDate: _startDate,
          endDate: _endDate,
          preselectedAccount: account,
        ),
      ),
    );
    if (result == true) {
      _refresh();
    }
  }

  Widget _actionIcon(IconData icon, Color bg, Color iconColor,
      {bool enabled = true}) {
    final displayColor = enabled ? iconColor : iconColor.withValues(alpha: 0.4);
    final displayBg = enabled ? bg : bg.withValues(alpha: 0.3);
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
              color: displayBg, borderRadius: BorderRadius.circular(4)),
          child: Icon(icon, size: 16, color: displayColor)),
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

  List<Widget> _buildRecurrenceValues(Account account) {
    // Para lançamentos de recorrência, mostrar Previsto e Lançado
    double averageValue = account.recurrenceId != null 
        ? (_recurrenceParentValues[account.recurrenceId] ?? account.value)
        : account.value;
    double launchedValue = account.value;
    
    return [
      // Valor previsto (cinza, tachado, menor)
      Text(
        UtilBrasilFields.obterReal(averageValue),
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade600,
          decoration: TextDecoration.lineThrough,
          decorationColor: Colors.grey.shade400,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        'Previsto',
        style: TextStyle(
          fontSize: 8,
          color: Colors.grey.shade600,
        ),
      ),
      const SizedBox(height: 6),
      // Valor lançado (vermelho, normal, maior)
      Text(
        UtilBrasilFields.obterReal(launchedValue),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.red.shade700,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        'LANÇADO',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.red.shade700,
        ),
      ),
    ];
  }

  // ... (Diálogos mantidos)
  Future<void> _showLaunchDialog(Account rule) async {
    // Calcular valor médio da recorrência
    final allAccounts = await DatabaseHelper.instance.readAllAccountsRaw();
    final relatedAccounts = allAccounts
        .where((a) => a.recurrenceId == rule.id && !a.isRecurrent)
        .toList();

    double averageValue = rule.value;
    if (relatedAccounts.isNotEmpty) {
      final totalValue =
          relatedAccounts.fold<double>(0, (sum, a) => sum + a.value);
      averageValue = totalValue / relatedAccounts.length;
    }

    // Controllers para valores médio e lançado
    final averageController =
        TextEditingController(text: UtilBrasilFields.obterReal(averageValue));
    final launchedValueController =
        TextEditingController(text: UtilBrasilFields.obterReal(averageValue));

    // Data padrão = próximo mês, mesmo dia do vencimento
    DateTime nextDate = DateTime(_startDate.year, _startDate.month + 1, rule.dueDay);
    if (nextDate.month > 12) {
      nextDate = DateTime(_startDate.year + 1, nextDate.month - 12, rule.dueDay);
    }

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
            label: const Text('LANÇAR'),
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

                final newAccount = Account(
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
                  observation: rule.observation,
                );

                final id = await DatabaseHelper.instance.createAccount(newAccount);
                debugPrint('✅ Parcela criada com ID: $id');

                if (mounted) {
                  Navigator.pop(ctx);
                          rec.ScaffoldMessenger.of(context).showSnackBar(
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
            label: const Text('LANÇAR'),
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
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NewExpenseDialog(card: card)),
    );
    if (result == true) {
      _refresh();
    }
  }

  Future<void> _showPaymentDialog() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentDialog(
          startDate: _startDate,
          endDate: _endDate,
        ),
      ),
    );
    if (result == true) {
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
      screenToOpen = RecurrentAccountEditScreen(account: account);
    } else {
      // Abrir tela normal de edição
      screenToOpen = AccountEditScreen(account: account);
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => screenToOpen),
    );

    if (result == true && mounted) {
      _refresh();
    }
  }

  Future<void> _confirmDelete(Account acc) async {
    if (acc.id == null) return;

    // Se é recorrente (PAI ou FILHA)
    if (acc.isRecurrent || acc.recurrenceId != null) {
      // Se é filha, carregar o pai para referência
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

      final option = await showDialog<int>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Excluir Recorrência'),
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
            TextButton(
              onPressed: () => Navigator.pop(ctx, 3),
              child: const Text('Apagar essa e futuras'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, 2),
              child: const Text('Apagar todas as recorrências'),
            ),
          ],
        ),
      );

      if (option == null || option == 0) return;

      if (option == 1) {
        // Apagar apenas esta parcela
        try {
          await DatabaseHelper.instance.deleteAccount(acc.id!);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Parcela excluída'),
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
      } else if (option == 3) {
        // Apagar atual e daqui pra frente
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
            final allAccounts =
                await DatabaseHelper.instance.readAllAccountsRaw();

            // Obter a data da parcela atual
            final currentDate = DateTime(acc.year ?? DateTime.now().year,
                acc.month ?? DateTime.now().month, 1);

            // Determinar qual recorrência estamos lidando
            final parentId = acc.recurrenceId ?? acc.id;

            // Apagar parcelas atuais e futuras (mes/ano >= mes/ano atual)
            final futureAccounts = allAccounts.where((a) {
              if (a.recurrenceId != parentId) return false;

              final accDate =
                  DateTime(a.year ?? DateTime.now().year, a.month ?? 1, 1);
              return accDate.isAtSameMomentAs(currentDate) ||
                  accDate.isAfter(currentDate);
            }).toList();

            for (final future in futureAccounts) {
              if (future.id != null) {
                debugPrint('🗑️ Apagando conta: ${future.description} (id=${future.id})');
                await DatabaseHelper.instance.deleteAccount(future.id!);
              }
            }

            debugPrint('✅ Total de ${futureAccounts.length} parcelas deletadas');

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Parcelas atuais e futuras excluídas'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
              debugPrint('📄 Atualizando tela...');
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
      } else if (option == 2) {
        // Apagar toda a recorrência (pai + filhas)
        final parentId = acc.recurrenceId ?? acc.id;
        final confirmAll = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmar'),
            content: Text(
              'Tem certeza que deseja excluir TODA a recorrência "${parent?.description ?? acc.description}"?\n\nIsso vai apagar a recorrência e TODAS as suas parcelas lançadas.',
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
            // Apagar todas as parcelas (filhas)
            final allAccounts =
                await DatabaseHelper.instance.readAllAccountsRaw();
            final relatedAccounts = allAccounts
                .where((a) => a.recurrenceId == parentId)
                .toList();

            for (final related in relatedAccounts) {
              if (related.id != null) {
                await DatabaseHelper.instance.deleteAccount(related.id!);
              }
            }

            // Apagar a recorrência (pai) - só se for a própria conta pai
            if (acc.isRecurrent && acc.recurrenceId == null) {
              await DatabaseHelper.instance.deleteAccount(acc.id!);
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
          title: const Text('Excluir Conta'),
          content: Text('Tem certeza que deseja excluir "${acc.description}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir'),
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

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildQuickAction(
                icon: Icons.receipt_long,
                label: 'Lançar Conta',
                color: Colors.blue.shade600,
                onTap: () async {
                  Navigator.pop(ctx);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AccountFormScreen()),
                  );
                  _refresh();
                },
              ),
              _buildQuickAction(
                icon: Icons.credit_card,
                label: 'Despesa Cartão',
                color: Colors.deepPurple.shade500,
                onTap: () {
                  Navigator.pop(ctx);
                  _startCardExpenseFlow();
                },
              ),
              _buildQuickAction(
                icon: Icons.payments,
                label: 'Lançar Pagamento',
                color: Colors.green.shade600,
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
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final fg = foregroundColorFor(color);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 110,
        height: 110,
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
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 30),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: 13,
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
