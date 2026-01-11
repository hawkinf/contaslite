import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../models/account_category.dart';
import '../utils/app_colors.dart';
import '../widgets/app_input_decoration.dart';
import '../services/prefs_service.dart';
import '../services/holiday_service.dart';
import '../widgets/dialog_close_button.dart';

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

  AccountCategory? _selectedCategory;
  List<AccountCategory> _categorias = [];
  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _descController.dispose();
    _valueController.dispose();
    _purchaseDateController.dispose();
    _installmentsQtyController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final categorias = await DatabaseHelper.instance.readAccountCategories(widget.card.typeId);
    final now = DateTime.now();
    _purchaseDateController.text = DateFormat('dd/MM/yyyy').format(now);

    if (!mounted) return;
    setState(() {
      _categorias = categorias;
      if (categorias.isNotEmpty) {
        _selectedCategory = categorias.first;
        _descController.text = categorias.first.categoria;
      }
      _isLoading = false;
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

  Future<void> _selectPurchaseDate() async {
    DateTime initialDate;
    try {
      initialDate = _parseDateString(_purchaseDateController.text);
    } catch (_) {
      initialDate = DateTime.now();
    }

    if (!mounted) return;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
    );

    if (picked != null && mounted) {
      _purchaseDateController.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  DateTime _calculateDueDate(int month, int year) {
    DateTime dueDate = DateTime(year, month, widget.card.dueDay);
    final city = PrefsService.cityNotifier.value;

    while (HolidayService.isWeekend(dueDate) || HolidayService.isHoliday(dueDate, city)) {
      dueDate = dueDate.add(Duration(days: widget.card.payInAdvance ? -1 : 1));
    }

    return dueDate;
  }

  (int month, int year) _calculateInvoiceMonth(DateTime purchaseDate) {
    final closingDay = widget.card.bestBuyDay ?? 1;

    if (purchaseDate.day <= closingDay) {
      return (purchaseDate.month, purchaseDate.year);
    } else {
      DateTime nextMonth = DateTime(purchaseDate.year, purchaseDate.month + 1, 1);
      return (nextMonth.month, nextMonth.year);
    }
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
      final installments = int.tryParse(_installmentsQtyController.text) ?? 1;
      final (invoiceMonth, invoiceYear) = _calculateInvoiceMonth(purchaseDate);

      final purchaseUuid = '${DateTime.now().millisecondsSinceEpoch}_${description.hashCode}';
      final installmentValue = value / installments;

      for (int i = 0; i < installments; i++) {
        DateTime parcDate = DateTime(invoiceYear, invoiceMonth + i, 1);
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
          isRecurrent: false,
          payInAdvance: widget.card.payInAdvance,
          cardId: widget.card.id,
          purchaseDate: DateFormat('yyyy-MM-dd').format(purchaseDate),
          purchaseUuid: purchaseUuid,
          creationDate: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
          installmentIndex: installments > 1 ? i + 1 : null,
          installmentTotal: installments > 1 ? installments : null,
        );

        await DatabaseHelper.instance.createAccount(expense);
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
                        // Categoria
                        if (_categorias.isNotEmpty) ...[
                          DropdownButtonFormField<AccountCategory>(
                            initialValue: _selectedCategory,
                            decoration: buildOutlinedInputDecoration(
                              label: 'Categoria',
                              icon: Icons.category,
                            ),
                            items: _categorias.map((cat) => DropdownMenuItem(value: cat, child: Text(cat.categoria))).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedCategory = val;
                                if (val != null) {
                                  _descController.text = val.categoria;
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

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

                        // Valor
                        TextFormField(
                          controller: _valueController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, CentavosInputFormatter(moeda: true)],
                          decoration: buildOutlinedInputDecoration(
                            label: 'Valor Total (R\$)',
                            icon: Icons.attach_money,
                          ),
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

                        // Quantidade de Parcelas
                        TextFormField(
                          controller: _installmentsQtyController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: buildOutlinedInputDecoration(
                            label: 'Quantidade de Parcelas',
                            icon: Icons.format_list_numbered,
                          ),
                          validator: (v) {
                            if (v!.isEmpty) return 'Obrigatorio';
                            final qty = int.tryParse(v);
                            if (qty == null || qty < 1 || qty > 48) return 'Entre 1 e 48 parcelas';
                            return null;
                          },
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
