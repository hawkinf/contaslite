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
import '../screens/account_types_screen.dart';
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
  final _establishmentController = TextEditingController();
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
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AccountTypesScreen()),
    );
    if (!mounted) return;
    await _loadTypesAndCategories(editing: widget.expenseToEdit);
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
    final cardColor = widget.card.cardColor != null
        ? Color(widget.card.cardColor!)
        : AppColors.primary;
    final fgColor = foregroundColorFor(cardColor);
    final dueText = widget.card.dueDay.toString().padLeft(2, '0')
        .replaceAll('00', '--');
    final brand = (widget.card.cardBrand ?? 'Cartao').trim();
    final description = (widget.card.cardBank ?? widget.card.description).trim();
    final label = [brand, description].where((s) => s.isNotEmpty).join(' ');
    final brandLogo = _buildCardBrandLogo();

    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black, width: 0.6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  dueText,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 36,
                    color: fgColor,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(width: 42, height: 25, child: brandLogo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: fgColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Recorrência simples
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Marcar como despesa recorrente (assinatura)',
                style: TextStyle(color: fgColor, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _isEditing
                    ? 'Não é possível alternar recorrência durante a edição'
                    : 'Será considerada em faturas futuras a partir deste mês',
                style: TextStyle(color: fgColor.withValues(alpha: 0.8)),
              ),
              value: _isRecurrent,
              activeThumbColor: fgColor,
              activeTrackColor: fgColor.withValues(alpha: 0.25),
              inactiveThumbColor: fgColor.withValues(alpha: 0.7),
              inactiveTrackColor: fgColor.withValues(alpha: 0.2),
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

  Widget _buildCardBrandLogo() {
    final brand = (widget.card.cardBrand ?? '').trim().toUpperCase();
    String? assetPath;
    if (brand == 'VISA') {
      assetPath = 'assets/icons/cc_visa.png';
    } else if (brand == 'AMEX' || brand == 'AMERICAN EXPRESS' || brand == 'AMERICANEXPRESS') {
      assetPath = 'assets/icons/cc_amex.png';
    } else if (brand == 'MASTER' || brand == 'MASTERCARD' || brand == 'MASTER CARD') {
      assetPath = 'assets/icons/cc_mc.png';
    } else if (brand == 'ELO') {
      assetPath = 'assets/icons/cc_elo.png';
    }

    if (assetPath != null) {
      return Image.asset(
        assetPath,
        package: 'finance_app',
        width: 28,
        height: 18,
        fit: BoxFit.contain,
      );
    }

    return const Icon(Icons.credit_card, size: 18);
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
            establishment: establishment,
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
            establishment: establishment,
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
            establishment: establishment,
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
    String? establishment,
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
                  color: widget.card.cardColor != null
                      ? Color(widget.card.cardColor!)
                      : Theme.of(context).colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      color: widget.card.cardColor != null
                          ? foregroundColorFor(Color(widget.card.cardColor!))
                          : null,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Nova Despesa - ${widget.card.cardBank ?? "Cartao"}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: widget.card.cardColor != null
                              ? foregroundColorFor(Color(widget.card.cardColor!))
                              : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        textAlign: TextAlign.left,
                      ),
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
                            decoration: buildOutlinedInputDecoration(
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
                                  'Gerenciar Categorias',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            icon: const Icon(Icons.category),
                            label: const Text('Acessar Categorias'),
                            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                            onPressed: _openCategoriesManager,
                          ),
                          const SizedBox(height: 16),
                          if (_categories.isNotEmpty)
                            DropdownButtonFormField<AccountCategory>(
                              key: const ValueKey('expense_category_dropdown'),
                              initialValue: _getValidatedSelectedCategory(),
                              decoration: buildOutlinedInputDecoration(
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
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: const Text('Nenhuma categoria encontrada para o tipo selecionado.'),
                            ),
                          const SizedBox(height: 16),
                        ],

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
