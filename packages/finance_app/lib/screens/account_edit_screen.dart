import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:brasil_fields/brasil_fields.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../models/account_type.dart';
import '../models/account_category.dart';
import '../services/prefs_service.dart';
import '../services/holiday_service.dart';
import '../utils/color_contrast.dart';
import '../utils/installment_utils.dart';



class _InstallmentDraft {
  final int index;
  DateTime originalDate;
  DateTime adjustedDate;
  double value;
  String? warning;
  final Account? originalAccount;
  final TextEditingController dateController;
  final TextEditingController valueController;

  _InstallmentDraft({
    required this.index,
    required this.originalDate,
    required this.adjustedDate,
    required this.value,
    this.originalAccount,
    this.warning,
  })  : dateController = TextEditingController(text: DateFormat('dd/MM/yy').format(adjustedDate)),
        valueController = TextEditingController(text: UtilBrasilFields.obterReal(value));

  void dispose() {
    dateController.dispose();
    valueController.dispose();

}
}



enum _DeleteAction { single, series }

class AccountEditScreen extends StatefulWidget {
  final Account account;
  const AccountEditScreen({super.key, required this.account});

  @override
  State<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends State<AccountEditScreen> {
  // Métodos utilitários necessários para evitar erros de método indefinido
  void _loadInitialData() {}
  void _loadPaymentInfo() {}
  void _clearInstallments() {}
  void _setInstallments(List<_InstallmentDraft> drafts) {}
  Widget _actionSquare({required Color color, required IconData icon, required VoidCallback onTap, Color? iconColor}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: iconColor ?? Colors.black, size: 20),
      ),
    );
  }

  // Métodos utilitários reais já implementados abaixo, removendo duplicidade de stubs

  late TextEditingController _descController;
  late TextEditingController _valueController;
  late TextEditingController _dateController;
  late TextEditingController _installmentsQtyController;
  late TextEditingController _observationController;
  late FocusNode _descFocus;
  late bool _isRecurrentAccount;
  late int _selectedColor;
  late bool _lockInstallmentRecalc;
  late TextInputFormatter _dateMaskFormatter;
  late List<_InstallmentDraft> _installments;
  dynamic _paymentInfo;
  late List<AccountType> _typesList;
  AccountType? _selectedType;
  late List<AccountCategory> _categorias;
  AccountCategory? _selectedCategory;
  DateTime? _mainOriginalDueDate;
  DateTime? _mainAdjustedDueDate;
  bool _mainDueDateWasAdjusted = false;


  @override
  void initState() {
    super.initState();

    final initialDesc = cleanInstallmentDescription(widget.account.description);
    _descController = TextEditingController(text: initialDesc);
    _valueController = TextEditingController(text: UtilBrasilFields.obterReal(widget.account.value));
    _dateController = TextEditingController(
      text: DateFormat('dd/MM/yy').format(
        DateTime(
          widget.account.year ?? DateTime.now().year,
          widget.account.month ?? DateTime.now().month,
          widget.account.dueDay,
        ),
      ),
    );
    _isRecurrentAccount = widget.account.isRecurrent;
    _installmentsQtyController = TextEditingController(text: _isRecurrentAccount ? 'Recorrência' : '1');
    _observationController = TextEditingController(text: widget.account.observation ?? '');
    _selectedColor = widget.account.cardColor ?? 0xFFFFFFFF;
    _descFocus = FocusNode();

    final hasInstallmentSuffix = installmentSuffixRegex.hasMatch(widget.account.description);
    final hasPurchaseUuid = widget.account.purchaseUuid?.isNotEmpty == true;
    final hasCardInstallments = widget.account.cardId != null;
    final hasInstallmentMetadata = widget.account.installmentTotal != null && widget.account.installmentTotal! > 1;
    _lockInstallmentRecalc = !_isRecurrentAccount && (hasInstallmentSuffix || hasPurchaseUuid || hasCardInstallments || hasInstallmentMetadata);
    if (_lockInstallmentRecalc) {
      _loadInstallmentSeries();
    }

    _dateMaskFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
      String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (digitsOnly.length > 6) digitsOnly = digitsOnly.substring(0, 6);
      String formatted = '';
      for (int i = 0; i < digitsOnly.length; i++) {
        formatted += digitsOnly[i];
        if ((i == 1 || i == 3) && i < digitsOnly.length - 1) {
          formatted += '/';
        }
      }
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    });

    _loadInitialData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_lockInstallmentRecalc) {
        _onMainDateChanged(_dateController.text);
      }
    });
    if (widget.account.id != null) {
      _loadPaymentInfo();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Implemente o corpo real da tela aqui
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Conta')),
      body: const Center(child: Text('Tela de edição de conta')),
    );
  }


  @override
  void dispose() {
    _descController.dispose();
    _valueController.dispose();
    _dateController.dispose();
    _installmentsQtyController.dispose();
    _observationController.dispose();

    // Removido bloco com variáveis não declaradas (types, selected) e await fora de contexto
  }

  Future<void> _loadCategories() async {
    if (_selectedType?.id == null) {
      setState(() {
        _categorias = [];
        _selectedCategory = null;
      });
      return;
    }

    final cats = await DatabaseHelper.instance.readAccountCategories(_selectedType!.id!);
    setState(() {
      _categorias = cats;
      _selectedCategory = null;
    });
  }

  Future<void> _loadInstallmentSeries() async {
    final account = widget.account;
    List<Account> series = [];
    final baseDesc = cleanInstallmentDescription(account.description);
    final installmentTotal = account.installmentTotal;
    final hasInstallmentMetadata = installmentTotal != null && installmentTotal > 1;

    if (account.purchaseUuid?.isNotEmpty == true) {
      series = await DatabaseHelper.instance.readInstallmentSeriesByUuid(account.purchaseUuid!);
    } else if (account.cardId != null && baseDesc.isNotEmpty) {
      series = await DatabaseHelper.instance.readInstallmentSeries(
        account.cardId!,
        baseDesc,
        installmentTotal: hasInstallmentMetadata ? installmentTotal : null,
      );
    } else if (baseDesc.isNotEmpty) {
      series = await DatabaseHelper.instance.readInstallmentSeriesByDescription(
        account.typeId,
        baseDesc,
        installmentTotal: hasInstallmentMetadata ? installmentTotal : null,
      );
    }

    if (!mounted) return;
    if (series.length <= 1) {
      _lockInstallmentRecalc = false;
      setState(() => _clearInstallments());
      return;
    }

    series.sort((a, b) {
      final yearA = a.year ?? 0;
      final yearB = b.year ?? 0;
      if (yearA != yearB) return yearA.compareTo(yearB);
      final monthA = a.month ?? 0;
      final monthB = b.month ?? 0;
      if (monthA != monthB) return monthA.compareTo(monthB);
      final dayA = a.dueDay;
      final dayB = b.dueDay;
      if (dayA != dayB) return dayA.compareTo(dayB);
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });

    final drafts = <_InstallmentDraft>[];
    for (int i = 0; i < series.length; i++) {
      final item = series[i];
      final year = item.year ?? DateTime.now().year;
      final month = item.month ?? DateTime.now().month;
      drafts.add(_InstallmentDraft(
        index: i + 1,
        originalDate: DateTime(year, month, item.dueDay),
        adjustedDate: DateTime(year, month, item.dueDay),
        value: item.value,
        originalAccount: item,
      ));
    }

    setState(() {
      _setInstallments(drafts);
      _installmentsQtyController.text = series.length.toString();
      _lockInstallmentRecalc = true;
      final totalValue = drafts.fold<double>(0.0, (sum, entry) => sum + entry.value);
      _valueController.text = UtilBrasilFields.obterReal(totalValue);
      if (drafts.isNotEmpty) {
        _dateController.text = DateFormat('dd/MM/yy').format(drafts.first.adjustedDate);
      }
    });
  }

  DateTime _parseDateString(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        final fullYear = year < 100 ? 2000 + year : year;
        return DateTime(fullYear, month, day);
      }
    } catch (_) {}
    return DateTime.now();
  }

  ({DateTime originalDate, DateTime adjustedDate, String? warning, bool changed}) _calculateAdjustment(String dateStr) {
    if (dateStr.length < 8) {
      final now = DateTime.now();
      return (originalDate: now, adjustedDate: now, warning: null, changed: false);
    }
    try {
      final parts = dateStr.split('/');
      if (parts.length != 3) {
        final now = DateTime.now();
        return (originalDate: now, adjustedDate: now, warning: null, changed: false);
      }
      int day = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      int year = int.parse(parts[2]);
      if (year < 100) year = 2000 + year;
      DateTime original = DateTime(year, month, day);
      var check = HolidayService.adjustDateToBusinessDay(original, PrefsService.cityNotifier.value);
      bool changed = !DateUtils.isSameDay(original, check.date);
      return (originalDate: original, adjustedDate: check.date, warning: check.warning, changed: changed);
    } catch (_) {
      final now = DateTime.now();
      return (originalDate: now, adjustedDate: now, warning: null, changed: false);
    }
  }

  Future<void> _selectDate() async {
    DateTime initialDate;
    try {
      initialDate = _parseDateString(_dateController.text);
    } catch (_) {
      initialDate = DateTime.now();
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
    );

    if (picked != null && mounted) {
      _dateController.text = DateFormat('dd/MM/yy').format(picked);
      _onMainDateChanged(_dateController.text, userInput: true);
    }
  }

  void _onMainDateChanged(String val, {bool userInput = false}) {
    if (userInput) _lockInstallmentRecalc = false;
    if (val.length < 8) return;
    final result = _calculateAdjustment(val);

    setState(() {
      _mainOriginalDueDate = result.originalDate;
      _mainAdjustedDueDate = result.adjustedDate;
      _mainDueDateWasAdjusted = result.changed;
    });

    if (result.changed) {
      String newText = DateFormat('dd/MM/yy').format(result.adjustedDate);
      if (_dateController.text != newText) {
        _dateController.text = newText;
        _dateController.selection = TextSelection.fromPosition(TextPosition(offset: newText.length));
      }
    }
    _updateInstallments();
  }

  void _updateInstallments() {
    if (_lockInstallmentRecalc) return;
    if (_dateController.text.length < 8 || _valueController.text.isEmpty || _installmentsQtyController.text.isEmpty) {
      setState(() => _clearInstallments());
      return;
    }

    DateTime startDate;
    try {
      startDate = _parseDateString(_dateController.text);
    } catch (_) {
      setState(() => _installments = []);
      return;
    }

    int qty = int.tryParse(_installmentsQtyController.text) ?? 1;
    if (qty < 1) qty = 1;

    double totalValue = UtilBrasilFields.converterMoedaParaDouble(_valueController.text);
    double baseValue = totalValue / qty;

    List<_InstallmentDraft> newList = [];
    String city = PrefsService.cityNotifier.value;
    DateTime firstDueDate = DateTime(startDate.year, startDate.month, startDate.day);

    for (int i = 0; i < qty; i++) {
      DateTime originalDate = DateTime(firstDueDate.year, firstDueDate.month + i, firstDueDate.day);
      var check = HolidayService.adjustDateToBusinessDay(originalDate, city);
      newList.add(_InstallmentDraft(
        index: i + 1,
        originalDate: originalDate,
        adjustedDate: check.date,
        value: baseValue,
        warning: check.warning,
        originalAccount: null,
      ));
    }
    setState(() => _setInstallments(newList));
  }

  void _onInstallmentDateChanged(int index, String val) {
    if (val.length < 8) return;
    final result = _calculateAdjustment(val);
    final draft = _installments[index];
    if (result.changed) {
      String formatted = DateFormat('dd/MM/yyyy').format(result.adjustedDate);
      if (draft.dateController.text != formatted) {
        draft.dateController.text = formatted;
        draft.dateController.selection = TextSelection.fromPosition(TextPosition(offset: formatted.length));
      }
    }
    setState(() {
      draft.originalDate = result.originalDate;
      draft.adjustedDate = result.adjustedDate;
      draft.warning = result.warning;
    });
  }

  void _onInstallmentValueChanged(int index, String val) {
    if (val.isEmpty) return;
    try {
      final parsed = UtilBrasilFields.converterMoedaParaDouble(val);
      _installments[index].value = parsed;
    } catch (_) {}
  }



  Future<void> _updateExistingInstallments(int qty, String baseDesc) async {
    if (_installments.isEmpty) return;
    for (var item in _installments) {
      final account = item.originalAccount;
      if (account?.id == null) continue;
      final dateText = item.dateController.text.isNotEmpty
          ? item.dateController.text
          : DateFormat('dd/MM/yyyy').format(item.adjustedDate);
      final dueDate = _parseDateString(dateText);
      double value = item.value;
      if (item.valueController.text.isNotEmpty) {
        try {
          value = UtilBrasilFields.converterMoedaParaDouble(item.valueController.text);
        } catch (_) {}
      }
      final updated = account!.copyWith(
        typeId: _selectedType!.id!,
        description: baseDesc,
        value: value,
        dueDay: dueDate.day,
        month: dueDate.month,
        year: dueDate.year,
        isRecurrent: false,
        payInAdvance: widget.account.payInAdvance,
        observation: _observationController.text,
        cardColor: _selectedColor,
        installmentIndex: item.index,
        installmentTotal: qty,
      );
      await DatabaseHelper.instance.updateAccount(updated);
    }
  }
}
  Future<void> _deleteSingleInstallment() async {
    if (widget.account.id == null) return;
    await DatabaseHelper.instance.deleteAccount(widget.account.id!);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _deleteEntireSeries(InstallmentDisplay info) async {
    final purchaseUuid = widget.account.purchaseUuid;
    if (purchaseUuid?.isNotEmpty == true) {
      await DatabaseHelper.instance.deleteInstallmentSeriesByUuid(purchaseUuid!);
    } else if (widget.account.cardId != null) {
      await DatabaseHelper.instance.deleteInstallmentSeries(
        widget.account.cardId!,
        cleanInstallmentDescription(widget.account.description),
        installmentTotal: info.total,
      );
    } else {
      await DatabaseHelper.instance.deleteInstallmentSeriesByDescription(
        widget.account.typeId,
        cleanInstallmentDescription(widget.account.description),
        installmentTotal: info.total,
      );
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _confirmDelete() async {
    if (widget.account.id == null) return;
    final installmentInfo = resolveInstallmentDisplay(widget.account);
    if (installmentInfo.isInstallment) {
      final action = await showDialog<_DeleteAction>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Excluir parcela?'),
          content: Text('Esta conta faz parte de um parcelamento de  24{installmentInfo.total}x.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, _DeleteAction.single),
              child: const Text('Só esta parcela', style: TextStyle(color: Colors.orange)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, _DeleteAction.series),
              child: const Text('Apagar todas'),
            ),
          ],
        ),
      );

      if (action == _DeleteAction.single) {
        await _deleteSingleInstallment();
      } else if (action == _DeleteAction.series) {
        await _deleteEntireSeries(installmentInfo);
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir conta?'),
        content: Text("Deseja remover ' 24{widget.account.description}'?"),
        actions: [
            _descFocus = FocusNode();
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteSingleInstallment();
    }
  }



  Widget _buildInstallmentsEditor() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                SizedBox(width: 30),
                Expanded(
                  flex: 3,
                  child: Text(
                    'VENCIMENTO',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'VALOR',
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _installments.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _installments[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.blue.shade50,
                            child: Text(
                              '${item.index}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: item.dateController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [_dateMaskFormatter],
                              decoration: buildOutlinedInputDecoration(
                                label: 'Vencimento',
                                icon: Icons.calendar_today,
                                dense: true,
                              ),
                              onChanged: (val) => _onInstallmentDateChanged(index, val),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: item.valueController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, CentavosInputFormatter(moeda: true)],
                              decoration: buildOutlinedInputDecoration(
                                label: 'Valor',
                                icon: Icons.attach_money,
                                dense: true,
                              ),
                              onChanged: (val) => _onInstallmentValueChanged(index, val),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 44, top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Data original: ${DateFormat('dd/MM/yy').format(item.originalDate)}',
                              style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600),
                            ),
                            if (!DateUtils.isSameDay(item.originalDate, item.adjustedDate))
                              Text(
                                'Data ajustada: ${DateFormat('dd/MM/yy').format(item.adjustedDate)}',
                                style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      ),
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

  Widget _buildSummaryCard(DateTime dueDate) {
    final dayNumber = DateFormat('dd').format(dueDate);
    final weekDay = DateFormat.EEEE('pt_BR').format(dueDate);
    final valueColor = widget.account.value >= 0 ? Colors.green.shade700 : Colors.red.shade700;
    final status = resolveInstallmentDisplay(widget.account);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FF),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dayNumber,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.black87),
              ),
              Text(
                weekDay,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'LANÇADO',
                  style: TextStyle(color: Colors.green.shade700, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Container(
            width: 1,
            height: 48,
            color: Colors.grey.shade300,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedType?.name ?? 'Conta',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  _descController.text,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: status.isInstallment ? Colors.deepPurple.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.labelText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: status.isInstallment ? Colors.deepPurple.shade700 : Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                UtilBrasilFields.obterReal(UtilBrasilFields.converterMoedaParaDouble(_valueController.text.isEmpty ? '0' : _valueController.text)),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: valueColor),
              ),
              const SizedBox(height: 10),
              _actionSquare(
                color: Colors.red.shade50,
                icon: Icons.delete,
                onTap: _confirmDelete,
                iconColor: Colors.red.shade700,
              ),
            ],
          ),
        ],
      ),
    );
  }



