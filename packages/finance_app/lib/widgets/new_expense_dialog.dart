import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../utils/app_colors.dart';
import '../utils/color_contrast.dart';
import '../widgets/app_input_decoration.dart';
import '../services/prefs_service.dart';
import '../services/holiday_service.dart';
import '../widgets/dialog_close_button.dart';
import '../utils/installment_utils.dart';

enum _EditScope { single, forward, all }

class _InstallmentPreviewItem {
  final int index;
  final DateTime dueDate;
  final DateTime originalDueDate;
  final String invoiceLabel;

  const _InstallmentPreviewItem({
    required this.index,
    required this.dueDate,
    required this.originalDueDate,
    required this.invoiceLabel,
  });

  bool get isAdjusted => !DateUtils.isSameDay(dueDate, originalDueDate);
}

/// Dialog flutuante para adicionar nova despesa em um cartao de credito.
class NewExpenseDialog extends StatefulWidget {
  final Account card;
  final Account? expenseToEdit;

  const NewExpenseDialog({
    super.key,
    required this.card,
    this.expenseToEdit,
  });

  @override
  State<NewExpenseDialog> createState() => _NewExpenseDialogState();
}

class _NewExpenseDialogState extends State<NewExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _valueController = TextEditingController();
  final _purchaseDateController = TextEditingController();
  final _installmentsQtyController = TextEditingController(text: '1');
  final _establishmentController = TextEditingController();
  final _observationController = TextEditingController();
  final List<Color> _colors = const [
    Color(0xFFFF0000),
    Color(0xFFFFFF00),
    Color(0xFF0000FF),
    Color(0xFFFFA500),
    Color(0xFF00FF00),
    Color(0xFF800080),
    Color(0xFFFF1493),
    Color(0xFF4B0082),
    Color(0xFF00CED1),
    Color(0xFF008080),
    Color(0xFF2E8B57),
    Color(0xFF6B8E23),
    Color(0xFFBDB76B),
    Color(0xFFDAA520),
    Color(0xFFCD5C5C),
    Color(0xFFFF7F50),
    Color(0xFF8B0000),
    Color(0xFF191970),
    Color(0xFFFFFFFF),
    Color(0xFF000000),
    Color(0xFF808080),
    Color(0xFF8B4513),
  ];

  bool _isSaving = false;
  bool _isLoading = true;
  bool _payInAdvance = false;
  bool _isRecurrent = false;
  int _selectedColor = 0xFFFFFFFF; // default paleta branca
  List<_InstallmentPreviewItem> _installmentPreviews = const [];
  double? _installmentValue;
  int _installmentTotal = 1;
  int _invoiceOffset = 0; // ajuste manual de fatura (-2 a +6 meses)

  bool get _isEditing => widget.expenseToEdit != null;

  // Limites seguros do datepicker
  static final DateTime _firstPickerDate = DateTime(2020, 1, 1);
  static final DateTime _lastPickerDate = DateTime(2030, 12, 31);

  @override
  void initState() {
    super.initState();
    _payInAdvance = widget.card.payInAdvance;
    // Sempre iniciar lançamento com cor branca; se editando, respeitar cor existente.
    _selectedColor = widget.expenseToEdit?.cardColor ?? 0xFFFFFFFF;
    _loadInitialData();
  }

  @override
  void dispose() {
    _descController.dispose();
    _valueController.dispose();
    _purchaseDateController.dispose();
    _installmentsQtyController.dispose();
    _establishmentController.dispose();
    _observationController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final now = DateTime.now();
    final editing = widget.expenseToEdit;

    if (editing != null) {
      final baseDesc = cleanAccountDescription(editing);
      final installments = editing.installmentTotal ?? 1;
      final totalValue = editing.value * installments;
      final purchaseDate = editing.purchaseDate != null
          ? DateTime.tryParse(editing.purchaseDate!) ?? now
          : DateTime(editing.year ?? now.year, editing.month ?? now.month, editing.dueDay);

      final (baseMonth, baseYear) = _calculateInvoiceMonth(purchaseDate);
      int offset = 0;
      if (editing.month != null && editing.year != null) {
        final base = DateTime(baseYear, baseMonth, 1);
        final stored = DateTime(editing.year!, editing.month!, 1);
        offset = (stored.year * 12 + stored.month) - (base.year * 12 + base.month);
        offset = offset.clamp(-2, 6).toInt();
      }

      if (!mounted) return;
      setState(() {
        _descController.text = baseDesc;
        _valueController.text = UtilBrasilFields.obterReal(totalValue);
        _purchaseDateController.text = DateFormat('dd/MM/yyyy').format(purchaseDate);
        _installmentsQtyController.text = installments.toString();
        _installmentTotal = installments;
        _payInAdvance = editing.payInAdvance;
        _isRecurrent = editing.isRecurrent;
        _selectedColor = editing.cardColor ?? _selectedColor;
        _observationController.text = editing.observation ?? '';
        _establishmentController.text = editing.establishment ?? '';
        _invoiceOffset = offset;
        _isLoading = false;
      });
    } else {
      _purchaseDateController.text = DateFormat('dd/MM/yyyy').format(now);
      if (!mounted) return;
      setState(() {
        _descController.text = '';
        _isLoading = false;
      });
    }

    _updatePreview();
  }

  DateTime _parseDateString(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length >= 2) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        // Se não tiver ano, usar o ano corrente
        final year = parts.length >= 3 ? int.parse(parts[2]) : DateTime.now().year;
        final fullYear = year < 100 ? 2000 + year : year;
        if (fullYear < 1900) return DateTime.now();
        return DateTime(fullYear, month, day);
      }
    } catch (_) {}
    return DateTime.now();
  }

  DateTime _clampToPickerRange(DateTime date) {
    if (date.isBefore(_firstPickerDate)) return _firstPickerDate;
    if (date.isAfter(_lastPickerDate)) return _lastPickerDate;
    return date;
  }

  Future<void> _selectPurchaseDate() async {
    DateTime initialDate;
    try {
      initialDate = _parseDateString(_purchaseDateController.text);
    } catch (_) {
      initialDate = DateTime.now();
    }
    initialDate = _clampToPickerRange(initialDate);

    if (!mounted) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _firstPickerDate,
      lastDate: _lastPickerDate,
      locale: const Locale('pt', 'BR'),
    );

    if (picked != null && mounted) {
      _purchaseDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      _updatePreview();
    }
  }

  DateTime _calculateDueDate(int month, int year) {
    final safeDay = _validDayForMonth(widget.card.dueDay, month, year);
    DateTime dueDate = DateTime(year, month, safeDay);
    final city = PrefsService.cityNotifier.value;

    while (HolidayService.isWeekend(dueDate) || HolidayService.isHoliday(dueDate, city)) {
      dueDate = dueDate.add(Duration(days: _payInAdvance ? -1 : 1));
    }

    return dueDate;
  }

  int _validDayForMonth(int desiredDay, int month, int year) {
    final lastDay = DateTime(year, month + 1, 0).day;
    if (desiredDay < 1) return 1;
    if (desiredDay > lastDay) return lastDay;
    return desiredDay;
  }

  (int month, int year) _calculateInvoiceMonth(DateTime purchaseDate) {
    final closingDay = widget.card.bestBuyDay ?? 1;
    // Compras ate o dia de fechamento entram na fatura do proximo mes.
    // Compras depois do fechamento vao para a fatura do mes seguinte (mes + 2).
    final base = purchaseDate.day <= closingDay
        ? DateTime(purchaseDate.year, purchaseDate.month + 1, 1)
        : DateTime(purchaseDate.year, purchaseDate.month + 2, 1);
    return (base.month, base.year);
  }

  void _updatePreview() {
    DateTime purchase;
    try {
      purchase = _parseDateString(_purchaseDateController.text);
    } catch (_) {
      purchase = DateTime.now();
    }
    purchase = _clampToPickerRange(purchase);

    final (baseMonth, baseYear) = _calculateInvoiceMonth(purchase);
    final offsetInvoice = DateTime(baseYear, baseMonth + _invoiceOffset, 1);

    final invoiceMonth = offsetInvoice.month;
    final invoiceYear = offsetInvoice.year;
    // Mantido para consistencia futura; não utilizado diretamente
    // final originalDue = DateTime(invoiceYear, invoiceMonth, _validDayForMonth(widget.card.dueDay, invoiceMonth, invoiceYear));
    // final adjustedDue = _calculateDueDate(invoiceMonth, invoiceYear);

    final installments = int.tryParse(_installmentsQtyController.text) ?? 1;
    double? installmentValue;
    try {
      final total = UtilBrasilFields.converterMoedaParaDouble(_valueController.text);
      installmentValue = total / installments;
    } catch (_) {}

    final previews = <_InstallmentPreviewItem>[];
    for (int i = 0; i < installments; i++) {
      final invoiceDate = DateTime(invoiceYear, invoiceMonth + i, 1);
      final rawDue = DateTime(
        invoiceDate.year,
        invoiceDate.month,
        _validDayForMonth(widget.card.dueDay, invoiceDate.month, invoiceDate.year),
      );
      final adjusted = _calculateDueDate(invoiceDate.month, invoiceDate.year);
      final invoiceLabel = '${DateFormat('MMMM', 'pt_BR').format(invoiceDate)}/${invoiceDate.year}';

      previews.add(
        _InstallmentPreviewItem(
          index: i + 1,
          dueDate: adjusted,
          originalDueDate: rawDue,
          invoiceLabel: invoiceLabel,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _installmentPreviews = previews;
      _installmentValue = installmentValue;
      _installmentTotal = installments;
    });
  }

  Widget _buildSummaryHeader() {
    final label = '${widget.card.cardBank ?? 'Cartao'} • ${widget.card.cardBrand ?? 'Bandeira'}';
    final limitText = (widget.card.cardLimit != null && widget.card.cardLimit! > 0)
        ? 'Limite ${UtilBrasilFields.obterReal(widget.card.cardLimit!)}'
        : 'Limite não informado';
    final dueText = 'Vencimento: dia ${widget.card.dueDay.toString().padLeft(2, '0')}'
        .replaceAll('dia 00', 'dia --');

    return Card(
      color: AppColors.primary.withValues(alpha: 0.08),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Text(dueText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Text(limitText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Recorrência simples
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Marcar como despesa recorrente (assinatura)'),
              subtitle: Text(_isEditing
                  ? 'Não é possível alternar recorrência durante a edição'
                  : 'Será considerada em faturas futuras a partir deste mês'),
              value: _isRecurrent,
              onChanged: _isEditing
                  ? null
                  : (val) {
                      setState(() => _isRecurrent = val);
                    },
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPalette() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Escolha a cor', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _colors.map((color) {
            final colorInt = color.toARGB32();
            final isSelected = _selectedColor == colorInt;
            return InkWell(
              onTap: () => setState(() => _selectedColor = colorInt),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? foregroundColorFor(color) : Colors.grey.shade400,
                    width: isSelected ? 3 : 1,
                  ),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                ),
                child: isSelected
                    ? Center(
                        child: Icon(
                          Icons.check,
                          size: 18,
                          color: foregroundColorFor(color), // usa a mesma cor do check para o texto interno
                        ),
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInstallmentScheduleCard() {
    if (_installmentPreviews.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Calendario das parcelas', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._installmentPreviews.expand((item) {
              final dueStr = DateFormat('dd/MM/yyyy').format(item.dueDate);
              final valueStr = _installmentValue != null ? UtilBrasilFields.obterReal(_installmentValue!) : null;
              return [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                    child: Text(
                      '${item.index}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  title: Text('Parcela ${item.index}/$_installmentTotal', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${item.invoiceLabel} • $dueStr'),
                  trailing: valueStr != null
                      ? Text(
                          valueStr,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        )
                      : null,
                ),
                if (item != _installmentPreviews.last)
                  Divider(color: Colors.grey.shade300, height: 12, thickness: 1),
              ];
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos obrigatorios.'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final value = UtilBrasilFields.converterMoedaParaDouble(_valueController.text);
      final description = _descController.text.trim();
      final purchaseDate = _parseDateString(_purchaseDateController.text);
      final installments = _isRecurrent ? 1 : (int.tryParse(_installmentsQtyController.text) ?? 1);
      final (invoiceMonthBase, invoiceYearBase) = _calculateInvoiceMonth(purchaseDate);
      final observation = _observationController.text.trim().isEmpty ? null : _observationController.text.trim();
      final establishment = _establishmentController.text.trim().isEmpty ? null : _establishmentController.text.trim();

      if (_isEditing && widget.expenseToEdit != null) {
        final original = widget.expenseToEdit!;
        final bool isRecurrence = original.isRecurrent || original.recurrenceId != null;
        final bool isInstallmentSeries = (original.installmentTotal ?? 1) > 1;

        if (isRecurrence) {
          final scope = await _askScope(title: 'Atualizar recorrência');
          if (scope == null) return;
          await _updateRecurrenceSeries(
            original: original,
            scope: scope,
            description: description,
            value: value,
            purchaseDate: purchaseDate,
            observation: observation,
            establishment: establishment,
          );
        } else if (isInstallmentSeries) {
          final scope = await _askScope(title: 'Atualizar parcelamento');
          if (scope == null) return;
          await _updateInstallmentSeries(
            original: original,
            scope: scope,
            description: description,
            value: value,
            purchaseDate: purchaseDate,
            installments: installments,
            invoiceYearBase: invoiceYearBase,
            invoiceMonthBase: invoiceMonthBase,
            observation: observation,
            establishment: establishment,
          );
        } else {
          await _updateSingleExpense(
            original: original,
            description: description,
            value: value,
            purchaseDate: purchaseDate,
            observation: observation,
            establishment: establishment,
          );
        }
      } else {
        final baseInvoiceDate = DateTime(invoiceYearBase, invoiceMonthBase + _invoiceOffset, 1);
        final purchaseUuid = '${DateTime.now().millisecondsSinceEpoch}_${description.hashCode}';
        final installmentValue = installments > 1 ? value / installments : value;

        for (int i = 0; i < installments; i++) {
          DateTime parcDate = DateTime(baseInvoiceDate.year, baseInvoiceDate.month + i, 1);
          final dueDate = _calculateDueDate(parcDate.month, parcDate.year);

          String finalDesc = description;
          if (installments > 1) {
            finalDesc = '$description (${i + 1}/$installments)';
          }

          final expense = Account(
            typeId: widget.card.typeId,
            description: finalDesc,
            value: installmentValue,
            dueDay: dueDate.day,
            month: parcDate.month,
            year: parcDate.year,
            isRecurrent: _isRecurrent,
            payInAdvance: _payInAdvance,
            cardId: widget.card.id,
            purchaseDate: DateFormat('yyyy-MM-dd').format(purchaseDate),
            purchaseUuid: purchaseUuid,
            creationDate: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
            installmentIndex: installments > 1 ? i + 1 : null,
            installmentTotal: installments > 1 ? installments : null,
            observation: observation,
            establishment: establishment,
            cardColor: _selectedColor,
          );

          await DatabaseHelper.instance.createAccount(expense);
        }
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<_EditScope?> _askScope({required String title}) async {
    return showDialog<_EditScope>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: const Text('Como deseja aplicar esta alteração?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx, _EditScope.single), child: const Text('Somente essa')),
          TextButton(onPressed: () => Navigator.pop(ctx, _EditScope.forward), child: const Text('Essa e futuras')),
          FilledButton(onPressed: () => Navigator.pop(ctx, _EditScope.all), child: const Text('Todas')), 
        ],
      ),
    );
  }

  Future<void> _updateSingleExpense({
    required Account original,
    required String description,
    required double value,
    required DateTime purchaseDate,
    String? observation,
    String? establishment,
  }) async {
    final (invoiceMonthBase, invoiceYearBase) = _calculateInvoiceMonth(purchaseDate);
    final baseDate = DateTime(invoiceYearBase, invoiceMonthBase + _invoiceOffset, 1);
    final targetInvoice = DateTime(baseDate.year, baseDate.month, 1);
    final dueDate = _calculateDueDate(targetInvoice.month, targetInvoice.year);

    final updated = original.copyWith(
      description: description,
      value: value,
      dueDay: dueDate.day,
      month: targetInvoice.month,
      year: targetInvoice.year,
      isRecurrent: _isRecurrent,
      payInAdvance: _payInAdvance,
      cardColor: _selectedColor,
      observation: observation,
      establishment: establishment,
      purchaseDate: DateFormat('yyyy-MM-dd').format(purchaseDate),
      installmentIndex: null,
      installmentTotal: null,
    );

    await DatabaseHelper.instance.updateAccount(updated);
  }

  Future<void> _updateInstallmentSeries({
    required Account original,
    required _EditScope scope,
    required String description,
    required double value,
    required DateTime purchaseDate,
    required int installments,
    required int invoiceYearBase,
    required int invoiceMonthBase,
    String? observation,
    String? establishment,
  }) async {
    final perInstallmentValue = installments > 1 ? value / installments : value;
    final baseInvoiceDate = DateTime(invoiceYearBase, invoiceMonthBase + _invoiceOffset, 1);

    List<Account> series;
    if (original.purchaseUuid != null) {
      series = await DatabaseHelper.instance.readInstallmentSeriesByUuid(original.purchaseUuid!);
    } else {
      final baseDesc = cleanAccountDescription(original);
      series = await DatabaseHelper.instance.readInstallmentSeries(original.cardId!, baseDesc, installmentTotal: original.installmentTotal);
    }
    series.sort((a, b) {
      final ai = a.installmentIndex ?? 0;
      final bi = b.installmentIndex ?? 0;
      if (ai != 0 && bi != 0) return ai.compareTo(bi);
      final ay = a.year ?? 0;
      final by = b.year ?? 0;
      if (ay != by) return ay.compareTo(by);
      return (a.month ?? 0).compareTo(b.month ?? 0);
    });

    final int currentIdx = (original.installmentIndex ?? 1).clamp(1, installments);

    for (final acc in series) {
      final int idx = (acc.installmentIndex ?? currentIdx).clamp(1, installments);
      if (scope == _EditScope.single && acc.id != original.id) continue;
      if (scope == _EditScope.forward && idx < currentIdx) continue;

      final targetInvoice = DateTime(baseInvoiceDate.year, baseInvoiceDate.month + (idx - 1), 1);
      final dueDate = _calculateDueDate(targetInvoice.month, targetInvoice.year);
      String finalDesc = description;
      if (installments > 1) {
        finalDesc = '$description ($idx/$installments)';
      }

      final updated = acc.copyWith(
        description: finalDesc,
        value: perInstallmentValue,
        dueDay: dueDate.day,
        month: targetInvoice.month,
        year: targetInvoice.year,
        isRecurrent: false,
        payInAdvance: _payInAdvance,
        cardColor: _selectedColor,
        observation: observation,
        establishment: establishment,
        purchaseDate: DateFormat('yyyy-MM-dd').format(purchaseDate),
        installmentIndex: installments > 1 ? idx : null,
        installmentTotal: installments > 1 ? installments : null,
      );
      await DatabaseHelper.instance.updateAccount(updated);
    }
  }

  Future<void> _updateRecurrenceSeries({
    required Account original,
    required _EditScope scope,
    required String description,
    required double value,
    required DateTime purchaseDate,
    String? observation,
    String? establishment,
  }) async {
    final parentId = original.recurrenceId ?? original.id;
    if (parentId == null) return;
    final allAccounts = await DatabaseHelper.instance.readAllAccountsRaw();
    final series = allAccounts.where((a) => a.recurrenceId == parentId || a.id == parentId).toList();
    series.sort((a, b) {
      final ay = a.year ?? 0;
      final by = b.year ?? 0;
      if (ay != by) return ay.compareTo(by);
      return (a.month ?? 0).compareTo(b.month ?? 0);
    });

    final currentDate = DateTime(original.year ?? DateTime.now().year, original.month ?? DateTime.now().month, 1);
    final newDay = purchaseDate.day;

    for (final acc in series) {
      final accDate = DateTime(acc.year ?? currentDate.year, acc.month ?? currentDate.month, 1);
      if (scope == _EditScope.single && acc.id != original.id) continue;
      if (scope == _EditScope.forward && accDate.isBefore(currentDate)) continue;

      final safeDay = _validDayForMonth(newDay, acc.month ?? purchaseDate.month, acc.year ?? purchaseDate.year);

      final updated = acc.copyWith(
        description: description,
        value: value,
        dueDay: safeDay,
        isRecurrent: true,
        payInAdvance: _payInAdvance,
        cardColor: _selectedColor,
        observation: observation,
        establishment: establishment,
        purchaseDate: DateFormat('yyyy-MM-dd').format(purchaseDate),
        installmentIndex: null,
        installmentTotal: null,
      );
      await DatabaseHelper.instance.updateAccount(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final viewInsets = MediaQuery.of(context).viewInsets;

    final maxWidth = (screenSize.width * 0.95).clamp(320.0, 700.0);
    final availableHeight = screenSize.height - viewInsets.bottom;
    final maxHeight = (availableHeight * 0.9).clamp(420.0, 850.0);

    if (_isLoading) {
      return const Dialog(
        child: SizedBox(
          width: 200,
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: maxHeight,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cabecalho semelhante ao dialogo de contas
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Nova Despesa - ${widget.card.cardBank ?? "Cartao"}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DialogCloseButton(
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Formulario
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                                // Linha de resumo similar ao lançamento de conta
                                _buildSummaryHeader(),
                                const SizedBox(height: 16),

                          // Paleta de cores
                          _buildColorPalette(),
                          const SizedBox(height: 20),

                        // Descricao
                        TextFormField(
                          controller: _descController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: buildOutlinedInputDecoration(
                            label: 'Descricao da Compra',
                            icon: Icons.description_outlined,
                          ),
                          validator: (v) => v!.isEmpty ? 'Obrigatorio' : null,
                        ),
                        const SizedBox(height: 16),

                        // Estabelecimento (opcional)
                        TextFormField(
                          controller: _establishmentController,
                          textCapitalization: TextCapitalization.words,
                          decoration: buildOutlinedInputDecoration(
                            label: 'Estabelecimento (Opcional)',
                            icon: Icons.store_mall_directory,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Valor
                        TextFormField(
                          controller: _valueController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, CentavosInputFormatter(moeda: true)],
                          decoration: buildOutlinedInputDecoration(
                            label: 'Valor Total (R\$)',
                            icon: Icons.attach_money,
                          ),
                          onChanged: (_) => _updatePreview(),
                          validator: (v) {
                            if (v!.isEmpty) return 'Obrigatorio';
                            try {
                              final val = UtilBrasilFields.converterMoedaParaDouble(v);
                              if (val <= 0) return 'Valor deve ser maior que zero';
                            } catch (_) {
                              return 'Valor invalido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Data da Compra
                        TextFormField(
                          controller: _purchaseDateController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, DataInputFormatter()],
                          decoration: buildOutlinedInputDecoration(
                            label: 'Data da Compra',
                            icon: Icons.calendar_today,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.date_range, color: AppColors.primary),
                              tooltip: 'Selecionar Data',
                              onPressed: _selectPurchaseDate,
                            ),
                          ),
                          onChanged: (_) => _updatePreview(),
                          validator: (v) {
                            if (v!.isEmpty) return 'Obrigatorio';
                            try {
                              _parseDateString(v);
                            } catch (_) {
                              return 'Data invalida';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Fatura Débito (Melhor Dia: ${(widget.card.bestBuyDay ?? 1).toString().padLeft(2, '0')})',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DropdownButton<int>(
                              value: _invoiceOffset,
                              onChanged: (val) {
                                if (val == null) return;
                                setState(() => _invoiceOffset = val);
                                _updatePreview();
                              },
                              items: List.generate(9, (i) => i - 2).map((offset) {
                                final (baseMonth, baseYear) = _calculateInvoiceMonth(_parseDateString(_purchaseDateController.text));
                                final target = DateTime(baseYear, baseMonth + offset, 1);
                                final label = '${DateFormat('MMMM', 'pt_BR').format(target)}/${target.year}';
                                final desc = offset == 0
                                    ? ' (sugerido)'
                                    : offset > 0
                                        ? ' (+$offset)'
                                        : ' ($offset)';
                                return DropdownMenuItem<int>(
                                  value: offset,
                                  child: Text('$label$desc'),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        if (!_isRecurrent) ...[
                          // Quantidade de Parcelas
                          TextFormField(
                            controller: _installmentsQtyController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: buildOutlinedInputDecoration(
                              label: 'Quantidade de Parcelas',
                              icon: Icons.format_list_numbered,
                            ),
                            readOnly: _isEditing,
                            validator: (v) {
                              if (v!.isEmpty) return 'Obrigatorio';
                              final qty = int.tryParse(v);
                              if (qty == null || qty < 1 || qty > 48) return 'Entre 1 e 48 parcelas';
                              return null;
                            },
                            onChanged: (_) => _updatePreview(),
                          ),
                          const SizedBox(height: 12),
                          _buildInstallmentScheduleCard(),
                          const SizedBox(height: 16),
                        ],

                        // Observacao
                        TextFormField(
                          controller: _observationController,
                          maxLines: 2,
                          decoration: buildOutlinedInputDecoration(
                            label: 'Observacao (Opcional)',
                            icon: Icons.notes,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Botoes
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close),
                        label: const Text('Cancelar'),
                        onPressed: _isSaving ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.success,
                          disabledBackgroundColor: AppColors.success.withValues(alpha: 0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _isSaving ? null : _saveExpense,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle, size: 20),
                        label: Text(
                          _isSaving ? 'Gravando...' : 'Gravar',
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
}
