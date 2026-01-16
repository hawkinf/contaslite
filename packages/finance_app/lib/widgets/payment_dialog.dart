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
import '../utils/app_colors.dart';
import '../utils/color_contrast.dart';
import 'app_input_decoration.dart';

enum PaymentAccountType { regular, creditCard }

class PaymentDialog extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final Account? preselectedAccount;
  final bool isRecebimento;

  const PaymentDialog({
    required this.startDate,
    required this.endDate,
    this.preselectedAccount,
    this.isRecebimento = false,
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
  bool _inferredRecebimento = false;

  bool get _effectiveRecebimento => widget.isRecebimento || _inferredRecebimento;

  Color _resolveAppBarColor() {
    if (_selectedAccount?.cardColor != null) {
      return Color(_selectedAccount!.cardColor!);
    }
    return Theme.of(context).colorScheme.primary;
  }

  Color _resolveAppBarTextColor(Color background) {
    return foregroundColorFor(background);
  }

  Widget _buildCardBrandLogo(String? brand) {
    final normalized = (brand ?? '').trim().toUpperCase();
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
        width: 26,
        height: 16,
        fit: BoxFit.contain,
      );
    }

    return const Icon(Icons.credit_card, size: 16);
  }

  Widget _buildCardInvoiceRow(Account account, {Color? textColor}) {
    final color = textColor ?? Colors.grey.shade700;
    final dueDay = account.dueDay.toString().padLeft(2, '0');
    final brand = (account.cardBrand ?? 'Cartao').trim();
    final description = (account.cardBank ?? account.description).trim();
    return Row(
      children: [
        Text(
          dueDay,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 26, height: 16, child: _buildCardBrandLogo(account.cardBrand)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$brand $description',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _methodColor(String type) {
    switch (type) {
      case 'CREDIT_CARD':
        return AppColors.cardPurple;
      case 'PIX':
        return AppColors.success;
      case 'CASH':
        return AppColors.warning;
      case 'BANK_DEBIT':
        return AppColors.primary;
      default:
        return Colors.grey.shade700;
    }
  }

  Widget _buildPaymentMethodRow(PaymentMethod method, {Color? textColor}) {
    final color = textColor ?? Colors.grey.shade800;
    final logo = method.logo?.trim();
    final iconColor = _methodColor(method.type);
    return Row(
      children: [
        if (logo != null && logo.isNotEmpty)
          Text(
            logo,
            style: const TextStyle(fontSize: 18),
          )
        else
          Icon(method.icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            method.name,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentCardRow(Account card, {Color? textColor}) {
    final color = textColor ?? Colors.grey.shade700;
    final dueDay = card.dueDay.toString().padLeft(2, '0');
    final brand = (card.cardBrand ?? 'Cartao').trim();
    final description = (card.cardBank ?? card.description).trim();
    return Row(
      children: [
        SizedBox(width: 26, height: 16, child: _buildCardBrandLogo(card.cardBrand)),
        const SizedBox(width: 8),
        Text(
          dueDay,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$brand $description',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

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
      final types = await DatabaseHelper.instance.readAllTypes();
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

      // Resolver conta inicial ANTES do setState, usando as listas locais
      Account? initialAccount;
      DateTime? lockedDueDate;
      String? lockedWarning;
      DateTime? lockedPaymentDate;
      
      bool inferredRecebimento = _inferredRecebimento;
      if (widget.preselectedAccount != null) {
        final preferred = widget.preselectedAccount!;
        final isCard = preferred.cardBrand != null;
        final targetList = isCard ? cardInvoices : regularAccounts;
        
        // Buscar por ID primeiro
        Account? match;
        if (preferred.id != null) {
          for (final acc in targetList) {
            if (acc.id == preferred.id) {
              match = acc;
              break;
            }
          }
        }
        
        // Se não encontrou por ID, usar a conta pré-selecionada diretamente
        // A conta pode não estar na lista (já paga ou outro motivo)
        match ??= preferred;
        
        initialAccount = match;
        _accountType = isCard ? PaymentAccountType.creditCard : PaymentAccountType.regular;
        if (!_effectiveRecebimento) {
          final type = types.where((t) => t.id == preferred.typeId).toList();
          if (type.isNotEmpty && type.first.name.toLowerCase().contains('receb')) {
            inferredRecebimento = true;
          }
        }
      }
      final effectiveRecebimento = widget.isRecebimento || inferredRecebimento;
      final filteredPaymentMethods = paymentMethods
          .where((m) => effectiveRecebimento
              ? m.supportsRecebimentos
              : m.supportsPagamentos)
          .toList();
      
      // Fallback para primeira conta disponível
      if (initialAccount == null) {
        if (regularAccounts.isNotEmpty) {
          initialAccount = regularAccounts.first;
          _accountType = PaymentAccountType.regular;
        } else if (cardInvoices.isNotEmpty) {
          initialAccount = cardInvoices.first;
          _accountType = PaymentAccountType.creditCard;
        }
      }
      
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
          _paymentMethods = filteredPaymentMethods;
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
          _inferredRecebimento = inferredRecebimento;
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
    final formattedOriginal = DateFormat('dd/MM/yyyy').format(original);
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
      description:
          '${_effectiveRecebimento ? 'Recebimento' : 'Pagamento'}: ${_selectedAccount!.description}',
      value: _selectedAccount!.value,
      dueDay: card.dueDay,
      month: month,
      year: year,
      cardId: card.id,
      cardBrand: card.cardBrand,
      cardBank: card.cardBank,
      establishment: _selectedAccount!.description,
      observation: _effectiveRecebimento
          ? 'Recebimento via cartão de crédito'
          : 'Pagamento via cartão de crédito',
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
    final label = isRegular
        ? (_effectiveRecebimento
            ? 'Conta a receber selecionada'
            : 'Conta a pagar selecionada')
        : 'Fatura do Cartão';

    if (_isAccountLocked && _selectedAccount != null) {
      if (!isRegular) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InputDecorator(
              decoration: buildOutlinedInputDecoration(
                label: 'Fatura do Cartão',
                icon: Icons.credit_card,
              ).copyWith(
                enabled: false,
              ),
              child: _buildCardInvoiceRow(
                _selectedAccount!,
                textColor: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            _buildDueDateField(useLocked: true),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InputDecorator(
            decoration: buildOutlinedInputDecoration(
              label: isRegular
                  ? (_effectiveRecebimento ? 'Conta a receber selecionada' : 'Conta a pagar selecionada')
                  : 'Fatura selecionada',
              icon: isRegular ? Icons.receipt : Icons.credit_card,
            ).copyWith(enabled: false),
            child: Text(
              _accountDisplayLabel(_selectedAccount!),
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(height: 12),
          _buildDueDateField(useLocked: true),
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
          ? (_effectiveRecebimento
              ? 'Nenhuma conta a receber pendente neste mês.'
              : 'Nenhuma conta a pagar pendente neste mês.')
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isRegular)
          DropdownButtonFormField<Account>(
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
          )
        else
          DropdownButtonFormField<Account>(
            initialValue: currentValue,
            isExpanded: true,
            decoration: buildOutlinedInputDecoration(
              label: 'Fatura do Cartão',
              icon: Icons.credit_card,
            ),
            items: list
                .map((account) => DropdownMenuItem(
                      value: account,
                      child: _buildCardInvoiceRow(
                        account,
                        textColor: Colors.grey.shade700,
                      ),
                    ))
                .toList(),
            selectedItemBuilder: (context) => list
                .map((account) => _buildCardInvoiceRow(
                      account,
                      textColor: Colors.grey.shade700,
                    ))
                .toList(),
            onChanged: null,
          ),
        const SizedBox(height: 12),
        _buildDueDateField(account: currentValue),
      ],
    );
  }

  Widget _buildDueDateField({Account? account, bool useLocked = false}) {
    final effectiveAccount = account ?? _selectedAccount;
    DateTime? dueDate;
    if (useLocked) {
      dueDate = _lockedDueDate;
    } else if (effectiveAccount != null) {
      dueDate = _getAccountDueDate(effectiveAccount);
    }
    final label = _effectiveRecebimento ? 'Recebimento' : 'Vencimento';
    final text = dueDate != null ? DateFormat('dd/MM/yyyy').format(dueDate) : '-';
    return TextFormField(
      initialValue: text,
      enabled: false,
      decoration: buildOutlinedInputDecoration(
        label: label,
        icon: Icons.event,
      ).copyWith(
        helperText: useLocked ? _lockedDueDateWarning : null,
      ),
    );
  }

  Future<void> _savePayment() async {
    // Validações
    if (_selectedAccount == null) {
      _showError(_effectiveRecebimento
          ? 'Selecione uma conta a receber'
          : 'Selecione uma conta a pagar');
      return;
    }

    if (_selectedMethod == null) {
      _showError(_effectiveRecebimento
          ? 'Selecione uma forma de recebimento'
          : 'Selecione uma forma de pagamento');
      return;
    }

    if ((_selectedMethod!.requiresBank ||
            _selectedMethod!.type == 'PIX' ||
            _selectedMethod!.type == 'BANK_DEBIT') &&
        _selectedBank == null) {
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

      debugPrint('💰 Salvando pagamento: accountId=${payment.accountId}, value=${payment.value}, date=${payment.paymentDate}');
      
      // Salvar no banco
      final paymentId = await DatabaseHelper.instance.createPayment(payment);
      debugPrint('💰 Pagamento salvo com ID: $paymentId');

      // Se for cartão de crédito, lançar despesa no cartão
      if (_selectedMethod!.type == 'CREDIT_CARD') {
        await _launchCardExpense();
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao salvar pagamento: $e');
      debugPrint('Stack: $stackTrace');
      _showError(_effectiveRecebimento
          ? 'Erro ao salvar recebimento: $e'
          : 'Erro ao salvar pagamento: $e');
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
      final appBarColor = _resolveAppBarColor();
      final appBarFg = _resolveAppBarTextColor(appBarColor);
      return Scaffold(
        appBar: AppBar(
          title:
              Text(_effectiveRecebimento ? 'Lançar Recebimento' : 'Lançar Pagamento'),
          backgroundColor: appBarColor,
          foregroundColor: appBarFg,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final appBarColor = _resolveAppBarColor();
    final appBarFg = _resolveAppBarTextColor(appBarColor);

    return Scaffold(
      appBar: AppBar(
        title:
            Text(_effectiveRecebimento ? 'Lançar Recebimento' : 'Lançar Pagamento'),
        elevation: 0,
        backgroundColor: appBarColor,
        foregroundColor: appBarFg,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Tipo de Conta',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 480;
              final amountBox = _selectedAccount != null
                  ? IntrinsicWidth(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        constraints: const BoxConstraints(minWidth: 220, minHeight: 48),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _effectiveRecebimento ? Colors.blue : Colors.red,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _effectiveRecebimento ? 'Total a Receber' : 'Total a Pagar',
                              style: TextStyle(
                                color: _effectiveRecebimento ? Colors.blue : Colors.red,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  UtilBrasilFields.obterReal(_selectedAccount?.value ?? 0.0),
                                  style: TextStyle(
                                    color: _effectiveRecebimento ? Colors.blue : Colors.red,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 45,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink();
              return isCompact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
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
                        if (_selectedAccount != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: amountBox,
                          ),
                        ],
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
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
                        ),
                        if (_selectedAccount != null) ...[
                          const SizedBox(width: 12),
                          amountBox,
                        ],
                      ],
                    );
            },
          ),
          const SizedBox(height: 12),
          Text(
            _accountType == PaymentAccountType.regular
                ? (_effectiveRecebimento ? 'Conta a Receber' : 'Conta a Pagar')
                : 'Fatura do Cartão',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          _buildAccountSelector(),
          const SizedBox(height: 24),

          // Seção: Data do Pagamento/Recebimento
          Text(
            _effectiveRecebimento ? 'Data do Recebimento' : 'Data do Pagamento',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _selectDate,
            child: InputDecorator(
              decoration: buildOutlinedInputDecoration(
                label:
                    _effectiveRecebimento ? 'Data do Recebimento' : 'Data do Pagamento',
                icon: Icons.calendar_today,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('dd/MM/yyyy').format(_paymentDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Icon(Icons.calendar_month, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Seção: Forma de Pagamento
          Text(
            _effectiveRecebimento ? 'Forma de Recebimento' : 'Forma de Pagamento',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PaymentMethod>(
            initialValue: _selectedMethod,
            isExpanded: true,
            decoration: buildOutlinedInputDecoration(
              label: _effectiveRecebimento
                  ? 'Selecione a forma de recebimento'
                  : 'Selecione a forma de pagamento',
              icon: Icons.payment,
            ),
            items: _paymentMethods
                .map((method) => DropdownMenuItem(
                      value: method,
                      child: _buildPaymentMethodRow(method),
                    ))
                .toList(),
            selectedItemBuilder: (context) =>
                _paymentMethods.map((method) => _buildPaymentMethodRow(method)).toList(),
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
            if (_selectedMethod != null &&
              (_selectedMethod!.requiresBank ||
                _selectedMethod!.type == 'PIX' ||
                _selectedMethod!.type == 'BANK_DEBIT')) ...[
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
              isExpanded: true,
              decoration: buildOutlinedInputDecoration(
                label: 'Selecione um cartão',
                icon: Icons.credit_card,
              ),
              items: (_paymentCards..sort((a, b) => a.dueDay.compareTo(b.dueDay)))
                  .map((card) => DropdownMenuItem(
                        value: card,
                        child: _buildPaymentCardRow(card),
                      ))
                  .toList(),
              selectedItemBuilder: (context) => (_paymentCards..sort((a, b) => a.dueDay.compareTo(b.dueDay)))
                  .map((card) => _buildPaymentCardRow(card))
                  .toList(),
              onChanged: (card) {
                setState(() {
                  _selectedCard = card;
                });
              },
            ),
            const SizedBox(height: 24),
          ],

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
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('Cancelar'),
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _savePayment,
                  icon: const Icon(Icons.check_circle, size: 24),
                  label: const Text(
                    'Gravar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
                    backgroundColor: Colors.green.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
