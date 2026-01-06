import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:brasil_fields/brasil_fields.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../models/account_type.dart';
import '../models/account_category.dart';
import '../utils/color_contrast.dart';
import '../widgets/app_input_decoration.dart';
import '../widgets/payment_dialog.dart';
import '../services/prefs_service.dart';
import '../widgets/date_range_app_bar.dart';

enum _RecurrentEditScope { thisOnly, thisAndFuture }

class RecurrentAccountEditScreen extends StatefulWidget {
  final Account account;
  const RecurrentAccountEditScreen({super.key, required this.account});

  @override
  State<RecurrentAccountEditScreen> createState() => _RecurrentAccountEditScreenState();
}

class _RecurrentAccountEditScreenState extends State<RecurrentAccountEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _descController;
  late TextEditingController _valueController;
  late TextEditingController _dueDayController;
  late TextEditingController _observationController;
  late TextEditingController _averageValueController;
  late double _currentLaunchedValue;

  late Account _parentAccount;
  bool _isEditingParent = false;

  List<AccountType> _typesList = [];
  AccountType? _selectedType;

  List<AccountCategory> _categorias = [];
  AccountCategory? _selectedCategory;

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
  int _selectedColor = 0xFFFFFFFF;

  bool _isSaving = false;
  bool _payInAdvance = false;
  Map<String, dynamic>? _paymentInfo;
  bool _shouldRefreshOnPop = false;

  @override
  void initState() {
    super.initState();
    _initializeSync();
    _initializeAsync();
  }

  void _initializeSync() {
    // Inicializar dados síncronos
    _isEditingParent = widget.account.isRecurrent && widget.account.recurrenceId == null;
    _parentAccount = widget.account;

    _descController = TextEditingController(text: _parentAccount.description);
    _valueController = TextEditingController(text: UtilBrasilFields.obterReal(_parentAccount.value));
    _averageValueController = TextEditingController(text: UtilBrasilFields.obterReal(_parentAccount.value));
    _dueDayController = TextEditingController(text: _parentAccount.dueDay.toString());
    _observationController = TextEditingController(text: _parentAccount.observation ?? '');
    _selectedColor = _parentAccount.cardColor ?? 0xFFFFFFFF;
    _payInAdvance = _parentAccount.payInAdvance;
    _currentLaunchedValue = _parentAccount.value;
  }

  Future<void> _initializeAsync() async {
    // Carregar pai se estamos editando uma filha
    if (!_isEditingParent && widget.account.recurrenceId != null) {
      try {
        final parent = await DatabaseHelper.instance.readAccountById(widget.account.recurrenceId!);
        if (parent != null && mounted) {
          setState(() {
            _parentAccount = parent;
            if (_isEditingParent) {
              _descController.text = parent.description;
              _valueController.text = UtilBrasilFields.obterReal(parent.value);
              _dueDayController.text = parent.dueDay.toString();
              _observationController.text = parent.observation ?? '';
              _selectedColor = parent.cardColor ?? 0xFFFFFFFF;
              _payInAdvance = parent.payInAdvance;
            } else {
              _averageValueController.text = UtilBrasilFields.obterReal(parent.value);
            }
          });
        }
      } catch (e) {
        // Widget foi deativado durante o carregamento
        return;
      }
    }

    if (!mounted) return;
    await _loadInitialData();

    if (widget.account.id != null && !_isEditingParent && mounted) {
      await _loadPaymentInfo();
    }
  }

  Future<void> _loadPaymentInfo() async {
    if (widget.account.id == null) return;
    final info = await DatabaseHelper.instance.getAccountPaymentInfo(widget.account.id!);
    if (!mounted) return;
    setState(() {
      _paymentInfo = info;
    });
  }

  Future<void> _updateLaunchedValue() async {
    if (_isEditingParent || widget.account.id == null) return;
    final text = _valueController.text;
    if (text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informe o valor lançado.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final launchedValue = UtilBrasilFields.converterMoedaParaDouble(text);
    try {
      final updated = widget.account.copyWith(value: launchedValue);
      await DatabaseHelper.instance.updateAccount(updated);
      if (!mounted) return;
      setState(() {
        _currentLaunchedValue = launchedValue;
        _shouldRefreshOnPop = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valor lançado atualizado.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _openPayAccount() async {
    if (widget.account.id == null || _paymentInfo != null) return;
    final now = DateTime.now();
    final targetMonth = widget.account.month ?? now.month;
    final targetYear = widget.account.year ?? now.year;
    final startDate = DateTime(targetYear, targetMonth, 1);
    final endDate = DateTime(targetYear, targetMonth + 1, 0);
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentDialog(
          startDate: startDate,
          endDate: endDate,
          preselectedAccount: widget.account,
        ),
      ),
    );
    if (result == true) {
      await _loadPaymentInfo();
    }
  }

  Future<void> _loadInitialData() async {
    final types = await DatabaseHelper.instance.readAllTypes();
    if (!mounted) return;

    AccountType? selected;
    try {
      selected = types.firstWhere((t) => t.id == _parentAccount.typeId);
    } catch (_) {
      selected = types.isNotEmpty ? types.first : null;
    }

    if (mounted) {
      setState(() {
        _typesList = types;
        _selectedType = selected;
      });
    }

    await _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (_selectedType?.id == null) {
      if (mounted) {
        setState(() {
          _categorias = [];
          _selectedCategory = null;
        });
      }
      return;
    }

    final cats = await DatabaseHelper.instance.readAccountCategories(_selectedType!.id!);
    if (mounted) {
      setState(() {
        _categorias = cats;
        _selectedCategory = null;
      });
    }
  }

  Future<void> _saveAccount() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate() || _selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos obrigatórios.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final dueDay = int.tryParse(_dueDayController.text) ?? 1;
      if (dueDay < 1 || dueDay > 31) {
        throw Exception('Dia do mês deve estar entre 1 e 31');
      }

      final newValue = UtilBrasilFields.converterMoedaParaDouble(_valueController.text);
      final averageValue = _isEditingParent
          ? newValue
          : UtilBrasilFields.converterMoedaParaDouble(_averageValueController.text);
      final newDesc = _descController.text.trim();

      // Criar versão atualizada do pai
      final updatedParent = _parentAccount.copyWith(
        typeId: _selectedType!.id!,
        description: newDesc,
        value: averageValue,
        dueDay: dueDay,
        payInAdvance: _payInAdvance,
        cardColor: _selectedColor,
        observation: _observationController.text,
      );

      // Se estamos editando uma filha, mostrar diálogo de escolha
      if (!_isEditingParent) {
        if (!mounted) return;
        final scope = await showDialog<_RecurrentEditScope>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Editar Recorrência'),
            content: const Text('Deseja atualizar:\n\n• Somente essa instância\n• Essa e as futuras'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, _RecurrentEditScope.thisOnly),
                child: const Text('Só essa'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, _RecurrentEditScope.thisAndFuture),
                child: const Text('Essa e futuras'),
              ),
            ],
          ),
        );

        if (scope == null) {
          if (mounted) setState(() => _isSaving = false);
          return;
        }

        if (scope == _RecurrentEditScope.thisOnly) {
          // Atualizar só a instância atual
          final updated = widget.account.copyWith(
            typeId: _selectedType!.id!,
            description: newDesc,
            value: _currentLaunchedValue,
            dueDay: dueDay,
            payInAdvance: _payInAdvance,
            cardColor: _selectedColor,
            observation: _observationController.text,
          );
          await DatabaseHelper.instance.updateAccount(updated);
        } else {
          // Atualizar pai e futuras
          await DatabaseHelper.instance.updateAccount(updatedParent);
          final updateMap = updatedParent.toMap();
          updateMap.remove('id'); // Remover ID para não violar constraint UNIQUE
          await DatabaseHelper.instance.updateRecurrenceInstances(
            _parentAccount.id!,
            widget.account.month ?? DateTime.now().month,
            widget.account.year ?? DateTime.now().year,
            updateMap,
          );
        }
      } else {
        // Editando o pai - atualizar pai e todas as instâncias existentes
        await DatabaseHelper.instance.updateAccount(updatedParent);

        // Atualizar todas as instâncias existentes com os novos valores
        // Mantendo month/year originais (não recalcular datas)
        final instances = await DatabaseHelper.instance.readAllAccountsRaw();
        final children = instances.where((a) => a.recurrenceId == _parentAccount.id).toList();

        for (var child in children) {
          final updated = child.copyWith(
            typeId: _selectedType!.id!,
            description: newDesc,
            value: newValue,
            dueDay: dueDay, // Atualizar só o dia, manter month/year originais
            payInAdvance: _payInAdvance,
            cardColor: _selectedColor,
            observation: _observationController.text,
          );
          await DatabaseHelper.instance.updateAccount(updated);
        }
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recorrência atualizada com sucesso!'), backgroundColor: Colors.green),
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

  Future<void> _confirmDelete() async {
    if (_parentAccount.id == null) return;

    final isParent = _isEditingParent;
    final title = isParent ? 'Deletar Recorrência?' : 'Deletar Instância?';
    final message = isParent
        ? 'Isso removerá TODAS as instâncias mensais.'
        : 'Deseja deletar:\n\n• Só essa instância\n• Toda a recorrência';

    if (isParent) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Deletar Tudo'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _deleteRecurrence();
      }
    } else {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'single'),
              child: const Text('Só essa', style: TextStyle(color: Colors.orange)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, 'series'),
              child: const Text('Toda série'),
            ),
          ],
        ),
      );

      if (action == 'single') {
        await _deleteSingleInstance();
      } else if (action == 'series') {
        await _deleteRecurrence();
      }
    }
  }

  Future<void> _deleteSingleInstance() async {
    if (widget.account.id == null) return;
    await DatabaseHelper.instance.deleteAccount(widget.account.id!);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _deleteRecurrence() async {
    if (_parentAccount.id == null) return;
    await DatabaseHelper.instance.deleteSubscriptionSeries(_parentAccount.id!);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _descController.dispose();
    _valueController.dispose();
    _averageValueController.dispose();
    _dueDayController.dispose();
    _observationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isChild = !_isEditingParent;
    final valueLabel = _isEditingParent ? 'Valor Médio (R\$)' : 'Valor Lançado (R\$)';
    final showAverageValue = isChild;

    return ValueListenableBuilder<DateTimeRange>(
      valueListenable: PrefsService.dateRangeNotifier,
      builder: (context, range, _) {
        return PopScope(
          canPop: !_shouldRefreshOnPop,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop || !_shouldRefreshOnPop) return;
            Navigator.pop(context, true);
          },
          child: Scaffold(
            appBar: DateRangeAppBar(
              title: 'Editar Recorrência',
              range: range,
              onPrevious: () => PrefsService.shiftDateRange(-1),
              onNext: () => PrefsService.shiftDateRange(1),
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              actions: [
                if (isChild && widget.account.id != null)
                  IconButton(
                    icon: const Icon(Icons.payments),
                    tooltip: _paymentInfo != null
                        ? 'Pagamento já registrado'
                        : 'Registrar pagamento',
                    onPressed: (widget.account.id == null || _paymentInfo != null)
                        ? null
                        : _openPayAccount,
                  ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSummaryCard(),
                    const SizedBox(height: 16),

              // Paleta de cores
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: _colors
                    .map(
                      (c) => InkWell(
                        onTap: () => setState(() => _selectedColor = c.toARGB32()),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedColor == c.toARGB32()
                                  ? foregroundColorFor(c)
                                  : Colors.grey.shade400,
                              width: _selectedColor == c.toARGB32() ? 3 : 1,
                            ),
                          ),
                          child: _selectedColor == c.toARGB32()
                              ? Icon(
                                  Icons.check,
                                  size: 18,
                                  color: foregroundColorFor(c),
                                )
                              : null,
                        ),
                      ),
                    )
                    .toList(),
              ),

              const SizedBox(height: 20),

              // Tipo da conta
              DropdownButtonFormField<AccountType>(
                initialValue: _selectedType,
                decoration: buildOutlinedInputDecoration(
                  label: 'Tipo da Conta',
                  icon: Icons.account_balance_wallet,
                ),
                items: _typesList.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                onChanged: (val) async {
                  setState(() {
                    _selectedType = val;
                    _selectedCategory = null;
                  });
                  await _loadCategories();
                },
                validator: (val) => val == null ? 'Selecione um tipo' : null,
              ),

              const SizedBox(height: 12),

              if (_categorias.isNotEmpty)
                DropdownButtonFormField<AccountCategory>(
                  initialValue: _selectedCategory,
                  decoration: buildOutlinedInputDecoration(
                    label: 'Categoria',
                    icon: Icons.label,
                  ),
                  items: _categorias.map((cat) => DropdownMenuItem(value: cat, child: Text(cat.categoria))).toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val),
                ),

              if (_categorias.isNotEmpty) const SizedBox(height: 12),

              // Descrição
              TextFormField(
                controller: _descController,
                textCapitalization: TextCapitalization.sentences,
                decoration: buildOutlinedInputDecoration(
                  label: 'Descrição',
                  icon: Icons.description_outlined,
                ),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),

              const SizedBox(height: 16),

              if (showAverageValue)
                TextFormField(
                  controller: _averageValueController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, CentavosInputFormatter(moeda: true)],
                  decoration: buildOutlinedInputDecoration(
                    label: 'Valor Médio (R\$)',
                    icon: Icons.bar_chart,
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
                ),

              if (showAverageValue) const SizedBox(height: 12),

              // Valor lançado e Dia de vencimento
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _valueController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, CentavosInputFormatter(moeda: true)],
                      decoration: buildOutlinedInputDecoration(
                        label: valueLabel,
                        icon: Icons.attach_money,
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
                    ),
                  ),
                  if (showAverageValue) const SizedBox(width: 8),
                  if (showAverageValue)
                    FilledButton(
                      onPressed: _updateLaunchedValue,
                      child: const Text('Gravar'),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _dueDayController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 2,
                      decoration: buildOutlinedInputDecoration(
                        label: 'Dia (1-31)',
                        icon: Icons.calendar_today,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Obrigatório';
                        final day = int.tryParse(v);
                        if (day == null || day < 1 || day > 31) return 'Entre 1-31';
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Comportamento em feriado
              SwitchListTile(
                title: const Text('Pagar em Feriado'),
                subtitle: const Text('Antecipar para dia útil anterior'),
                value: _payInAdvance,
                onChanged: (val) => setState(() => _payInAdvance = val),
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _observationController,
                maxLines: 3,
                decoration: buildOutlinedInputDecoration(
                  label: 'Observações (Opcional)',
                  icon: Icons.note,
                  alignLabelWithHint: true,
                ),
              ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).cardColor,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue.shade700,
                  disabledBackgroundColor: Colors.blue.shade400,
                ),
                onPressed: _isSaving ? null : _saveAccount,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Gravando...' : 'Gravar'),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard() {
    final valueColor = _parentAccount.value >= 0 ? Colors.green.shade700 : Colors.red.shade700;

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
                _dueDayController.text.isEmpty ? '--' : _dueDayController.text,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.black87),
              ),
              Text(
                'do mês',
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
                  'RECORRÊNCIA',
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
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _isEditingParent ? 'Conta Pai' : 'Instância Mensal',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
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

  Widget _actionSquare({required Color color, required IconData icon, required VoidCallback onTap, required Color iconColor}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
    );
  }
}
