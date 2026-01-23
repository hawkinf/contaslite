import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../models/account_category.dart';
import '../models/account_type.dart';
import '../utils/app_colors.dart';
import '../utils/color_contrast.dart';
import '../widgets/app_input_decoration.dart';
import '../widgets/icon_picker_dialog.dart';
import '../services/prefs_service.dart';
import '../services/holiday_service.dart';
import '../services/default_account_categories_service.dart';
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
  final _observationController = TextEditingController();
  final List<Color> _colors = AppColors.essentialPalette;

  List<AccountType> _typesList = [];
  AccountType? _selectedType;
  List<AccountCategory> _categories = [];
  AccountCategory? _selectedCategory;

  bool _isSaving = false;
  bool _isLoading = true;
  bool _payInAdvance = false;
  bool _isRecurrent = false;
  bool _submitted = false;
  bool _descTouched = false;
  bool _valueTouched = false;
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

    await _loadTypesAndCategories(editing: editing);
    _updatePreview();
  }

  AccountType? _getValidatedSelectedType() {
    if (_selectedType == null) return null;
    if (_typesList.any((t) => t.id == _selectedType!.id)) return _selectedType;
    return null;
  }

  AccountCategory? _getValidatedSelectedCategory() {
    if (_selectedCategory == null) return null;
    if (_categories.any((c) => c.id == _selectedCategory!.id)) return _selectedCategory;
    return null;
  }

  Future<void> _loadTypesAndCategories({Account? editing}) async {
    final types = await DatabaseHelper.instance.readAllTypes();
    String normalizeName(String value) {
      return value
          .trim()
          .toUpperCase()
          .replaceAll('Á', 'A')
          .replaceAll('À', 'A')
          .replaceAll('Â', 'A')
          .replaceAll('Ã', 'A')
          .replaceAll('É', 'E')
          .replaceAll('Ê', 'E')
          .replaceAll('Í', 'I')
          .replaceAll('Ó', 'O')
          .replaceAll('Ô', 'O')
          .replaceAll('Õ', 'O')
          .replaceAll('Ú', 'U')
          .replaceAll('Ç', 'C');
    }
    final recebimentosKey = normalizeName(DefaultAccountCategoriesService.recebimentosName);
    const cartoesKey = 'CARTOES DE CREDITO';
    final filtered = types
        .where((t) {
          final key = normalizeName(t.name);
          if (key == recebimentosKey) return false;
          if (key == cartoesKey) return false;
          return true;
        })
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    AccountType? selected = _selectedType;
    if (editing != null && filtered.isNotEmpty) {
      selected = filtered.firstWhere(
        (t) => t.id == editing.typeId,
        orElse: () => filtered.first,
      );
    }
    if (selected != null && !filtered.any((t) => t.id == selected!.id)) {
      selected = filtered.isNotEmpty ? filtered.first : null;
    }
    selected ??= filtered.isNotEmpty ? filtered.first : null;

    List<AccountCategory> categories = [];
    AccountCategory? selectedCategory;
    if (selected?.id != null) {
      categories = await DatabaseHelper.instance.readAccountCategories(selected!.id!);
      categories.sort((a, b) => a.categoria.compareTo(b.categoria));

      if (editing?.categoryId != null) {
        for (final cat in categories) {
          if (cat.id == editing!.categoryId) {
            selectedCategory = cat;
            break;
          }
        }
      }

      if (selectedCategory == null && _selectedCategory != null) {
        if (categories.any((c) => c.id == _selectedCategory!.id)) {
          selectedCategory = _selectedCategory;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _typesList = filtered;
      _selectedType = selected;
      _categories = categories;
      _selectedCategory = selectedCategory;
    });
  }

  Future<void> _reloadCategoriesForSelectedType() async {
    if (_selectedType?.id == null) {
      if (!mounted) return;
      setState(() {
        _categories = [];
        _selectedCategory = null;
      });
      return;
    }

    final categories = await DatabaseHelper.instance.readAccountCategories(_selectedType!.id!);
    categories.sort((a, b) => a.categoria.compareTo(b.categoria));
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _selectedCategory = null;
    });
  }

  Future<void> _openCategoriesManager() async {
    if (_selectedType?.id == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione a conta a pagar antes de gerenciar categorias'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    await _reloadCategoriesForSelectedType();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => _CategoriasDialog(
        typeId: _selectedType!.id!,
        categorias: _categories,
        onCategoriasUpdated: () => _reloadCategoriesForSelectedType(),
      ),
    );
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

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    IconData? icon,
    String? hintText,
    String? helperText,
    Widget? suffixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      helperText: helperText,
      prefixIcon: icon != null ? Icon(icon) : null,
      prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      prefixIconColor: colorScheme.onSurfaceVariant,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colorScheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.primary.withValues(alpha: 0.6)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  String _selectedColorLabel() {
    final index = _colors.indexWhere((c) => c.toARGB32() == _selectedColor);
    if (index == -1) return 'Personalizada';
    return 'Opção ${index + 1}';
  }

  Future<void> _showColorPicker() async {
    final colorScheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Escolher cor',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _colors.map((color) {
                  final colorInt = color.toARGB32();
                  final isSelected = _selectedColor == colorInt;
                  return InkWell(
                    onTap: () {
                      setState(() => _selectedColor = colorInt);
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.onSurface
                              : colorScheme.outlineVariant.withValues(alpha: 0.6),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              size: 14,
                              color: foregroundColorFor(color),
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
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
    if (!_submitted) {
      setState(() => _submitted = true);
    }
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos obrigatorios.'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_selectedType?.id == null || _selectedCategory?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a tabela pai e a categoria filha.'), backgroundColor: AppColors.error),
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
            typeId: _selectedType!.id!,
            categoryId: _selectedCategory!.id!,
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
            typeId: _selectedType!.id!,
            categoryId: _selectedCategory!.id!,
          );
        } else {
          await _updateSingleExpense(
            original: original,
            description: description,
            value: value,
            purchaseDate: purchaseDate,
            observation: observation,
            typeId: _selectedType!.id!,
            categoryId: _selectedCategory!.id!,
          );
        }
      } else {
        final baseInvoiceDate = DateTime(invoiceYearBase, invoiceMonthBase + _invoiceOffset, 1);
        final purchaseUuid = '${DateTime.now().millisecondsSinceEpoch}_${description.hashCode}';
        final installmentValue = installments > 1 ? value / installments : value;

        // Guardar informações da primeira fatura para exibir feedback ao usuário
        final firstInvoiceMonth = baseInvoiceDate.month;
        final firstInvoiceYear = baseInvoiceDate.year;

        for (int i = 0; i < installments; i++) {
          DateTime parcDate = DateTime(baseInvoiceDate.year, baseInvoiceDate.month + i, 1);
          final dueDate = _calculateDueDate(parcDate.month, parcDate.year);

          String finalDesc = description;
          if (installments > 1) {
            finalDesc = '$description (${i + 1}/$installments)';
          }

          final expense = Account(
            typeId: _selectedType!.id!,
            categoryId: _selectedCategory!.id!,
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
            cardColor: _selectedColor,
          );

          await DatabaseHelper.instance.createAccount(expense);
        }

        // Mostrar feedback informando em qual mês a despesa foi lançada
        if (mounted) {
          final monthName = DateFormat('MMMM/yyyy', 'pt_BR').format(DateTime(firstInvoiceYear, firstInvoiceMonth, 1));
          final message = installments > 1 
              ? 'Despesa parcelada em ${installments}x adicionada à fatura de $monthName'
              : 'Despesa adicionada à fatura de $monthName';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
            ),
          );
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
    required int typeId,
    required int categoryId,
  }) async {
    final (invoiceMonthBase, invoiceYearBase) = _calculateInvoiceMonth(purchaseDate);
    final baseDate = DateTime(invoiceYearBase, invoiceMonthBase + _invoiceOffset, 1);
    final targetInvoice = DateTime(baseDate.year, baseDate.month, 1);
    final dueDate = _calculateDueDate(targetInvoice.month, targetInvoice.year);

    final updated = original.copyWith(
      typeId: typeId,
      categoryId: categoryId,
      description: description,
      value: value,
      dueDay: dueDate.day,
      month: targetInvoice.month,
      year: targetInvoice.year,
      isRecurrent: _isRecurrent,
      payInAdvance: _payInAdvance,
      cardColor: _selectedColor,
      observation: observation,
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
    required int typeId,
    required int categoryId,
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
        typeId: typeId,
        categoryId: categoryId,
        description: finalDesc,
        value: perInstallmentValue,
        dueDay: dueDate.day,
        month: targetInvoice.month,
        year: targetInvoice.year,
        isRecurrent: false,
        payInAdvance: _payInAdvance,
        cardColor: _selectedColor,
        observation: observation,
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
    required int typeId,
    required int categoryId,
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
        typeId: typeId,
        categoryId: categoryId,
        description: description,
        value: value,
        dueDay: safeDay,
        isRecurrent: true,
        payInAdvance: _payInAdvance,
        cardColor: _selectedColor,
        observation: observation,
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
    final colorScheme = Theme.of(context).colorScheme;

    final maxWidth = (screenSize.width * 0.95).clamp(320.0, 860.0);
    final availableHeight = screenSize.height - viewInsets.bottom;
    final maxHeight = (availableHeight * 0.9).clamp(420.0, 850.0);
    final installmentsQty = int.tryParse(_installmentsQtyController.text) ?? 1;
    final hasInstallments = !_isRecurrent && installmentsQty > 1;

    if (_isLoading) {
      return const Dialog(
        child: SizedBox(
          width: 200,
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final cardTitle = [
      widget.card.cardBank?.trim() ?? '',
      widget.card.cardBrand?.trim() ?? '',
    ].where((t) => t.isNotEmpty).join(' • ');

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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        cardTitle.isEmpty ? 'Cartão' : cardTitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Chip(
                      label: Text('Fech: ${(widget.card.bestBuyDay ?? 1).toString().padLeft(2, '0')}'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
                      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11),
                    ),
                    const SizedBox(width: 6),
                    Chip(
                      label: Text('Venc: ${widget.card.dueDay.toString().padLeft(2, '0')}'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
                      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.close),
                      iconSize: 20,
                      color: colorScheme.onSurfaceVariant,
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Formulário
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Tipo e identificação',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
                          ),
                          child: SwitchListTile(
                            value: _isRecurrent,
                            onChanged: (val) => setState(() => _isRecurrent = val),
                            title: const Text('Despesa recorrente (mensal)'),
                            secondary: Icon(Icons.autorenew, color: colorScheme.onSurfaceVariant),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Descrição
                        SizedBox(
                          height: 48,
                          child: TextFormField(
                            controller: _descController,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: _inputDecoration(
                              context,
                              label: 'Descrição da Compra',
                              icon: Icons.description_outlined,
                            ),
                            onTap: () {
                              if (_descTouched) return;
                              setState(() => _descTouched = true);
                            },
                            onChanged: (_) {
                              if (_descTouched) return;
                              setState(() => _descTouched = true);
                            },
                            validator: (v) {
                              if (!_submitted && !_descTouched) return null;
                              return (v == null || v.isEmpty) ? 'Obrigatório' : null;
                            },
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Valor
                        SizedBox(
                          height: 48,
                          child: TextFormField(
                            controller: _valueController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, CentavosInputFormatter(moeda: true)],
                            decoration: _inputDecoration(
                              context,
                              label: 'Valor Total (R\$)',
                              icon: Icons.attach_money,
                            ),
                            onTap: () {
                              if (_valueTouched) return;
                              setState(() => _valueTouched = true);
                            },
                            onChanged: (_) {
                              if (!_valueTouched) {
                                setState(() => _valueTouched = true);
                              }
                              _updatePreview();
                            },
                            validator: (v) {
                              if (!_submitted && !_valueTouched) return null;
                              if (v == null || v.isEmpty) return 'Obrigatório';
                              try {
                                final val = UtilBrasilFields.converterMoedaParaDouble(v);
                                if (val <= 0) return 'Valor deve ser maior que zero';
                              } catch (_) {
                                return 'Valor inválido';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          'Datas e fatura',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 6),

                        // Data da Compra
                        SizedBox(
                          height: 48,
                          child: TextFormField(
                            controller: _purchaseDateController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, DataInputFormatter()],
                            decoration: _inputDecoration(
                              context,
                              label: 'Data da Compra',
                              icon: Icons.calendar_today,
                              suffixIcon: IconButton(
                                icon: Icon(Icons.date_range, color: colorScheme.onSurfaceVariant),
                                tooltip: 'Selecionar Data',
                                onPressed: _selectPurchaseDate,
                              ),
                            ),
                            onChanged: (_) => _updatePreview(),
                            validator: (v) {
                              if (v!.isEmpty) return 'Obrigatório';
                              try {
                                _parseDateString(v);
                              } catch (_) {
                                return 'Data inválida';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: _invoiceOffset,
                          decoration: _inputDecoration(
                            context,
                            label: 'Fatura',
                            icon: Icons.event_note,
                          ),
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() => _invoiceOffset = val);
                            _updatePreview();
                          },
                          items: List.generate(9, (i) => i - 2).map((offset) {
                            final (baseMonth, baseYear) =
                                _calculateInvoiceMonth(_parseDateString(_purchaseDateController.text));
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
                        const SizedBox(height: 6),
                        Text(
                          'Melhor dia: ${(widget.card.bestBuyDay ?? 1).toString().padLeft(2, '0')}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          'Classificação',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 6),

                        if (_typesList.isEmpty)
                          InkWell(
                            onTap: _openCategoriesManager,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.warningBackground,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.warning),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.warning, color: AppColors.warning),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text('Cadastre a tabela pai e categorias para classificar a despesa.'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else ...[
                          DropdownButtonFormField<AccountType>(
                            key: const ValueKey('expense_type_dropdown'),
                            initialValue: _getValidatedSelectedType(),
                            decoration: _inputDecoration(
                              context,
                              label: 'Conta a Pagar',
                              icon: Icons.account_balance_wallet,
                            ),
                            items: _typesList
                                .map((type) => DropdownMenuItem(
                                      value: type,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(type.logo ?? '📁', style: const TextStyle(fontSize: 18)),
                                          const SizedBox(width: 8),
                                          Text(type.name),
                                        ],
                                      ),
                                    ))
                                .toList(),
                            selectedItemBuilder: (context) {
                              return _typesList
                                  .map((type) => Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text('${type.logo ?? '📁'} ${type.name}'),
                                      ))
                                  .toList();
                            },
                            onChanged: (val) {
                              setState(() {
                                _selectedType = val;
                                _selectedCategory = null;
                                _categories = [];
                              });
                              _reloadCategoriesForSelectedType();
                            },
                            validator: (val) => val == null ? 'Selecione a conta a pagar' : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Categorias',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _openCategoriesManager,
                                child: const Text('Gerenciar'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_categories.isNotEmpty)
                            DropdownButtonFormField<AccountCategory>(
                              key: const ValueKey('expense_category_dropdown'),
                              initialValue: _getValidatedSelectedCategory(),
                              decoration: _inputDecoration(
                                context,
                                label: 'Categoria',
                                icon: Icons.label,
                              ),
                              items: _categories
                                  .map((cat) => DropdownMenuItem(
                                        value: cat,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(cat.logo ?? '📁', style: const TextStyle(fontSize: 18)),
                                            const SizedBox(width: 8),
                                            Text(cat.categoria),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                              selectedItemBuilder: (context) {
                                return _categories
                                    .map((cat) => Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text('${cat.logo ?? '📁'} ${cat.categoria}'),
                                        ))
                                    .toList();
                              },
                              onChanged: (val) => setState(() => _selectedCategory = val),
                              validator: (val) => val == null ? 'Selecione a categoria' : null,
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
                              ),
                              child: const Text('Nenhuma categoria encontrada para o tipo selecionado.'),
                            ),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 12),

                        Text(
                          'Opções',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Color(_selectedColor),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Cor do lançamento',
                                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    Text(
                                      _selectedColorLabel(),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton(
                                onPressed: _showColorPicker,
                                child: const Text('Escolher'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (!_isRecurrent && installmentsQty == 1)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Parcelamento',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _isEditing
                                      ? null
                                      : () {
                                          _installmentsQtyController.text = '2';
                                          _updatePreview();
                                          setState(() {});
                                        },
                                  child: const Text('Adicionar'),
                                ),
                              ],
                            ),
                          ),

                        if (hasInstallments) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _installmentsQtyController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: _inputDecoration(
                              context,
                              label: 'Quantidade de Parcelas',
                              icon: Icons.format_list_numbered,
                            ),
                            readOnly: _isEditing,
                            validator: (v) {
                              if (v!.isEmpty) return 'Obrigatório';
                              final qty = int.tryParse(v);
                              if (qty == null || qty < 1 || qty > 48) return 'Entre 1 e 48 parcelas';
                              return null;
                            },
                            onChanged: (_) => _updatePreview(),
                          ),
                        ],

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _observationController,
                          maxLines: 2,
                          decoration: _inputDecoration(
                            context,
                            label: 'Observação (opcional)',
                            icon: Icons.notes,
                          ),
                        ),

                        if (hasInstallments) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Calendário das parcelas',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 8),
                          _buildInstallmentScheduleCard(),
                        ],
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
                    const Spacer(),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('Cancelar'),
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
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

class _CategoriasDialog extends StatefulWidget {
  final int typeId;
  final List<AccountCategory> categorias;
  final VoidCallback onCategoriasUpdated;

  const _CategoriasDialog({
    required this.typeId,
    required this.categorias,
    required this.onCategoriasUpdated,
  });

  @override
  State<_CategoriasDialog> createState() => _CategoriasDialogState();
}

class _CategoriasDialogState extends State<_CategoriasDialog> {
  late List<AccountCategory> _categorias;
  final _newCategoriaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _categorias = List.from(widget.categorias);
  }

  @override
  void dispose() {
    _newCategoriaController.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    final text = _newCategoriaController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Digite uma categoria'),
            backgroundColor: AppColors.warning),
      );
      return;
    }

    final exists = await DatabaseHelper.instance
        .checkAccountCategoryExists(widget.typeId, text);
    if (exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Esta categoria já existe'),
              backgroundColor: AppColors.error),
        );
      }
      return;
    }

    final categoria =
        AccountCategory(accountId: widget.typeId, categoria: text);
    final id = await DatabaseHelper.instance.createAccountCategory(categoria);

    setState(() {
      _categorias.add(
          AccountCategory(id: id, accountId: widget.typeId, categoria: text));
      _newCategoriaController.clear();
    });

    widget.onCategoriasUpdated();
  }

  Future<void> _deleteCategory(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deletar Categoria?'),
        content: const Text('Deseja remover esta categoria?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Deletar')),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteAccountCategory(id);
      setState(() {
        _categorias.removeWhere((d) => d.id! == id);
      });
      widget.onCategoriasUpdated();
    }
  }

  Future<void> _editCategory(AccountCategory category) async {
    final controller = TextEditingController(text: category.categoria);
    final logoController = TextEditingController(text: category.logo ?? '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Categoria'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: buildOutlinedInputDecoration(
                label: 'Nome da categoria',
                icon: Icons.label,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: logoController,
                    decoration: buildOutlinedInputDecoration(
                      label: 'Logo (emoji ou texto)',
                      icon: Icons.image,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () async {
                    final selectedIcon = await showIconPickerDialog(
                      ctx,
                      initialIcon: logoController.text.isNotEmpty
                          ? logoController.text
                          : null,
                    );
                    if (selectedIcon != null) {
                      logoController.text = selectedIcon;
                    }
                  },
                  icon: const Icon(Icons.palette),
                  label: const Text('Picker'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              final logo = logoController.text.trim();
              Navigator.pop(ctx, {'name': name, 'logo': logo});
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (result != null && result['name']!.isNotEmpty) {
      final newName = result['name']!;
      final newLogo = result['logo']!.isEmpty ? null : result['logo'];
      final nameChanged = newName != category.categoria;
      final logoChanged = newLogo != category.logo;

      if (!nameChanged && !logoChanged) {
        controller.dispose();
        logoController.dispose();
        return;
      }

      if (nameChanged) {
        final exists = await DatabaseHelper.instance
            .checkAccountCategoryExists(widget.typeId, newName);
        if (exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Uma categoria com este nome ja existe'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          controller.dispose();
          logoController.dispose();
          return;
        }
      }

      final updated = category.copyWith(categoria: newName, logo: newLogo);
      await DatabaseHelper.instance.updateAccountCategory(updated);

      final refreshed =
          await DatabaseHelper.instance.readAccountCategories(widget.typeId);
      setState(() {
        _categorias
          ..clear()
          ..addAll(refreshed);
      });
      widget.onCategoriasUpdated();
    }

    controller.dispose();
    logoController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFFF5F5F5),
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Gerenciar Categorias',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87),
            ),
            const SizedBox(height: 16),

            // Campo de entrada
            TextField(
              controller: _newCategoriaController,
              decoration: buildOutlinedInputDecoration(
                label: 'Nova Categoria',
                icon: Icons.add_circle,
                dense: true,
                suffixIcon: _newCategoriaController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () =>
                            setState(() => _newCategoriaController.clear()),
                      ),
              ),
              onChanged: (val) => setState(() {}),
              onSubmitted: (val) => _addCategory(),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Adicionar'),
              onPressed: _addCategory,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),

            const SizedBox(height: 16),

            // Lista de categorias
            Flexible(
              child: _categorias.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhuma categoria cadastrada',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 14),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _categorias.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final cat = _categorias[idx];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    if (cat.logo != null &&
                                        cat.logo!.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8.0),
                                        child: Text(
                                          cat.logo!,
                                          style:
                                              const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        cat.categoria,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.blue, size: 20),
                                onPressed: () => _editCategory(cat),
                                tooltip: 'Editar',
                                splashRadius: 20,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red, size: 20),
                                onPressed: () => _deleteCategory(cat.id!),
                                tooltip: 'Deletar',
                                splashRadius: 20,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 16),

            // Botões de ação
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar', style: TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
