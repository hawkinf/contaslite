import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../models/account_category.dart';
import '../utils/color_contrast.dart';
import '../utils/app_colors.dart';
import '../utils/installment_utils.dart';
import '../widgets/app_input_decoration.dart';
import '../services/prefs_service.dart';
import '../widgets/date_range_app_bar.dart';

class CardExpenseEditScreen extends StatefulWidget {
  final Account expense;
  final Account card;

  const CardExpenseEditScreen({
    super.key,
    required this.expense,
    required this.card,
  });

  @override
  State<CardExpenseEditScreen> createState() => _CardExpenseEditScreenState();
}

class _CardExpenseEditScreenState extends State<CardExpenseEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _valueController = TextEditingController();
  final _dateController = TextEditingController();
  final _observationController = TextEditingController();

  AccountCategory? _selectedCategory;
  List<AccountCategory> _categorias = [];
  bool _isSaving = false;
  int? _installmentIndex;
  int? _installmentTotal;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _descController.dispose();
    _valueController.dispose();
    _dateController.dispose();
    _observationController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    // Carregar categorias
    final categorias = await DatabaseHelper.instance.readAccountCategories(widget.card.typeId);

    final baseDescription = cleanAccountDescription(widget.expense);
    final status = resolveInstallmentDisplay(widget.expense);

    // Tentar selecionar categoria correspondente
    AccountCategory? selectedCat;
    try {
      selectedCat = categorias.firstWhere((c) => c.categoria == baseDescription);
    } catch (_) {
      if (categorias.isNotEmpty) {
        selectedCat = categorias.first;
      }
    }

    setState(() {
      _categorias = categorias;
      _selectedCategory = selectedCat;
      _descController.text = baseDescription;
      _valueController.text = UtilBrasilFields.obterReal(widget.expense.value);
      _dateController.text = DateFormat('dd/MM/yyyy').format(
        DateTime(widget.expense.year ?? DateTime.now().year, widget.expense.month ?? DateTime.now().month, widget.expense.dueDay),
      );
      _observationController.text = widget.expense.observation ?? '';
      _installmentIndex = status.index;
      _installmentTotal = status.total;
    });
  }

  DateTime _parseDateString(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        // Se tiver 2 dígitos (yy), converter para 20xx
        final fullYear = year < 100 ? 2000 + year : year;
        return DateTime(fullYear, month, day);
      }
    } catch (_) {}
    return DateTime(widget.expense.year ?? DateTime.now().year, widget.expense.month ?? DateTime.now().month, widget.expense.dueDay);
  }

  Future<void> _selectDate() async {
    DateTime initialDate;
    try {
      initialDate = _parseDateString(_dateController.text);
    } catch (_) {
      initialDate = DateTime(widget.expense.year ?? DateTime.now().year, widget.expense.month ?? DateTime.now().month, widget.expense.dueDay);
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
      _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos obrigatórios.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Compor descrição final com sufixo de parcelamento
      final finalDescription = cleanInstallmentDescription(_descController.text.trim());

      // Converter valor e data
      final newValue = UtilBrasilFields.converterMoedaParaDouble(_valueController.text);
      final newDate = _parseDateString(_dateController.text);

      // Criar objeto Account atualizado
      final updated = Account(
        id: widget.expense.id,
        typeId: widget.expense.typeId,
        description: finalDescription,
        value: newValue,
        dueDay: newDate.day,
        month: newDate.month,
        year: newDate.year,
        isRecurrent: widget.expense.isRecurrent,
        payInAdvance: widget.expense.payInAdvance,
        recurrenceId: widget.expense.recurrenceId,
        bestBuyDay: widget.expense.bestBuyDay,
        cardBrand: widget.expense.cardBrand,
        cardBank: widget.expense.cardBank,
        cardLimit: widget.expense.cardLimit,
        cardColor: widget.expense.cardColor,
        cardId: widget.expense.cardId,
        observation: _observationController.text.trim().isEmpty
          ? null
          : _observationController.text.trim(),
        establishment: widget.expense.establishment,
        purchaseDate: widget.expense.purchaseDate,
        purchaseUuid: widget.expense.purchaseUuid,
        creationDate: widget.expense.creationDate,
        installmentIndex: _installmentIndex,
        installmentTotal: _installmentTotal,
      );

      // Salvar no banco
      await DatabaseHelper.instance.updateAccount(updated);

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Despesa atualizada com sucesso!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildFieldWithIcon({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return child;
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = (widget.card.cardColor != null) ? Color(widget.card.cardColor!) : AppColors.cardPurple;
    final fgColor = foregroundColorFor(bgColor);

    return ValueListenableBuilder<DateTimeRange>(
      valueListenable: PrefsService.dateRangeNotifier,
      builder: (context, range, _) {
        return Scaffold(
      appBar: DateRangeAppBar(
          title: 'Editar Despesa',
          range: range,
          onPrevious: () => PrefsService.shiftDateRange(-1),
          onNext: () => PrefsService.shiftDateRange(1),
          backgroundColor: bgColor,
          foregroundColor: fgColor,
        ),
        body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Categoria
              if (_categorias.isNotEmpty)
                _buildFieldWithIcon(
                  icon: Icons.label,
                  label: 'Categoria',
                  child: DropdownButtonFormField<AccountCategory>(
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
                ),
              if (_categorias.isNotEmpty) const SizedBox(height: 20),

              // Descrição
              _buildFieldWithIcon(
                icon: Icons.description_outlined,
                label: 'Descrição',
                child: TextFormField(
                  controller: _descController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: buildOutlinedInputDecoration(
                    label: 'Descrição',
                    icon: Icons.description_outlined,
                  ),
                  validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                ),
              ),
              const SizedBox(height: 20),

              // Valor
              _buildFieldWithIcon(
                icon: Icons.attach_money,
                label: 'Valor (R\$)',
                child: TextFormField(
                  controller: _valueController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, CentavosInputFormatter(moeda: true)],
                  decoration: buildOutlinedInputDecoration(
                    label: 'Valor (R\$)',
                    icon: Icons.attach_money,
                  ),
                  validator: (v) {
                    if (v!.isEmpty) return 'Obrigatório';
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
              const SizedBox(height: 20),

              // Data
              _buildFieldWithIcon(
                icon: Icons.calendar_today,
                label: 'Data',
                child: TextFormField(
                  controller: _dateController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, DataInputFormatter()],
                  decoration: buildOutlinedInputDecoration(
                    label: 'Data',
                    icon: Icons.calendar_today,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.date_range, color: AppColors.primary),
                      tooltip: 'Selecionar Data',
                      onPressed: _selectDate,
                    ),
                  ),
                  validator: (v) {
                    if (v!.isEmpty) return 'Obrigatório';
                    try {
                      _parseDateString(v);
                    } catch (_) {
                      return 'Data inválida (dd/mm/aa)';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Observações
              _buildFieldWithIcon(
                icon: Icons.note,
                label: 'Observações (Opcional)',
                child: TextFormField(
                  controller: _observationController,
                  decoration: buildOutlinedInputDecoration(
                    label: 'Observações (Opcional)',
                    icon: Icons.note,
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Theme.of(context).cardColor,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.close),
                label: const Text('Cancelar'),
                onPressed: _isSaving ? null : () => Navigator.pop(context),
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
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
                  backgroundColor: AppColors.success,
                  disabledBackgroundColor: AppColors.success.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSaving ? null : _saveExpense,
                icon: _isSaving ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Icon(Icons.check_circle, size: 24),
                label: Text(
                  _isSaving ? 'Gravando...' : 'Gravar',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
        );
      },
    );
  }
}
