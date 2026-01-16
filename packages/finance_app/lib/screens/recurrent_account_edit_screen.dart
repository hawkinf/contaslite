import 'package:flutter/material.dart';
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/services.dart';
import 'package:brasil_fields/brasil_fields.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../models/account_type.dart';
import '../models/account_category.dart';
import '../widgets/app_input_decoration.dart';
import '../widgets/payment_dialog.dart';
import '../services/prefs_service.dart';
import '../utils/app_colors.dart';
import 'recebimentos_table_screen.dart';

enum _RecurrentEditScope { thisOnly, thisAndFuture, all }

class RecurrentAccountEditScreen extends StatefulWidget {
  final Account account;
  final bool isRecebimento;
  final VoidCallback? onClose;
  const RecurrentAccountEditScreen({
    super.key,
    required this.account,
    this.isRecebimento = false,
    this.onClose,
  });

  @override
  State<RecurrentAccountEditScreen> createState() =>
      _RecurrentAccountEditScreenState();
}

class _RecurrentAccountEditScreenState
    extends State<RecurrentAccountEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isDisposed = false;

  late TextEditingController _descController;
  late TextEditingController _valueController;
  late TextEditingController _dueDayController;
  late TextEditingController _observationController;
  late TextEditingController _averageValueController;

  late Account _parentAccount;
  bool _isEditingParent = false;

  List<AccountType> _typesList = [];
  AccountType? _selectedType;

  List<AccountCategory> _parentCategorias = [];
  AccountCategory? _selectedParentCategoria;

  List<AccountCategory> _categorias = [];
  AccountCategory? _selectedCategory;

  static const String _recebimentosChildSeparator = '||';

  int _selectedColor = 0xFFFFFFFF;

  bool _isSaving = false;
  bool _payInAdvance = false;
  Map<String, dynamic>? _paymentInfo;
  final bool _shouldRefreshOnPop = false;

  @override
  void initState() {
    super.initState();
    _initializeSync();
    _initializeAsync();
  }

  void _initializeSync() {
    // Inicializar dados síncronos
    _isEditingParent =
        widget.account.isRecurrent && widget.account.recurrenceId == null;
    _parentAccount = widget.account;

    _descController = TextEditingController(text: _parentAccount.description);
    _valueController = TextEditingController(
        text: UtilBrasilFields.obterReal(_parentAccount.value));
    _averageValueController = TextEditingController(
        text: UtilBrasilFields.obterReal(
            _parentAccount.estimatedValue ?? _parentAccount.value));
    _dueDayController =
        TextEditingController(text: _parentAccount.dueDay.toString());
    _observationController =
        TextEditingController(text: _parentAccount.observation ?? '');
    _selectedColor = _parentAccount.cardColor ?? 0xFFFFFFFF;
    _payInAdvance = _parentAccount.payInAdvance;
  }

  void _closeScreen() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _initializeAsync() async {
    // Carregar pai se estamos editando uma filha
    if (!_isEditingParent && widget.account.recurrenceId != null) {
      try {
        final parent = await DatabaseHelper.instance
            .readAccountById(widget.account.recurrenceId!);
        if (parent != null && mounted) {
          setState(() {
            // Atualiza referência ao pai, mas NÃO sobrescreve campos da instância filha
            _parentAccount = parent;
            if (_isEditingParent) {
              _descController.text = parent.description;
              _valueController.text = UtilBrasilFields.obterReal(parent.value);
              _dueDayController.text = parent.dueDay.toString();
              _observationController.text = parent.observation ?? '';
              _selectedColor = parent.cardColor ?? 0xFFFFFFFF;
              _payInAdvance = parent.payInAdvance;
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
    final info =
        await DatabaseHelper.instance.getAccountPaymentInfo(widget.account.id!);
    if (!mounted) return;
    setState(() {
      _paymentInfo = info;
    });
  }

  Future<void> _openPayAccount() async {
    if (widget.account.id == null || _paymentInfo != null) return;
    final now = DateTime.now();
    final targetMonth = widget.account.month ?? now.month;
    final targetYear = widget.account.year ?? now.year;
    final startDate = DateTime(targetYear, targetMonth, 1);
    final endDate = DateTime(targetYear, targetMonth + 1, 0);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final media = MediaQuery.of(dialogContext);
        final viewInsets = media.viewInsets.bottom;
        final maxWidth = (media.size.width * 0.92).clamp(280.0, 720.0);
        final availableHeight = media.size.height - viewInsets;
        final maxHeight = (availableHeight * 0.9).clamp(420.0, 900.0);
        return AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: viewInsets + 16,
          ),
          child: Dialog(
            insetPadding: EdgeInsets.zero,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: PaymentDialog(
                startDate: startDate,
                endDate: endDate,
                preselectedAccount: widget.account,
                isRecebimento: widget.isRecebimento,
              ),
            ),
          ),
        );
      },
    );
    if (result == true) {
      await _loadPaymentInfo();
    }
  }

  Future<void> _loadInitialData() async {
    final types = await DatabaseHelper.instance.readAllTypes();
    if (!mounted) return;

    final baseTypes =
        types.where((t) => !t.name.toLowerCase().contains('cart')).toList();
    final filteredTypes = widget.isRecebimento
        ? baseTypes
            .where((t) => t.name.trim().toLowerCase() == 'recebimentos')
            .toList()
        : baseTypes
            .where((t) => !t.name.toLowerCase().contains('recebimento'))
            .toList();

    AccountType? selected;
    try {
      selected = filteredTypes.firstWhere((t) => t.id == _parentAccount.typeId);
    } catch (_) {
      selected = filteredTypes.isNotEmpty ? filteredTypes.first : null;
    }

    if (mounted) {
      setState(() {
        _typesList = filteredTypes;
        _selectedType = selected;
      });
    }

    await _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (_selectedType?.id == null) {
      if (mounted) {
        setState(() {
          _parentCategorias = [];
          _selectedParentCategoria = null;
          _categorias = [];
          _selectedCategory = null;
        });
      }
      return;
    }

    final cats =
        await DatabaseHelper.instance.readAccountCategories(_selectedType!.id!);

    if (!mounted) return;

    // Para Recebimentos, separar em categorias pai e filha
    if (widget.isRecebimento) {
      final parents = <AccountCategory>[];
      final children = <AccountCategory>[];
      for (final cat in cats) {
        if (cat.categoria.contains(_recebimentosChildSeparator)) {
          children.add(cat);
        } else {
          parents.add(cat);
        }
      }
      parents.sort((a, b) => a.categoria.compareTo(b.categoria));

      // Usar a categoria pai já selecionada (que foi atualizada no setState)
      AccountCategory? selectedParent = _selectedParentCategoria;

      // Se nenhuma categoria pai está selecionada, tentar usar da conta
      if (selectedParent == null && _parentAccount.categoryId != null) {
        final catName = cats
            .where((c) => c.id == _parentAccount.categoryId)
            .firstOrNull
            ?.categoria;
        if (catName != null) {
          final parentName = catName.contains(_recebimentosChildSeparator)
              ? catName.split(_recebimentosChildSeparator).first.trim()
              : catName;
          for (final parent in parents) {
            if (parent.categoria.trim() == parentName) {
              selectedParent = parent;
              break;
            }
          }
        }
      }

      if (selectedParent == null && parents.isNotEmpty) {
        selectedParent = parents.first;
      }

      final filteredChildren = selectedParent == null
          ? <AccountCategory>[]
          : children
              .where((child) => child.categoria.startsWith(
                  '${selectedParent!.categoria}$_recebimentosChildSeparator'))
              .toList()
        ..sort((a, b) => a.categoria.compareTo(b.categoria));

      setState(() {
        _parentCategorias = parents;
        _selectedParentCategoria = selectedParent;
        _categorias = filteredChildren;

        // Selecionar categoria filha se houver uma na conta
        if (_parentAccount.categoryId != null) {
          try {
            _selectedCategory =
                cats.firstWhere((c) => c.id == _parentAccount.categoryId);
            if (!_categorias.any((c) => c.id == _selectedCategory!.id)) {
              _selectedCategory = null;
            }
          } catch (_) {
            _selectedCategory = null;
          }
        }
      });
      return;
    }

    // Para não-Recebimentos, apenas carregar categorias normalmente
    setState(() {
      _categorias = cats;
      _selectedCategory = null;
    });
  }

  Future<void> _showCategoriesDialog() async {
    if (_isDisposed) return;

    if (widget.isRecebimento) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Dialog.fullscreen(
          child: RecebimentosTableScreen(),
        ),
      );
      if (_isDisposed) return;
      await _loadCategories();
      return;
    }

    if (_selectedType?.id == null) {
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione um tipo antes de gerenciar categorias'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    await _loadCategories();

    if (!mounted || _isDisposed) return;
    await showDialog(
      context: context,
      builder: (ctx) => _CategoriasDialog(
        typeId: _selectedType!.id!,
        categorias: _categorias,
        onCategoriasUpdated: _loadCategories,
      ),
    );
  }

  String _childDisplayName(String raw) {
    if (!raw.contains(_recebimentosChildSeparator)) return raw;
    return raw.split(_recebimentosChildSeparator).last.trim();
  }

  Future<void> _saveAccount() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate() || _selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Preencha todos os campos obrigatórios.'),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final dueDay = int.tryParse(_dueDayController.text) ?? 1;
      if (dueDay < 1 || dueDay > 31) {
        throw Exception('Dia do mês deve estar entre 1 e 31');
      }

      final newValue =
          UtilBrasilFields.converterMoedaParaDouble(_valueController.text);
      final averageValue = UtilBrasilFields.converterMoedaParaDouble(
          _averageValueController.text);
      final newDesc = _descController.text.trim();

      debugPrint('💾 Salvando recorrência:');
      debugPrint('   - Valor Médio (estimatedValue): $averageValue');
      debugPrint('   - Valor Lançado (value): $newValue');

      // Criar versão atualizada do pai (será construída conforme o escopo selecionado)

      // Mostrar diálogo de escolha para salvar
      if (!mounted) return;
      final scope = await showDialog<_RecurrentEditScope>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.save, color: Colors.blue, size: 48),
          title: const Text('Salvar Alterações'),
          content: const Text(
              'Como deseja aplicar as alterações?\n\nNota: O valor lançado é específico para cada conta e nunca é propagado.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, _RecurrentEditScope.thisOnly),
              child: const Text('Somente essa conta'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, _RecurrentEditScope.thisAndFuture),
              child: const Text('Essa e futuras'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, _RecurrentEditScope.all),
              child: const Text('Todas as recorrentes'),
            ),
          ],
        ),
      );

      if (scope == null) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }

      if (scope == _RecurrentEditScope.thisOnly) {
        // Atualizar só a instância atual (incluindo valor lançado)
        final updated = widget.account.copyWith(
          typeId: _selectedType!.id!,
          description: newDesc,
          value: newValue, // Valor lançado só para essa conta
          estimatedValue: averageValue,
          dueDay: dueDay,
          payInAdvance: _payInAdvance,
          cardColor: _selectedColor,
          observation: _observationController.text,
        );
        await DatabaseHelper.instance.updateAccount(updated);
      } else if (scope == _RecurrentEditScope.thisAndFuture) {
        // Atualizar essa e futuras (mas NÃO propagar valor lançado)

        // Verificar se estamos editando o PAI ou uma FILHA
        final isEditingParentAccount = widget.account.id == _parentAccount.id;

        // Atualizar o PAI (com ou sem valor lançado dependendo se é o que estamos editando)
        final updatedParent = _parentAccount.copyWith(
          typeId: _selectedType!.id!,
          description: newDesc,
          value: isEditingParentAccount
              ? newValue
              : _parentAccount.value, // Só atualiza value se editamos o PAI
          estimatedValue: averageValue,
          dueDay: dueDay,
          payInAdvance: _payInAdvance,
          cardColor: _selectedColor,
          observation: _observationController.text,
        );
        await DatabaseHelper.instance.updateAccount(updatedParent);

        // Se não estamos editando o PAI, atualizar a conta atual com valor lançado
        if (!isEditingParentAccount) {
          final updatedThis = widget.account.copyWith(
            typeId: _selectedType!.id!,
            description: newDesc,
            value: newValue, // Valor lançado só para essa
            estimatedValue: averageValue,
            dueDay: dueDay,
            payInAdvance: _payInAdvance,
            cardColor: _selectedColor,
            observation: _observationController.text,
          );
          await DatabaseHelper.instance.updateAccount(updatedThis);
        }

        // Atualizar futuras (sem propagar valor lançado)
        final currentMonth = widget.account.month ?? DateTime.now().month;
        final currentYear = widget.account.year ?? DateTime.now().year;
        final currentDate = DateTime(currentYear, currentMonth, 1);

        final instances = await DatabaseHelper.instance.readAllAccountsRaw();
        final futureChildren = instances.where((a) {
          if (a.recurrenceId != _parentAccount.id) return false;
          if (a.id == widget.account.id) return false; // Já atualizamos essa
          final accDate =
              DateTime(a.year ?? DateTime.now().year, a.month ?? 1, 1);
          return accDate.isAfter(currentDate);
        }).toList();

        for (var child in futureChildren) {
          final updated = child.copyWith(
            typeId: _selectedType!.id!,
            description: newDesc,
            // NÃO atualizar value (valor lançado) - manter o original
            estimatedValue: averageValue,
            dueDay: dueDay,
            payInAdvance: _payInAdvance,
            cardColor: _selectedColor,
            observation: _observationController.text,
          );
          await DatabaseHelper.instance.updateAccount(updated);
        }
      } else if (scope == _RecurrentEditScope.all) {
        // Atualizar TODAS as recorrências (mas NÃO propagar valor lançado)

        // Verificar se estamos editando o PAI ou uma FILHA
        final isEditingParentAccount = widget.account.id == _parentAccount.id;

        // Atualizar o PAI (com ou sem valor lançado dependendo se é o que estamos editando)
        final updatedParent = _parentAccount.copyWith(
          typeId: _selectedType!.id!,
          description: newDesc,
          value: isEditingParentAccount
              ? newValue
              : _parentAccount.value, // Só atualiza value se editamos o PAI
          estimatedValue: averageValue,
          dueDay: dueDay,
          payInAdvance: _payInAdvance,
          cardColor: _selectedColor,
          observation: _observationController.text,
        );
        await DatabaseHelper.instance.updateAccount(updatedParent);

        // Se não estamos editando o PAI, atualizar a conta atual com valor lançado
        if (!isEditingParentAccount) {
          final updatedThis = widget.account.copyWith(
            typeId: _selectedType!.id!,
            description: newDesc,
            value: newValue, // Valor lançado só para essa
            estimatedValue: averageValue,
            dueDay: dueDay,
            payInAdvance: _payInAdvance,
            cardColor: _selectedColor,
            observation: _observationController.text,
          );
          await DatabaseHelper.instance.updateAccount(updatedThis);
        }

        // Atualizar TODAS as outras filhas (sem propagar valor lançado)
        final instances = await DatabaseHelper.instance.readAllAccountsRaw();
        final allChildren = instances.where((a) {
          if (a.recurrenceId != _parentAccount.id) return false;
          if (a.id == widget.account.id) return false; // Já atualizamos essa
          return true;
        }).toList();

        for (var child in allChildren) {
          final updated = child.copyWith(
            typeId: _selectedType!.id!,
            description: newDesc,
            // NÃO atualizar value (valor lançado) - manter o original
            estimatedValue: averageValue,
            dueDay: dueDay,
            payInAdvance: _payInAdvance,
            cardColor: _selectedColor,
            observation: _observationController.text,
          );
          await DatabaseHelper.instance.updateAccount(updated);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Recorrência atualizada com sucesso!'),
            backgroundColor: Colors.green),
      );
      _closeScreen();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
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
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Deletar Tudo'),
            ),
          ],
        ),
      );

      if (!mounted) return;
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
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'single'),
              child:
                  const Text('Só essa', style: TextStyle(color: Colors.orange)),
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
        // Confirmar antes de apagar
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 48),
            title: const Text('Confirmar Exclusão'),
            content: Text(
                'Tem certeza que deseja apagar somente esta instância de "${widget.account.description}"?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Sim, Apagar'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (confirmed != true) return;
        final deleted = await _deleteSingleInstance();
        if (!mounted) return;
        if (deleted) _closeScreen();
      } else if (action == 'series') {
        // Confirmar antes de apagar
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded,
                color: Colors.orange, size: 48),
            title: const Text('Confirmar Exclusão'),
            content: Text(
                'Tem certeza que deseja apagar TODA a série de "${widget.account.description}"?\n\nEsta ação não pode ser desfeita.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Sim, Apagar'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (confirmed != true) return;
        final deleted = await _deleteRecurrence();
        if (!mounted) return;
        if (deleted) _closeScreen();
      }
    }
  }

  Future<bool> _deleteSingleInstance() async {
    if (widget.account.id == null) return false;
    await DatabaseHelper.instance.deleteAccount(widget.account.id!);
    return true;
  }

  Future<bool> _deleteRecurrence() async {
    if (_parentAccount.id == null) return false;
    await DatabaseHelper.instance.deleteSubscriptionSeries(_parentAccount.id!);
    return true;
  }

  @override
  void dispose() {
    _isDisposed = true;
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
    final valueLabel =
        _isEditingParent ? 'Valor Lançado (R\$)' : 'Valor Lançado (R\$)';
    final showAverageValue = true; // Sempre mostrar Valor Médio

    return ValueListenableBuilder<DateTimeRange>(
      valueListenable: PrefsService.dateRangeNotifier,
      builder: (context, range, _) {
        return PopScope(
          canPop: !_shouldRefreshOnPop,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop || !_shouldRefreshOnPop) return;
            _closeScreen();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                  widget.isRecebimento ? 'Editar Recebimento' : 'Editar Conta'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _closeScreen,
              ),
              actions: [
                if (isChild && widget.account.id != null)
                  IconButton(
                    icon: const Icon(Icons.payments),
                    tooltip: _paymentInfo != null
                        ? (widget.isRecebimento
                            ? 'Recebimento já registrado'
                            : 'Pagamento já registrado')
                        : (widget.isRecebimento
                            ? 'Registrar recebimento'
                            : 'Registrar pagamento'),
                    onPressed:
                        (widget.account.id == null || _paymentInfo != null)
                            ? null
                            : _openPayAccount,
                  ),
                // Botão de deletar
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Deletar',
                  onPressed: _confirmDelete,
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
                    // Card com tipo, categoria e descrição
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Para Recebimentos: Categoria Pai (Tipo de Recebimento)
                            if (widget.isRecebimento &&
                                _parentCategorias.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  DropdownButtonFormField<AccountCategory>(
                                    initialValue: _selectedParentCategoria,
                                    decoration: buildOutlinedInputDecoration(
                                      label: 'Tipo de Recebimento',
                                      icon: Icons.account_balance_wallet,
                                    ),
                                    items: _parentCategorias
                                        .map((cat) => DropdownMenuItem(
                                              value: cat,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    cat.logo ?? '📁',
                                                    style: const TextStyle(
                                                        fontSize: 18),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(cat.categoria),
                                                ],
                                              ),
                                            ))
                                        .toList(),
                                    selectedItemBuilder:
                                        (BuildContext context) {
                                      return _parentCategorias
                                          .map((cat) => Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                    '${cat.logo ?? '📁'} ${cat.categoria}'),
                                              ))
                                          .toList();
                                    },
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedParentCategoria = val;
                                        _selectedCategory = null;
                                        _categorias = [];
                                      });
                                      _loadCategories();
                                    },
                                    validator: (val) => val == null
                                        ? 'Selecione um tipo de recebimento'
                                        : null,
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
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                    ),
                                    onPressed: _showCategoriesDialog,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              )
                            // Para não-Recebimentos: Tipo da Conta normal
                            else if (!widget.isRecebimento)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  DropdownButtonFormField<AccountType>(
                                    initialValue: _selectedType,
                                    decoration: buildOutlinedInputDecoration(
                                      label: 'Tipo da Conta',
                                      icon: Icons.account_balance_wallet,
                                    ),
                                    items: _typesList
                                        .map((t) => DropdownMenuItem(
                                              value: t,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    t.logo ?? '📁',
                                                    style: const TextStyle(
                                                        fontSize: 18),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(t.name),
                                                ],
                                              ),
                                            ))
                                        .toList(),
                                    selectedItemBuilder:
                                        (BuildContext context) {
                                      return _typesList
                                          .map((t) => Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                    '${t.logo ?? '📁'} ${t.name}'),
                                              ))
                                          .toList();
                                    },
                                    onChanged: (val) async {
                                      setState(() {
                                        _selectedType = val;
                                        _selectedCategory = null;
                                      });
                                      await _loadCategories();
                                    },
                                    validator: (val) => val == null
                                        ? 'Selecione um tipo'
                                        : null,
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
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                    ),
                                    onPressed: _showCategoriesDialog,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),

                            if (_categorias.isNotEmpty)
                              DropdownButtonFormField<AccountCategory>(
                                initialValue: _selectedCategory,
                                decoration: buildOutlinedInputDecoration(
                                  label: 'Categoria',
                                  icon: Icons.label,
                                ),
                                items: _categorias.map((cat) {
                                  final displayText = widget.isRecebimento
                                      ? _childDisplayName(cat.categoria)
                                      : cat.categoria;
                                  return DropdownMenuItem(
                                    value: cat,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          cat.logo ?? '📁',
                                          style: const TextStyle(fontSize: 18),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(displayText),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                selectedItemBuilder: (BuildContext context) {
                                  return _categorias.map((cat) {
                                    final displayText = widget.isRecebimento
                                        ? _childDisplayName(cat.categoria)
                                        : cat.categoria;
                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                          '${cat.logo ?? '📁'} $displayText'),
                                    );
                                  }).toList();
                                },
                                onChanged: (val) =>
                                    setState(() => _selectedCategory = val),
                              ),

                            if (_categorias.isNotEmpty)
                              const SizedBox(height: 12),

                            // Descrição
                            TextFormField(
                              controller: _descController,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: buildOutlinedInputDecoration(
                                label: widget.isRecebimento
                                    ? 'Descrição do Recebimento'
                                    : 'Descrição (Ex: TV Nova, Aluguel)',
                                icon: Icons.description_outlined,
                              ),
                              validator: (v) =>
                                  v!.isEmpty ? 'Obrigatório' : null,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Card com valores e data
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Dia do vencimento
                            TextFormField(
                              controller: _dueDayController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              maxLength: 2,
                              decoration: buildOutlinedInputDecoration(
                                label: widget.isRecebimento
                                    ? 'Dia Base do Recebimento (1-31)'
                                    : 'Dia Base do Vencimento (1-31)',
                                icon: Icons.calendar_today,
                              ).copyWith(counter: const SizedBox.shrink()),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Obrigatório';
                                }
                                final day = int.tryParse(v);
                                if (day == null || day < 1 || day > 31) {
                                  return 'Entre 1-31';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // Valor Total / Valor Médio
                            TextFormField(
                              controller: _averageValueController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                CentavosInputFormatter(moeda: true)
                              ],
                              decoration: buildOutlinedInputDecoration(
                                label: 'Valor Total (R\$)',
                                icon: Icons.attach_money,
                              ),
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Obrigatório' : null,
                            ),

                            const SizedBox(height: 16),

                            // Valor Lançado (se for conta recorrente)
                            if (showAverageValue)
                              TextFormField(
                                controller: _valueController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  CentavosInputFormatter(moeda: true)
                                ],
                                decoration: buildOutlinedInputDecoration(
                                  label: valueLabel,
                                  icon: Icons.attach_money,
                                ),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Obrigatório'
                                    : null,
                              ),

                            if (showAverageValue) const SizedBox(height: 16),

                            // Comportamento em feriado
                            SwitchListTile(
                              title: Text(widget.isRecebimento
                                  ? 'Receber em Feriado'
                                  : 'Pagar em Feriado'),
                              subtitle: const Text(
                                  'Antecipar para dia útil anterior'),
                              value: _payInAdvance,
                              onChanged: (val) =>
                                  setState(() => _payInAdvance = val),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Card com observações
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: _observationController,
                          maxLines: 3,
                          decoration: buildOutlinedInputDecoration(
                            label: 'Observações (Opcional)',
                            icon: Icons.note,
                            alignLabelWithHint: true,
                          ),
                        ),
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
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('Cancelar'),
                      onPressed: _isSaving ? null : _closeScreen,
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
                        padding: const EdgeInsets.symmetric(
                            vertical: 18, horizontal: 32),
                        backgroundColor: Colors.green.shade600,
                        disabledBackgroundColor:
                            Colors.green.shade600.withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isSaving ? null : _saveAccount,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Icon(Icons.check_circle, size: 24),
                      label: Text(
                        _isSaving ? 'Gravando...' : 'Gravar',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final exists = await DatabaseHelper.instance
        .checkAccountCategoryExists(widget.typeId, text);
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta categoria já existe'),
          backgroundColor: AppColors.error,
        ),
      );
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
            child: const Text('Deletar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteAccountCategory(id);
      setState(() {
        _categorias.removeWhere((d) => d.id == id);
      });
      widget.onCategoriasUpdated();
    }
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
            TextField(
              controller: _newCategoriaController,
              decoration: InputDecoration(
                labelText: 'Nova Categoria',
                prefixIcon: const Icon(Icons.add),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (_) => _addCategory(),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _addCategory,
              icon: const Icon(Icons.save),
              label: const Text('Adicionar'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _categorias.isEmpty
                  ? const Center(child: Text('Nenhuma categoria cadastrada'))
                  : ListView.builder(
                      itemCount: _categorias.length,
                      itemBuilder: (context, index) {
                        final cat = _categorias[index];
                        return Card(
                          child: ListTile(
                            leading: Text(cat.logo ?? '📂',
                                style: const TextStyle(fontSize: 18)),
                            title: Text(cat.categoria),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: cat.id != null
                                  ? () => _deleteCategory(cat.id!)
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
