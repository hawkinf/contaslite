import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:brasil_fields/brasil_fields.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../models/bank_account.dart';
import '../models/payment.dart';
import '../models/payment_method.dart';
import '../services/holiday_service.dart';
import '../services/prefs_service.dart';
import 'app_input_decoration.dart';

enum PaymentAccountType { regular, creditCard }

class PaymentDialog extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final Account? preselectedAccount;

  const PaymentDialog({
    required this.startDate,
    required this.endDate,
    this.preselectedAccount,
    super.key,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  List<Account> _regularAccounts = [];
  List<Account> _cardInvoices = [];
  List<Account> _paymentCards = [];
  late List<PaymentMethod> _paymentMethods = [];
  late List<BankAccount> _banks = [];

  Account? _selectedAccount;
  PaymentMethod? _selectedMethod;
  BankAccount? _selectedBank;
  Account? _selectedCard;
  DateTime _paymentDate = DateTime.now();
  PaymentAccountType _accountType = PaymentAccountType.regular;
  late final bool _isAccountLocked;
  DateTime? _lockedDueDate;
  String? _lockedDueDateWarning;

  final _observationController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
     _isAccountLocked = widget.preselectedAccount != null;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final accounts = await DatabaseHelper.instance.getAccountsByDateRange(
        widget.startDate,
        widget.endDate,
      );
      final paymentMethods = await DatabaseHelper.instance.readPaymentMethods();
      final banks = await DatabaseHelper.instance.readBankAccounts();
      final cards = await DatabaseHelper.instance.readAllCards();

      final accountIds = <int>[];
      for (final acc in accounts) {
        if (acc.id != null) accountIds.add(acc.id!);
      }
      for (final card in cards) {
        if (card.id != null) accountIds.add(card.id!);
      }

      final paymentsMap = await DatabaseHelper.instance
          .getPaymentsForAccountsByMonth(
              accountIds, widget.startDate.month, widget.startDate.year);

      final regularAccounts = accounts
          .where((a) =>
              a.cardBrand == null &&
              !a.isRecurrent &&
              a.id != null &&
              !paymentsMap.containsKey(a.id!))
          .toList()
        ..sort((a, b) {
          final aDate = DateTime(
              a.year ?? widget.startDate.year,
              a.month ?? widget.startDate.month,
              a.dueDay);
          final bDate = DateTime(
              b.year ?? widget.startDate.year,
              b.month ?? widget.startDate.month,
              b.dueDay);
          return aDate.compareTo(bDate);
        });

      final cardInvoices = <Account>[];
      for (final card in cards) {
        if (card.id == null) continue;
        final invoiceValue = await _calculateCardInvoiceValue(card);
        if (invoiceValue <= 0) continue;
        if (paymentsMap.containsKey(card.id!)) continue;
        cardInvoices.add(card.copyWith(
          value: invoiceValue,
          month: widget.startDate.month,
          year: widget.startDate.year,
        ));
      }
      cardInvoices.sort((a, b) => a.dueDay.compareTo(b.dueDay));

      final initialAccount = _resolveInitialSelectedAccount(widget.preselectedAccount);
      DateTime? lockedDueDate;
      String? lockedWarning;
      DateTime? lockedPaymentDate;
      if (_isAccountLocked && initialAccount != null) {
        final dueInfo = _getAccountDueDate(initialAccount);
        final adjustment = _applyBusinessRules(initialAccount, dueInfo);
        lockedDueDate = dueInfo;
        lockedWarning = adjustment.warning;
        lockedPaymentDate = adjustment.date;
      }

      if (mounted) {
        setState(() {
          _regularAccounts = regularAccounts;
          _cardInvoices = cardInvoices;
          _paymentMethods = paymentMethods;
          _banks = banks;
          _paymentCards = cards;
          _selectedAccount = initialAccount;
          _selectedCard = null;
          _lockedDueDate = lockedDueDate;
          _lockedDueDateWarning = lockedWarning;
          if (lockedPaymentDate != null) {
            _paymentDate = lockedPaymentDate;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
    }
  }

  Account? _resolveInitialSelectedAccount([Account? preferred]) {
    if (preferred != null) {
      final isCard = preferred.cardBrand != null;
      final targetList = isCard ? _cardInvoices : _regularAccounts;
      final match = _findMatchingAccount(preferred, targetList);

      if (match != null) {
        _accountType =
            isCard ? PaymentAccountType.creditCard : PaymentAccountType.regular;
        return match;
      }
    }

    final currentList = _accountType == PaymentAccountType.regular
        ? _regularAccounts
        : _cardInvoices;
    if (currentList.isNotEmpty) {
      return currentList.first;
    }
    final fallbackList = _accountType == PaymentAccountType.regular
        ? _cardInvoices
        : _regularAccounts;
    if (fallbackList.isNotEmpty) {
      _accountType = _accountType == PaymentAccountType.regular
          ? PaymentAccountType.creditCard
          : PaymentAccountType.regular;
      return fallbackList.first;
    }
    return null;
  }

  Account? _findMatchingAccount(Account needle, List<Account> source) {
    if (needle.id != null) {
      for (final acc in source) {
        if (acc.id == needle.id) return acc;
      }
    }
    final normalizedDesc = needle.description.trim().toLowerCase();
    final targetMonth = needle.month ?? widget.startDate.month;
    final targetYear = needle.year ?? widget.startDate.year;
    for (final acc in source) {
      final sameDesc = acc.description.trim().toLowerCase() == normalizedDesc;
      final sameDay = acc.dueDay == needle.dueDay;
      final sameMonth = (acc.month ?? widget.startDate.month) == targetMonth;
      final sameYear = (acc.year ?? widget.startDate.year) == targetYear;
      if (sameDesc && sameDay && sameMonth && sameYear) {
        return acc;
      }
    }
    return null;
  }

  DateTime _getAccountDueDate(Account account) {
    final year = account.year ?? widget.startDate.year;
    final month = account.month ?? widget.startDate.month;
    return DateTime(year, month, account.dueDay);
  }

  ({DateTime date, String? warning}) _applyBusinessRules(
      Account account, DateTime original) {
    final city = PrefsService.cityNotifier.value;
    DateTime adjusted = original;
    final bool isWeekend = HolidayService.isWeekend(original);
    final bool isHoliday = HolidayService.isHoliday(original, city);
    final bool needsAdjustment = isWeekend || isHoliday;
    if (!needsAdjustment) {
      return (date: original, warning: null);
    }

    if (account.payInAdvance) {
      while (HolidayService.isWeekend(adjusted) ||
          HolidayService.isHoliday(adjusted, city)) {
        adjusted = adjusted.subtract(const Duration(days: 1));
      }
    } else {
      while (HolidayService.isWeekend(adjusted) ||
          HolidayService.isHoliday(adjusted, city)) {
        adjusted = adjusted.add(const Duration(days: 1));
      }
    }

    String reason;
    if (isWeekend && isHoliday) {
      reason = 'Feriado/Fim de Semana';
    } else if (isHoliday) {
      reason = 'Feriado';
    } else {
      reason = 'Final de Semana';
    }
    final direction = account.payInAdvance ? 'Antecipado' : 'Postergado';
    final formattedOriginal = DateFormat('dd/MM/yy').format(original);
    return (
      date: adjusted,
      warning: 'Original $formattedOriginal • $reason • $direction',
    );
  }

  Future<double> _calculateCardInvoiceValue(Account card) async {
    if (card.id == null) return 0.0;
    final expenses = await DatabaseHelper.instance.getCardExpensesForMonth(
        card.id!, widget.startDate.month, widget.startDate.year);
    double total = 0.0;
    for (final expense in expenses) {
      total += expense.value;
    }
    return total;
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _paymentDate = date;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  Future<void> _launchCardExpense() async {
    final card = _selectedCard;
    if (card == null || _selectedAccount == null) return;

    // Calcular mês da fatura (baseado no melhor dia de compra do cartão)
    final referenceDate = _paymentDate;
    final bestBuyDay = card.bestBuyDay ?? 1;

    int month, year;
    if (referenceDate.day <= bestBuyDay) {
      month = referenceDate.month;
      year = referenceDate.year;
    } else {
      final nextMonth = DateTime(referenceDate.year, referenceDate.month + 1, 1);
      month = nextMonth.month;
      year = nextMonth.year;
    }

    // Criar despesa no cartão
    final expense = Account(
      typeId: card.typeId,
      description: 'Pagamento: ${_selectedAccount!.description}',
      value: _selectedAccount!.value,
      dueDay: card.dueDay,
      month: month,
      year: year,
      cardId: card.id,
      cardBrand: card.cardBrand,
      cardBank: card.cardBank,
      establishment: _selectedAccount!.description,
      observation: 'Pagamento via cartão de crédito',
      purchaseDate: _paymentDate.toIso8601String(),
      creationDate: DateTime.now().toIso8601String(),
      isRecurrent: false,
      payInAdvance: false,
    );

    await DatabaseHelper.instance.createAccount(expense);
  }

  void _onAccountTypeChanged(PaymentAccountType type) {
    if (_accountType == type) return;
    if (_isAccountLocked) return;
    setState(() {
      _accountType = type;
      final list = _accountType == PaymentAccountType.regular
          ? _regularAccounts
          : _cardInvoices;
      _selectedAccount = list.isNotEmpty ? list.first : null;
    });
  }

  List<Account> get _currentAccountList => _accountType == PaymentAccountType.regular
      ? _regularAccounts
      : _cardInvoices;

  String _accountDisplayLabel(Account account) {
    final dueDate = DateTime(
        account.year ?? widget.startDate.year,
        account.month ?? widget.startDate.month,
        account.dueDay);
    final dateText = DateFormat('dd/MM').format(dueDate);
    final valueText = UtilBrasilFields.obterReal(account.value);
    if (_accountType == PaymentAccountType.regular) {
      return '$dateText · ${account.description} — $valueText';
    }
    final cardName = (account.cardBank ?? account.description).trim();
    final dueDayText = dueDate.day.toString().padLeft(2, '0');
    final bestDay = (account.bestBuyDay ?? 1).toString().padLeft(2, '0');
    return '$dueDayText – $cardName (Melhor dia: $bestDay) — $valueText';
  }

  Widget _buildAccountSelector() {
    final list = _currentAccountList;
    final isRegular = _accountType == PaymentAccountType.regular;
    final label =
        isRegular ? 'Selecione a conta' : 'Selecione o cartão de crédito';

    if (_isAccountLocked && _selectedAccount != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            initialValue: _accountDisplayLabel(_selectedAccount!),
            enabled: false,
            decoration: buildOutlinedInputDecoration(
              label: isRegular ? 'Conta selecionada' : 'Fatura selecionada',
              icon: isRegular ? Icons.receipt : Icons.credit_card,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _lockedDueDate != null
                ? DateFormat('dd/MM/yy').format(_lockedDueDate!)
                : '-',
            enabled: false,
            decoration: buildOutlinedInputDecoration(
              label: 'Vencimento',
              icon: Icons.event,
            ).copyWith(
              helperText: _lockedDueDateWarning,
            ),
          ),
        ],
      );
    }

    if (list.isEmpty) {
      if (_selectedAccount != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _selectedAccount = null);
          }
        });
      }
      final emptyMessage = isRegular
          ? 'Nenhuma conta avulsa pendente neste mês.'
          : 'Nenhuma fatura de cartão pendente neste mês.';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.grey.shade100,
        ),
        child: Text(
          emptyMessage,
          style: TextStyle(color: Colors.grey.shade700),
        ),
      );
    }

    final currentValue =
        list.contains(_selectedAccount) ? _selectedAccount : list.first;
    if (_selectedAccount != currentValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedAccount = currentValue);
        }
      });
    }

    return DropdownButtonFormField<Account>(
      initialValue: currentValue,
      decoration: buildOutlinedInputDecoration(
        label: label,
        icon: isRegular ? Icons.receipt : Icons.credit_card,
      ),
      items: list
          .map((account) => DropdownMenuItem(
                value: account,
                child: Text(_accountDisplayLabel(account)),
              ))
          .toList(),
      onChanged: (account) {
        setState(() {
          _selectedAccount = account;
        });
      },
    );
  }

  Future<void> _savePayment() async {
    // Validações
    if (_selectedAccount == null) {
      _showError('Selecione uma conta');
      return;
    }

    if (_selectedMethod == null) {
      _showError('Selecione uma forma de pagamento');
      return;
    }

    if (_selectedMethod!.requiresBank && _selectedBank == null) {
      _showError('Selecione um banco');
      return;
    }

    if (_selectedMethod!.type == 'CREDIT_CARD' && _selectedCard == null) {
      _showError('Selecione um cartão');
      return;
    }

    try {
      // Criar Payment
      final payment = Payment(
        accountId: _selectedAccount!.id!,
        paymentMethodId: _selectedMethod!.id!,
        bankAccountId: _selectedBank?.id,
        creditCardId: _selectedCard?.id,
        value: _selectedAccount!.value,
        paymentDate: _paymentDate.toIso8601String(),
        observation: _observationController.text.trim().isNotEmpty
            ? _observationController.text.trim()
            : null,
        createdAt: DateTime.now().toIso8601String(),
      );

      // Salvar no banco
      await DatabaseHelper.instance.createPayment(payment);

      // Se for cartão de crédito, lançar despesa no cartão
      if (_selectedMethod!.type == 'CREDIT_CARD') {
        await _launchCardExpense();
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Erro ao salvar pagamento: $e');
    }
  }

  @override
  void dispose() {
    _observationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lançar Pagamento')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lançar Pagamento'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cabeçalho com mês/ano
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Center(
                child: Text(
                  DateFormat('MMMM yyyy', 'pt_BR')
                      .format(widget.startDate)
                      .toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Tipo de Conta',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Conta Avulsa'),
                selected: _accountType == PaymentAccountType.regular,
                onSelected: _isAccountLocked
                    ? null
                    : (_) => _onAccountTypeChanged(PaymentAccountType.regular),
              ),
              ChoiceChip(
                label: const Text('Cartão de Crédito'),
                selected: _accountType == PaymentAccountType.creditCard,
                onSelected: _isAccountLocked
                    ? null
                    : (_) =>
                        _onAccountTypeChanged(PaymentAccountType.creditCard),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _accountType == PaymentAccountType.regular
                ? 'Conta a Pagar'
                : 'Fatura do Cartão',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          _buildAccountSelector(),
          const SizedBox(height: 24),

          // Seção: Forma de Pagamento
          Text(
            'Forma de Pagamento',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PaymentMethod>(
            initialValue: _selectedMethod,
            decoration: buildOutlinedInputDecoration(
              label: 'Selecione a forma de pagamento',
              icon: Icons.payment,
            ),
            items: _paymentMethods
                .map((method) => DropdownMenuItem(
                      value: method,
                      child: Text(method.name),
                    ))
                .toList(),
            onChanged: (method) {
              setState(() {
                _selectedMethod = method;
                // Reset campos condicionais
                _selectedBank = null;
                _selectedCard = null;
              });
            },
          ),
          const SizedBox(height: 24),

          // Seção Condicional: Banco (PIX ou Débito C/C)
          if (_selectedMethod != null && _selectedMethod!.requiresBank) ...[
            Text(
              'Conta Bancária',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<BankAccount>(
              initialValue: _selectedBank,
              decoration: buildOutlinedInputDecoration(
                label: 'Selecione um banco',
                icon: Icons.account_balance,
              ),
              items: _banks
                  .map((bank) => DropdownMenuItem(
                        value: bank,
                        child: Text('${bank.name} - ${bank.account}'),
                      ))
                  .toList(),
              onChanged: (bank) {
                setState(() {
                  _selectedBank = bank;
                });
              },
            ),
            const SizedBox(height: 24),
          ],

          // Seção Condicional: Cartão (Cartão Crédito)
          if (_selectedMethod != null && _selectedMethod!.type == 'CREDIT_CARD') ...[
            Text(
              'Cartão de Crédito',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Account>(
              initialValue: _selectedCard,
              decoration: buildOutlinedInputDecoration(
                label: 'Selecione um cartão',
                icon: Icons.credit_card,
              ),
              items: _paymentCards
                  .map((card) => DropdownMenuItem(
                        value: card,
                        child: Text(
                          '${card.cardBank} - ${card.description}',
                        ),
                      ))
                  .toList(),
              onChanged: (card) {
                setState(() {
                  _selectedCard = card;
                });
              },
            ),
            const SizedBox(height: 24),
          ],

          // Seção: Data do Pagamento
          Text(
            'Data do Pagamento',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: buildOutlinedInputDecoration(
              label: 'Data do Pagamento',
              icon: Icons.calendar_today,
            ),
            readOnly: true,
            enabled: !_isAccountLocked,
            controller: TextEditingController(
              text: DateFormat('dd/MM/yyyy').format(_paymentDate),
            ),
            onTap: _isAccountLocked ? null : _selectDate,
          ),
          const SizedBox(height: 24),

          // Seção: Observações
          Text(
            'Observações (opcional)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _observationController,
            decoration: buildOutlinedInputDecoration(
              label: 'Observações',
              icon: Icons.note,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 80), // Espaço para botão flutuante
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _savePayment,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Registrar Pagamento'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: Colors.green.shade600,
            ),
          ),
        ),
      ),
    );
  }
}
