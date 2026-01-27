// ignore_for_file: prefer_single_quotes, deprecated_member_use, prefer_const_constructors, prefer_const_literals_to_create_immutables, prefer_interpolation_to_compose_strings

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brasil_fields/brasil_fields.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../models/account_type.dart';
import '../models/account_category.dart';
import '../services/prefs_service.dart';
import '../services/holiday_service.dart';
import '../utils/app_colors.dart';
import '../utils/formatters.dart';
import 'account_types_screen.dart';
import 'recebimentos_table_screen.dart';
import '../utils/installment_utils.dart';
import '../widgets/icon_picker_dialog.dart';
import '../ui/components/app_modal_header.dart';
import '../ui/components/color_picker_field.dart';
import '../ui/components/standard_modal_shell.dart';
import '../ui/components/lancamento_form_padrao.dart';
import '../widgets/calculator_dialog.dart';

const List<String> _monthShortLabels = [
  'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
  'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
];

// Definindo InstallmentDraft (Mantido para a tabela)
class InstallmentDraft {
  int index;
  DateTime originalDate;
  DateTime adjustedDate;
  String? warning;
  double value;
  final TextEditingController valueController;
  final TextEditingController dateController;

  InstallmentDraft({
    required this.index,
    required this.originalDate,
    required this.adjustedDate,
    this.warning,
    required this.value,
  })  : valueController =
            TextEditingController(text: UtilBrasilFields.obterReal(value)),
        dateController = TextEditingController(
            text: DateFormat('dd/MM/yyyy').format(adjustedDate));
}

class AccountFormScreen extends StatefulWidget {
  final Account? accountToEdit;
  final String? typeNameFilter;
  final bool lockTypeSelection;
  final bool useInstallmentDropdown;
  final bool isRecebimento;
  final bool showAppBar; // Controla se mostra AppBar (false para Dialog)
  final VoidCallback? onClose; // Callback para fechar inline edit

  const AccountFormScreen({
    super.key,
    this.accountToEdit,
    this.typeNameFilter,
    this.lockTypeSelection = false,
    this.useInstallmentDropdown = false,
    this.isRecebimento = false,
    this.showAppBar = true, // Por padrão mostra AppBar
    this.onClose,
  });

  @override
  State<AccountFormScreen> createState() => _AccountFormScreenState();
}

class AccountEditDialog extends StatelessWidget {
  final Account accountToEdit;
  final bool isRecebimento;

  const AccountEditDialog({
    super.key,
    required this.accountToEdit,
    required this.isRecebimento,
  });
  
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final dialogWidth = (media.size.width * 0.92).clamp(0.0, 760.0);
    final availableHeight = media.size.height - media.viewInsets.bottom;
    final maxHeight = availableHeight * 0.88;
    final title = isRecebimento ? 'Editar Recebimento' : 'Editar Conta';

    return StandardModalShell(
      title: title,
      onClose: () => Navigator.pop(context),
      maxWidth: dialogWidth,
      maxHeight: maxHeight,
      scrollBody: false,
      bodyPadding: EdgeInsets.zero,
      body: AccountFormScreen(
        accountToEdit: accountToEdit,
        isRecebimento: isRecebimento,
        showAppBar: false,
      ),
    );
  }
}

class _LaunchInfo {
  final double total;
  final String? dateLabel;
  final bool hadPayment;

  const _LaunchInfo({required this.total, this.dateLabel, required this.hadPayment});
}

class _AccountFormScreenState extends State<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();

  // NOVOS CONTROLLERS PARA VALOR TOTAL E QTD PARCELAS
  final _totalValueController = TextEditingController();
  final _installmentsQtyController = TextEditingController(text: "1");

  final _recurrentValueController = TextEditingController();
  final _recurrentLaunchedValueController = TextEditingController();
  final _recurrentStartYearController = TextEditingController();
  final _dateController = TextEditingController(); // Data Vencimento
  final _observationController = TextEditingController();
  late final TextInputFormatter _dateMaskFormatter;

  int _entryMode = 0; // 0 = Avulsa/Parcelada, 1 = Recorrente Fixa
  Account? _editingAccount; // Conta sendo editada (pode ser diferente de widget.accountToEdit se for filha)

  final List<Color> _colors = AppColors.essentialPalette;
  int _selectedColor = 0xFFFFFFFF; // Branco padrão

  DateTime? _mainOriginalDueDate;
  DateTime? _mainAdjustedDueDate;
  bool _mainDueDateWasAdjusted = false;

  AccountType? _selectedType;
  AccountCategory? _selectedCategory;
  List<AccountType> _typesList = [];
  List<AccountCategory> _categorias = [];
  List<AccountCategory> _parentCategorias = [];
  AccountCategory? _selectedParentCategoria;
  static const String _recebimentosChildSeparator = '||';

  List<InstallmentDraft> _installments = [];
  int _recurrentDay = 10;
  int _recurrentStartMonth = 0; // Mês de início da recorrência (0 = janeiro, ...11 = dezembro)
  int _recurrentStartYear = 0; // Ano de início da recorrência
  bool _payInAdvance = false;
  bool _isSaving = false;
  bool _isLoadingData = true; // Indica se está carregando dados iniciais
  bool _isDisposed = false; // Flag para evitar operações após dispose

  // Soma pagamentos ligados a uma conta pai e todas as contas com recurrenceId = parentId
  Future<_LaunchInfo> _sumPaymentsForRecurrence(int parentId) async {
    double total = 0.0;
    bool hasAnyPayment = false;
    DateTime? latestDate;

    final db = await DatabaseHelper.instance.database;

    // Pagamentos diretamente ligados ao pai
    final parentPays = await DatabaseHelper.instance.readPaymentsByAccountId(parentId);
    debugPrint('💳 Pagamentos no pai ($parentId): ${parentPays.length} -> [${parentPays.map((p) => '${p.accountId}:${p.value}').join(', ')}]');
    if (parentPays.isNotEmpty) hasAnyPayment = true;
    for (final payment in parentPays) {
      total += payment.value;
      final parsed = DateTime.tryParse(payment.paymentDate);
      if (parsed != null) {
        if (latestDate == null) {
          latestDate = parsed;
        } else if (parsed.isAfter(latestDate)) {
          latestDate = parsed;
        }
      }
    }
    // Removido fallback: não somar value do pai sem pagamentos

    // Buscar todas as contas (filhas) desta recorrência, independentemente de mês/ano
    final childRows = await db.query(
      'accounts',
      columns: ['id', 'value', 'isRecurrent', 'month', 'year', 'description'],
      where: 'recurrenceId = ?',
      whereArgs: [parentId],
    );
    for (final row in childRows) {
      final childId = row['id'] as int?;
      if (childId == null) continue;
      final childValue = (row['value'] as num?)?.toDouble() ?? 0.0;
      final childIsRecurrent = (row['isRecurrent'] as int? ?? 0) == 1;
      final childMonth = row['month'];
      final childYear = row['year'];
      final childDesc = row['description'];

      debugPrint('🧾 Conta filha ($childId) ${childDesc ?? ''} [$childMonth/$childYear] valor=$childValue isRec=$childIsRecurrent');

      final childPays = await DatabaseHelper.instance.readPaymentsByAccountId(childId);
      debugPrint('💳 Pagamentos na filha ($childId): ${childPays.length} -> [${childPays.map((p) => '${p.accountId}:${p.value}').join(', ')}]');
      if (childPays.isNotEmpty) hasAnyPayment = true;
      for (final payment in childPays) {
        total += payment.value;
        final parsed = DateTime.tryParse(payment.paymentDate);
        if (parsed != null) {
          if (latestDate == null) {
            latestDate = parsed;
          } else if (parsed.isAfter(latestDate)) {
            latestDate = parsed;
          }
        }
      }

      // Removido fallback: não somar value das filhas sem pagamentos
      // Valor Lançado só deve refletir pagamentos reais
    }

    // Removido fallback: Valor Lançado só deve aparecer quando há pagamentos reais
    // Se não há pagamentos, total permanece 0 e campos ficam vazios

    debugPrint('💰 Total lançado (pai + todas as filhas) para recurrenceId=$parentId: $total (pagamentos? $hasAnyPayment)');
    final dateLabel = latestDate != null
        ? (latestDate.day == 1
            ? DateFormat('MM/yyyy').format(latestDate)
            : DateFormat('dd/MM/yyyy').format(latestDate))
        : null;
    return _LaunchInfo(total: total, dateLabel: dateLabel, hadPayment: hasAnyPayment);
  }

  String get _typeLabel =>
      widget.isRecebimento ? 'Tipo de Recebimento' : 'Tipo da Conta';
  String get _baseDateLabel => widget.isRecebimento
      ? 'Data Base do Recebimento'
      : 'Dia Base do Vencimento';
  String get _descriptionLabel => 'Descrição';
  String get _typeSelectMessage => widget.isRecebimento
      ? 'Selecione um tipo de recebimento primeiro'
      : 'Selecione um tipo de conta primeiro';
  String get _typeSelectErrorMessage => widget.isRecebimento
      ? 'Selecione um tipo de recebimento'
      : 'Selecione um tipo';
  String get _missingTypesMessage => widget.isRecebimento
      ? 'Cadastre Tipos de Recebimento Primeiro!'
      : 'Cadastre Tipos Primeiro!';

  String _saveButtonLabel() {
    if (_entryMode == 0) {
      return 'Gravar';
    }
    return 'Gravar';
  }

  void _closeScreen() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.pop(context);
    }
  }

  bool _isRecebimentosChild(AccountCategory category) {
    return category.categoria.contains(_recebimentosChildSeparator);
  }

  String _childDisplayName(String raw) {
    if (!raw.contains(_recebimentosChildSeparator)) return raw;
    return raw.split(_recebimentosChildSeparator).last.trim();
  }

  /// Retorna a categoria selecionada validada (garante que está na lista de categorias)
  AccountCategory? _getValidatedSelectedCategory() {
    if (_selectedCategory == null) return null;
    // Verificar se a categoria selecionada está na lista de categorias
    if (_categorias.any((c) => c.id == _selectedCategory!.id)) {
      return _selectedCategory;
    }
    // Se não estiver na lista, retornar null (evita erro no dropdown)
    return null;
  }

  /// Retorna a categoria pai selecionada validada
  AccountCategory? _getValidatedSelectedParentCategory() {
    if (_selectedParentCategoria == null) return null;
    // Verificar se a categoria pai selecionada está na lista de categorias pai
    if (_parentCategorias.any((c) => c.id == _selectedParentCategoria!.id)) {
      return _selectedParentCategoria;
    }
    // Se não estiver na lista, retornar null (evita erro no dropdown)
    return null;
  }

  /// Retorna o tipo selecionado validado
  AccountType? _getValidatedSelectedType() {
    if (_selectedType == null) return null;
    // Verificar se o tipo selecionado está na lista de tipos
    if (_typesList.any((t) => t.id == _selectedType!.id)) {
      return _selectedType;
    }
    // Se não estiver na lista, retornar null (evita erro no dropdown)
    return null;
  }

  /// Valida e ajusta um dia do mês para evitar datas inválidas (ex: 31/02)
  int _validateAndAdjustDay(int day, int month, int year) {
    // Definir o máximo de dias para cada mês
    final daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    
    // Verificar se é ano bissexto
    if ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)) {
      daysInMonth[1] = 29;
    }
    
    // Se o dia exceder o máximo do mês, ajustar para o último dia do mês
    if (day > daysInMonth[month - 1]) {
      return daysInMonth[month - 1];
    }
    return day;
  }

  @override
  void initState() {
    super.initState();
    
    // Inicializar mês/ano com os valores atuais
    final now = DateTime.now();
    _recurrentStartMonth = now.month - 1; // 0-11
    _recurrentStartYear = now.year;
    _recurrentStartYearController.text = _recurrentStartYear.toString();
    
    // Valor Lançado vazio para nova conta (só preenchido via action button)
    _recurrentLaunchedValueController.text = '';
    
    _dateMaskFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
      // Remove non-digits
      String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

      // Accept up to 8 digits (ddmmyyyy) but also allow 4 (ddmm)
      if (digitsOnly.length > 8) {
        digitsOnly = digitsOnly.substring(0, 8);
      }

      // Format: dd/mm or dd/mm/yy or dd/mm/yyyy
      String formatted = '';
      for (int i = 0; i < digitsOnly.length; i++) {
        formatted += digitsOnly[i];
        if (i == 1 && digitsOnly.length > 2) {
          formatted += '/';
        } else if (i == 3 && digitsOnly.length > 4) {
          formatted += '/';
        }
      }

      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    });
    if (widget.accountToEdit != null) {
      var acc = widget.accountToEdit!;

      debugPrint('📋 EDITANDO CONTA: ${acc.description}');
      debugPrint('   - isRecurrent: ${acc.isRecurrent}');
      debugPrint('   - recurrenceId: ${acc.recurrenceId}');
      debugPrint('   - month: ${acc.month}, year: ${acc.year}');

      // Se é filha de uma recorrência, carregar pai e atualizar após inicialização
      if (acc.recurrenceId != null) {
        final parentId = acc.recurrenceId;
        debugPrint(
            '🔄 Parcela filha detectada, carregando recorrência pai (id=$parentId)...');

        // Carregar o pai no postFrameCallback para garantir que setState funcione
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            // Buscar apenas o pai (não TODAS as contas)
            final parent = await DatabaseHelper.instance.getAccountById(parentId);
            if (parent != null && parent.isRecurrent && mounted && parentId != null) {
              // Buscar apenas as filhas desta recorrência
              final children = await DatabaseHelper.instance.getAccountsByRecurrenceId(parentId);
              if (children.isNotEmpty) {
                final first = children.first;
                _recurrentStartMonth = (first.month ?? DateTime.now().month) - 1;
                _recurrentStartYear = first.year ?? DateTime.now().year;
                _recurrentStartYearController.text = _recurrentStartYear.toString();
              }

              _editingAccount = parent;
              debugPrint(
                  '✅ Recorrência pai carregada: ${parent.description}, valor=${parent.value}');

              // Buscar valor lançado (pagamentos do pai + de TODAS as filhas)
              _LaunchInfo totalLaunched = const _LaunchInfo(total: 0.0, dateLabel: null, hadPayment: false);
              if (parent.id != null) {
                totalLaunched = await _sumPaymentsForRecurrence(parent.id!);
              }

              if (mounted) {
                setState(() {
                  _descController.text = parent.description;
                    // Usar estimatedValue se disponível para o valor médio
                    final avgValue = parent.estimatedValue ?? parent.value;
                    _totalValueController.text =
                      UtilBrasilFields.obterReal(avgValue);
                    _recurrentValueController.text =
                      UtilBrasilFields.obterReal(avgValue);
                  _recurrentLaunchedValueController.text = totalLaunched.total > 0 ? UtilBrasilFields.obterReal(totalLaunched.total) : '';
                  _recurrentDay = parent.dueDay;
                  _payInAdvance = parent.payInAdvance;
                  _observationController.text = parent.observation ?? "";
                  _selectedColor = parent.cardColor ?? 0xFFFFFFFF;
                  _entryMode = 1; // Recorrente
                  // Validar dueDay para evitar datas inválidas
                  final now = DateTime.now();
                  final day = _validateAndAdjustDay(parent.dueDay, now.month, now.year);
                  _dateController.text = DateFormat('dd/MM/yyyy').format(
                      DateTime(now.year, now.month, day));
                  _installmentsQtyController.text = "recorrente";
                });
              }
            }
          } catch (e) {
            debugPrint('❌ Erro ao carregar recorrência pai: $e');
          }
        });
      } else if (acc.isRecurrent) {
        // A conta PAI tem month/year próprios, usar diretamente do acc
        debugPrint('🔧 Editando pai recorrente: id=${acc.id}, month=${acc.month}, year=${acc.year}');
        
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            // Calcular valor lançado do pai + todas as filhas
            _LaunchInfo totalLaunched = const _LaunchInfo(total: 0.0, dateLabel: null, hadPayment: false);
            if (acc.id != null) {
              totalLaunched = await _sumPaymentsForRecurrence(acc.id!);
            }
            
            if (mounted) {
              setState(() {
                // Usar month/year do PAI, não das filhas!
                _recurrentStartMonth = (acc.month ?? DateTime.now().month) - 1;
                _recurrentStartYear = acc.year ?? DateTime.now().year;
                _recurrentStartYearController.text = _recurrentStartYear.toString();
                _recurrentLaunchedValueController.text = totalLaunched.total > 0 ? UtilBrasilFields.obterReal(totalLaunched.total) : '';

                debugPrint('🔧 Valores setados: mês=$_recurrentStartMonth, ano=$_recurrentStartYear, lançado=${totalLaunched.total}');
              });
            }
          } catch (e) {
            debugPrint('❌ Erro ao carregar instâncias da recorrência: $e');
          }
        });
      }

      // Inicializar com dados da conta (será substituído pelo pai se for filha)
      _editingAccount = acc;
      _descController.text = acc.description;
      // Usar estimatedValue se disponível, senão usar value
      final avgValue = acc.estimatedValue ?? acc.value;
      _recurrentValueController.text = UtilBrasilFields.obterReal(avgValue);
      // Buscar valor lançado inicial - só preenche se houver pagamentos (total > 0)
      if (acc.id != null) {
        _sumPaymentsForRecurrence(acc.id!).then((info) {
          if (mounted) {
            setState(() {
              _recurrentLaunchedValueController.text = info.total > 0 ? UtilBrasilFields.obterReal(info.total) : '';
            });
          }
        });
      }
      _recurrentDay = acc.dueDay;
      _payInAdvance = acc.payInAdvance;
      _observationController.text = acc.observation ?? "";
      _selectedColor = acc.cardColor ?? 0xFFFFFFFF;

      // Detectar se é recorrente ou avulsa/parcelada
      // SE é filha de uma recorrência, tratá como recorrente (será atualizado pelo callback)
      if (acc.isRecurrent || acc.recurrenceId != null) {
        _entryMode = 1; // Recorrente
        _installmentsQtyController.text = "recorrente";
        _totalValueController.text = UtilBrasilFields.obterReal(acc.value);
        // Validar dueDay para evitar datas inválidas
        final now = DateTime.now();
        final day = _validateAndAdjustDay(acc.dueDay, now.month, now.year);
        _dateController.text = DateFormat('dd/MM/yyyy').format(
            DateTime(now.year, now.month, day));
        debugPrint('✅ _entryMode setado para 1 (Recorrente) por isRecurrent ou recurrenceId');
      } else {
        _entryMode = 0; // Avulsa/Parcelada
        // Carregar valor total e data
        _totalValueController.text = UtilBrasilFields.obterReal(acc.value);
        // Validar dueDay para evitar datas inválidas (ex: 31/02)
        final year = acc.year ?? DateTime.now().year;
        final month = acc.month ?? DateTime.now().month;
        final day = _validateAndAdjustDay(acc.dueDay, month, year);
        _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime(
            year,
            month,
            day));
        // Definir quantidade de parcelas como 1 (pode ser editado depois)
        _installmentsQtyController.text = "1";
        debugPrint('❌ _entryMode setado para 0 (Avulsa) - não é recorrente');
      }
    } else {
      _setInitialDate();
    }

    // Carregar dados após a tela ser renderizada (não bloqueia a UI)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final sw = Stopwatch()..start();
      debugPrint('⏳ AccountFormScreen: _loadInitialData...');
      await _loadInitialData();
      debugPrint('✅ AccountFormScreen: _loadInitialData ok (${sw.elapsedMilliseconds}ms)');
      sw.reset();
      debugPrint('⏳ AccountFormScreen: _loadPreferences...');
      await _loadPreferences();
      debugPrint('✅ AccountFormScreen: _loadPreferences ok (${sw.elapsedMilliseconds}ms)');
      // Only update installments if editing an existing account with values
      if (widget.accountToEdit != null && _totalValueController.text.isNotEmpty) {
        debugPrint('⏳ AccountFormScreen: _onMainDateChanged (init)...');
        _onMainDateChanged(_dateController.text);
        debugPrint('✅ AccountFormScreen: _onMainDateChanged concluído');
      }
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    });
  }

  Future<void> _loadCategories() async {
    debugPrint('🔧 _loadCategories: _selectedType=${_selectedType?.name} (id=${_selectedType?.id})');
    debugPrint('🔧 _loadCategories: widget.isRecebimento=${widget.isRecebimento}');
    
    if (_selectedType?.id == null) {
      if (mounted) {
        setState(() {
          _categorias = [];
          _parentCategorias = [];
          _selectedParentCategoria = null;
        });
      }
      return;
    }

    final categorias =
        await DatabaseHelper.instance.readAccountCategories(_selectedType!.id!);
    
    debugPrint('🔧 _loadCategories: categorias carregadas: ${categorias.length}');

    if (!mounted) return;

    if (!widget.isRecebimento) {
      setState(() {
        _categorias = categorias;
        final editing = widget.accountToEdit;
        if (editing != null) {
          final desiredId = editing.categoryId;
          debugPrint('🔧 _loadCategories (não-Recebimento): desiredId=$desiredId');
          AccountCategory? resolved;
          if (desiredId != null) {
            for (final category in categorias) {
              if (category.id == desiredId) {
                resolved = category;
                break;
              }
            }
          }
          if (resolved == null) {
            final descLower = editing.description.trim().toLowerCase();
            for (final category in categorias) {
              if (category.categoria.trim().toLowerCase() == descLower) {
                resolved = category;
                break;
              }
            }
          }
          debugPrint('🔧 _loadCategories (não-Recebimento): resolved=${resolved?.categoria}');
          if (resolved != null) _selectedCategory = resolved;
        }
      });
      return;
    }

    final editing = widget.accountToEdit;
    final desiredId = editing?.categoryId;
    AccountCategory? desiredCategory;
    if (desiredId != null) {
      for (final category in categorias) {
        if (category.id == desiredId) {
          desiredCategory = category;
          break;
        }
      }
    }
    if (desiredCategory == null && editing != null) {
      final descLower = editing.description.trim().toLowerCase();
      for (final category in categorias) {
        if (category.categoria.trim().toLowerCase() == descLower) {
          desiredCategory = category;
          break;
        }
      }
    }

    final parents = <AccountCategory>[];
    final children = <AccountCategory>[];
    for (final cat in categorias) {
      if (_isRecebimentosChild(cat)) {
        children.add(cat);
      } else {
        parents.add(cat);
      }
    }
    parents.sort((a, b) => a.categoria.compareTo(b.categoria));

    AccountCategory? selectedParent = _selectedParentCategoria;
    if (desiredCategory != null && _isRecebimentosChild(desiredCategory)) {
      final parentName =
          desiredCategory.categoria.split(_recebimentosChildSeparator).first.trim();
      for (final parent in parents) {
        if (parent.categoria.trim() == parentName) {
          selectedParent = parent;
          break;
        }
      }
    }
    if (selectedParent == null && parents.isNotEmpty) {
      selectedParent = parents.first;
    } else if (selectedParent != null &&
        !parents.any((p) => p.id == selectedParent!.id)) {
      selectedParent = parents.isNotEmpty ? parents.first : null;
    }

    final filteredChildren = selectedParent == null
        ? <AccountCategory>[]
        : children
            .where((child) =>
                child.categoria.startsWith(
                    '${selectedParent!.categoria}$_recebimentosChildSeparator'))
            .toList()
          ..sort((a, b) => a.categoria.compareTo(b.categoria));

    if (mounted) {
      setState(() {
        _parentCategorias = parents;
        _selectedParentCategoria = selectedParent;
        _categorias = filteredChildren;
        
        // Se temos uma categoria desejada (editando conta existente)
        if (desiredCategory != null) {
          // Verificar se está nos filhos filtrados
          if (filteredChildren.any((c) => c.id == desiredCategory!.id)) {
            _selectedCategory = desiredCategory;
          } else {
            // Se não estiver, pode ser porque o pai mudou - manter null
            _selectedCategory = null;
          }
        } else {
          // Se não há categoria desejada, verificar se a selecionada atual ainda é válida
          if (_selectedCategory != null &&
              !_categorias.any((c) => c.id == _selectedCategory!.id)) {
            _selectedCategory = null;
          }
        }
      });
    }
  }

  Future<void> _showCategoriesDialog() async {
    if (_isDisposed) return;

    if (widget.isRecebimento) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog.fullscreen(
          child: const RecebimentosTableScreen(),
        ),
      );
      if (_isDisposed) return;
      await _loadCategories();
      return;
    }
    if (_selectedType?.id == null) {
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_typeSelectMessage), backgroundColor: AppColors.warning),
        );
      }
      return;
    }

    await _loadCategories();

    if (!mounted || _isDisposed) return;
    showDialog(
      context: context,
      builder: (ctx) => _CategoriasDialog(
        typeId: _selectedType!.id!,
        categorias: _categorias,
        onCategoriasUpdated: _loadCategories,
      ),
    );
  }

  Future<void> _loadInitialData() async {
    debugPrint('🔧 _loadInitialData: widget.isRecebimento=${widget.isRecebimento}');
    debugPrint('🔧 _loadInitialData: widget.accountToEdit=${widget.accountToEdit?.id}, typeId=${widget.accountToEdit?.typeId}, categoryId=${widget.accountToEdit?.categoryId}');
    
    final types = await DatabaseHelper.instance.readAllTypes();

    final baseTypes =
        types.where((t) => !t.name.toLowerCase().contains('cart')).toList();

    final typeFilter = widget.typeNameFilter?.trim();
    var filteredTypes = baseTypes;

    // Filtrar tipos baseado em isRecebimento
    if (widget.isRecebimento) {
      // Para recebimentos, incluir APENAS o tipo "Recebimentos"
      filteredTypes = baseTypes
          .where((t) => t.name.trim().toLowerCase() == 'recebimentos')
          .toList();
    } else {
      // Para não-recebimentos, excluir "Recebimentos" do dropdown
      filteredTypes = baseTypes
          .where((t) => !t.name.toLowerCase().contains('recebimento'))
          .toList();
    }

    // Se houver um filtro específico de tipo, aplicar sobre o resultado anterior
    if (typeFilter != null && typeFilter.isNotEmpty) {
      final normalizedFilter = typeFilter.toLowerCase();
      filteredTypes = filteredTypes
          .where((t) => t.name.trim().toLowerCase() == normalizedFilter)
          .toList();
    }

    debugPrint('🔧 _loadInitialData: filteredTypes=${filteredTypes.length}');

    if (!mounted) return;

    setState(() {
      _typesList = filteredTypes;

      AccountType? resolvedType;
      if (widget.accountToEdit != null) {
        try {
          resolvedType = filteredTypes
              .firstWhere((t) => t.id == widget.accountToEdit!.typeId);
          debugPrint('🔧 _loadInitialData: resolvedType encontrado: ${resolvedType.name} (id=${resolvedType.id})');
        } catch (_) {
          debugPrint('⚠️ _loadInitialData: typeId ${widget.accountToEdit!.typeId} não encontrado em filteredTypes!');
          resolvedType = filteredTypes.isNotEmpty ? filteredTypes.first : null;
        }
      } else if (filteredTypes.isNotEmpty) {
        resolvedType = filteredTypes.first;
      }

      if (typeFilter != null && typeFilter.isNotEmpty) {
        resolvedType = filteredTypes.isNotEmpty ? filteredTypes.first : null;
      }

      _selectedType = resolvedType;
      debugPrint('🔧 _loadInitialData: _selectedType=${_selectedType?.name}');
    });
    await _loadCategories();
  }

  Future<void> _onTypeChanged(AccountType? val) async {
    setState(() {
      _selectedType = val;
      _categorias = [];
      _selectedCategory = null;
      // Não limpar a descrição ao mudar o tipo
    });
    await _loadCategories();
  }

  Future<void> _setInitialDate() async {
    // Corrigido: Data inicial é HOJE (formato dd/mm/yy)
    final date = DateTime.now();
    _dateController.text = DateFormat('dd/MM/yyyy').format(date);
  }

  // --- LÓGICA DE CÁLCULO DE DATAS ---
  ({DateTime originalDate, DateTime adjustedDate, String? warning, bool changed}) _calculateAdjustment(
      String dateStr) {
    if (dateStr.length < 8) {
      final now = DateTime.now();
      return (originalDate: now, adjustedDate: now, warning: null, changed: false);
    }
    try {
      // Converter dd/mm/yy para DateTime
      List<String> parts = dateStr.split('/');
      if (parts.length != 3) {
        final now = DateTime.now();
        return (originalDate: now, adjustedDate: now, warning: null, changed: false);
      }

      int day = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      int year = int.parse(parts[2]);
      if (year < 100) {
        year = 2000 + year;
      }

      DateTime original = DateTime(year, month, day);
      var check = HolidayService.adjustDateToBusinessDay(
          original, PrefsService.cityNotifier.value);
      bool changed = !DateUtils.isSameDay(original, check.date);
      return (
        originalDate: original,
        adjustedDate: check.date,
        warning: check.warning,
        changed: changed
      );
    } catch (e) {
      final now = DateTime.now();
      return (originalDate: now, adjustedDate: now, warning: null, changed: false);
    }
  }

  Future<void> _selectDate(TextEditingController controller) async {
    DateTime initialDate = _getInitialDateFromController(controller);

    if (!mounted) return;

    try {
      final picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        locale: const Locale('pt', 'BR'),
      );

      if (!mounted) return;

      if (picked != null) {
        String formatted = DateFormat('dd/MM/yyyy').format(picked);
        controller.text = formatted;
        if (controller == _dateController) {
          _onMainDateChanged(formatted);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erro ao selecionar data: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  DateTime _getInitialDateFromController(TextEditingController controller) {
    try {
      final text = controller.text.trim();
      if (text.isEmpty || text.length < 8) {
        return DateTime.now();
      }

      // Converter dd/mm/yy ou dd/mm/yyyy para DateTime
      final parts = text.split('/');
      if (parts.length != 3) {
        return DateTime.now();
      }

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      var year = int.parse(parts[2]);
      if (year < 100) year = 2000 + year;

      var initialDate = DateTime(year, month, day);
      if (initialDate.isBefore(DateTime(2020)) || initialDate.isAfter(DateTime(2030))) {
        initialDate = DateTime.now();
      }
      return initialDate;
    } catch (_) {
      return DateTime.now();
    }
  }

  Future<void> _selectInstallmentDate(int index) async {
    if (index < 0 || index >= _installments.length) return;

    final controller = _installments[index].dateController;
    final initialDate = _getInitialDateFromController(controller);

    if (!mounted) return;

    try {
      final picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        locale: const Locale('pt', 'BR'),
      );

      if (!mounted) return;

      if (picked != null) {
        final formatted = DateFormat('dd/MM/yyyy').format(picked);
        controller.text = formatted;
        controller.selection = TextSelection.fromPosition(TextPosition(offset: formatted.length));
        _onTableDateChanged(index, formatted);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao selecionar data: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _onMainDateChanged(String val) {
    if (val.length < 8) return;
    final result = _calculateAdjustment(val);
    setState(() {
      _mainOriginalDueDate = result.originalDate;
      _mainAdjustedDueDate = result.adjustedDate;
      _mainDueDateWasAdjusted = result.changed;
    });
    _updateInstallments();
  }

  void _updateInstallments() {
    // Aceita datas com 8 caracteres (dd/mm/yy)
    if (_dateController.text.length < 8 ||
        _totalValueController.text.isEmpty ||
        _installmentsQtyController.text.isEmpty ||
        _installmentsQtyController.text == "-1" ||
        _installmentsQtyController.text == "recorrente") {
      setState(() => _installments = []);
      return;
    }

    DateTime startSettingsDate;
    try {
      // Converter dd/mm/yy para DateTime
      List<String> parts = _dateController.text.split('/');
      if (parts.length != 3) {
        setState(() => _installments = []);
        return;
      }

      int day = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      int year = int.parse(parts[2]);
      if (year < 100) year = 2000 + year;
      startSettingsDate = DateTime(year, month, day);
    } catch (e) {
      return;
    }

    int qty = int.tryParse(_installmentsQtyController.text) ?? 1;
    if (qty < 1) qty = 1;

    final totalText = _totalValueController.text.trim();
    double totalValue = totalText.isNotEmpty
        ? UtilBrasilFields.converterMoedaParaDouble(totalText)
        : 0.0;
    double baseValue = totalValue / qty;

    List<InstallmentDraft> newList = [];
    String city = PrefsService.cityNotifier.value;

    // A data de vencimento da primeira parcela é a MESMA do dia base informado.
    DateTime firstDueDate = DateTime(
        startSettingsDate.year, startSettingsDate.month, startSettingsDate.day);

    for (int i = 0; i < qty; i++) {
      // Data de Vencimento (Mês + i)
      DateTime originalDate =
          DateTime(firstDueDate.year, firstDueDate.month + i, firstDueDate.day);

      // Ajuste de feriado/fim de semana
      var check = HolidayService.adjustDateToBusinessDay(originalDate, city);

      newList.add(InstallmentDraft(
          index: i + 1,
          originalDate: originalDate,
          adjustedDate: check.date,
          warning: check.warning,
          value: baseValue));
    }
    setState(() {
      _installments = newList;
    });
  }

  void _onTableDateChanged(int index, String val) {
    if (val.length < 8) return;
    final result = _calculateAdjustment(val);
    if (result.changed) {
      String newText = DateFormat('dd/MM/yyyyyy').format(result.adjustedDate);
      if (_installments[index].dateController.text != newText) {
        _installments[index].dateController.text = newText;
        _installments[index].dateController.selection =
            TextSelection.fromPosition(TextPosition(offset: newText.length));
      }
    }
    setState(() {
      _installments[index].originalDate = result.originalDate;
      _installments[index].adjustedDate = result.adjustedDate;
      _installments[index].warning = result.warning;
    });
  }

  Future<void> _showCalculator(TextEditingController controller, {VoidCallback? onChanged}) async {
    double currentValue = 0;
    if (controller.text.isNotEmpty) {
      try {
        currentValue = UtilBrasilFields.converterMoedaParaDouble(controller.text);
      } catch (_) {}
    }
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => CalculatorDialog(initialValue: currentValue),
    );
    if (result != null && mounted) {
      controller.text = UtilBrasilFields.obterReal(result);
      onChanged?.call();
    }
  }

  // --- HELPER PARA CAMPO COM ÍCONE E LABEL ACIMA ---
  Widget _buildFieldWithIcon({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return child;
  }

  InputDecoration buildOutlinedInputDecoration({
    required String label,
    required IconData icon,
    Widget? prefixIcon,
    String? hintText,
    String? prefixText,
    TextStyle? prefixStyle,
    Widget? suffixIcon,
    bool dense = true,
    EdgeInsetsGeometry? contentPadding,
    bool alignLabelWithHint = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
    );

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
      hintText: hintText,
      prefixIcon: prefixIcon ?? Icon(icon, color: colorScheme.onSurfaceVariant),
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      prefixText: prefixText,
      prefixStyle: prefixStyle,
      suffixIcon: suffixIcon,
      isDense: dense,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: colorScheme.surfaceContainerLow,
          contentPadding: contentPadding ??
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: baseBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    );
  }

  Widget _buildTypeDropdown() {
    debugPrint('📦 _buildTypeDropdown (types: ${_typesList.length}, selected: ${_selectedType?.name})');
    if (_typesList.isEmpty) {
      return InkWell(
        onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AccountTypesScreen()))
            .then((_) => _loadInitialData()),
        child: Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.warningBackground,
          child: Row(
            children: [
              const Icon(Icons.warning, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(_missingTypesMessage),
            ],
          ),
        ),
      );
    }
    if (widget.isRecebimento) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFieldWithIcon(
            icon: Icons.account_balance_wallet,
            label: _typeLabel,
            child: DropdownButtonFormField<AccountCategory>(
              value: _getValidatedSelectedParentCategory(),
              decoration: buildOutlinedInputDecoration(
                label: _typeLabel,
                icon: Icons.account_balance_wallet,
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    _selectedParentCategoria?.logo ?? '📁',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              items: _parentCategorias
                  .map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              cat.logo ?? '📁',
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 8),
                            Text(cat.categoria),
                          ],
                        ),
                      ))
                  .toList(),
              selectedItemBuilder: (BuildContext context) {
                return _parentCategorias
                    .map((cat) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(cat.categoria),
                        ))
                    .toList();
              },
              onChanged: (val) {
                debugPrint('🔄 Categoria pai alterada: ${val?.categoria}');
                setState(() {
                  _selectedParentCategoria = val;
                  _selectedCategory = null;
                  _categorias = [];
                });
                _loadCategories().then((_) {
                  debugPrint('✅ Categorias filhas carregadas: ${_categorias.length}');
                  debugPrint('   Lista: ${_categorias.map((c) => c.categoria).join(", ")}');
                });
              },
              validator: (val) => val == null ? _typeSelectErrorMessage : null,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFieldWithIcon(
          icon: Icons.account_balance_wallet,
          label: _typeLabel,
          child: DropdownButtonFormField<AccountType>(
            value: _getValidatedSelectedType(),
            decoration: buildOutlinedInputDecoration(
              label: _typeLabel,
              icon: Icons.account_balance_wallet,
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  _selectedType?.logo ?? '📁',
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            items: _typesList
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t.logo ?? '📁',
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 8),
                          Text(t.name),
                        ],
                      ),
                    ))
                .toList(),
            selectedItemBuilder: (BuildContext context) {
              return _typesList
                  .map((t) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(t.name),
                      ))
                  .toList();
            },
            onChanged: widget.lockTypeSelection ? null : (val) => _onTypeChanged(val),
            validator: (val) => val == null ? _typeSelectErrorMessage : null,
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    if (_categorias.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldWithIcon(
            icon: Icons.label,
            label: 'Categoria',
            child: DropdownButtonFormField<AccountCategory>(
              value: _getValidatedSelectedCategory(),
              decoration: buildOutlinedInputDecoration(
                label: 'Categoria',
                icon: Icons.label,
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    _selectedCategory?.logo ?? '📁',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              validator: (val) => val == null ? 'Selecione uma categoria' : null,
              items: _categorias.map((cat) {
                final displayText = widget.isRecebimento
                    ? _childDisplayName(cat.categoria)
                    : cat.categoria;
                final logoToShow = cat.logo ?? '📁';
                return DropdownMenuItem(
                  value: cat,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(logoToShow, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(displayText),
                    ],
                  ),
                );
              }).toList(),
              selectedItemBuilder: (BuildContext context) {
                return _categorias
                    .map((cat) {
                      final displayText = widget.isRecebimento
                          ? _childDisplayName(cat.categoria)
                          : cat.categoria;
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(displayText),
                      );
                    })
                    .toList();
              },
              onChanged: (val) {
                debugPrint('🎯 Categoria filha selecionada: ${val?.categoria}');
                setState(() {
                  _selectedCategory = val;
                });
              },
            ),
          ),
        ],
      );
    }

    if (widget.isRecebimento && _selectedParentCategoria != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nenhuma categoria filha encontrada para "${_selectedParentCategoria!.categoria}". Cadastre categorias filhas primeiro.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDescriptionField() {
    return _buildFieldWithIcon(
      icon: Icons.description_outlined,
      label: _descriptionLabel,
      child: TextFormField(
        controller: _descController,
        textCapitalization: TextCapitalization.sentences,
        decoration: buildOutlinedInputDecoration(
          label: _descriptionLabel,
          icon: Icons.description_outlined,
        ),
        validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
      ),
    );
  }

  String _selectedColorLabel() {
    final index = _colors.indexWhere((c) => c.toARGB32() == _selectedColor);
    if (index == -1) return 'Cor personalizada';
    return 'Opção ${index + 1}';
  }

  Future<void> _showColorPicker() async {
    final colorScheme = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                                color: colorScheme.onSurface,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstallmentDropdown() {
    return TextFormField(
      controller: _installmentsQtyController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: buildOutlinedInputDecoration(
        label: 'Quantidade de Parcelas',
        icon: Icons.repeat,
        hintText: 'Ex: 1 (à vista) ou 12 (12 parcelas)',
      ),
      onChanged: (val) {
        _updateInstallments();
      },
      validator: (val) {
        if (val == null || val.isEmpty) {
          return 'Informe a quantidade de parcelas (1-99)';
        }
        final qty = int.tryParse(val);
        if (qty == null || qty < 1 || qty > 99) {
          return 'Quantidade deve estar entre 1 e 99';
        }
        return null;
      },
    );
  }

  // Widget com o conteúdo do formulário (scrollável)
  Widget _buildFormContent() {
    try {
      debugPrint('🏗️ _buildFormContent INÍCIO');
      final colorScheme = Theme.of(context).colorScheme;
      return _buildTransactionFormContent(colorScheme);
    } catch (e, stackTrace) {
      debugPrint('❌ CRASH em _buildFormContent: $e');
      debugPrint('Stack trace:\n$stackTrace');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Erro ao construir formulário:\n$e'),
          ],
        ),
      );
    }
  }

  Widget _buildTransactionFormContent(ColorScheme colorScheme) {
    final installmentsQty = int.tryParse(_installmentsQtyController.text) ?? 1;
    final showInstallmentsList =
        _entryMode == 0 && installmentsQty > 1 && _installments.isNotEmpty;

    final dateField = _buildFieldWithIcon(
      icon: Icons.calendar_month,
      label: _baseDateLabel,
      child: TextFormField(
        controller: _dateController,
        keyboardType: TextInputType.number,
        inputFormatters: [_dateMaskFormatter],
        decoration: buildOutlinedInputDecoration(
          label: _baseDateLabel,
          icon: Icons.calendar_month,
          hintText: "dd/mm/aa",
          suffixIcon: IconButton(
            icon: Icon(Icons.date_range, color: colorScheme.onSurfaceVariant),
            tooltip: 'Selecionar Data',
            onPressed: () => _selectDate(_dateController),
          ),
        ),
        onChanged: _onMainDateChanged,
        validator: (value) => value == null || value.length < 8
            ? 'Data incompleta (dd/mm/aa)'
            : null,
      ),
    );

    final bool isRecurrent = _entryMode == 1;
    final valueController = isRecurrent ? _recurrentValueController : _totalValueController;
    final valueField = _buildFieldWithIcon(
      icon: Icons.attach_money,
      label: 'Valor (R\$) - Opcional',
      child: TextFormField(
        controller: valueController,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          CentavosInputFormatter(moeda: true),
        ],
        decoration: buildOutlinedInputDecoration(
          label: 'Valor (R\$) - Opcional',
          icon: Icons.attach_money,
          suffixIcon: IconButton(
            icon: Icon(Icons.calculate, color: colorScheme.onSurfaceVariant),
            tooltip: 'Calculadora',
            onPressed: () => _showCalculator(valueController, onChanged: () {
              if (!isRecurrent) _updateInstallments();
            }),
          ),
        ),
        onChanged: (val) {
          if (!isRecurrent) {
            _updateInstallments();
          }
        },
        validator: (value) {
          // Valor é opcional - só valida se preenchido
          if (value == null || value.trim().isEmpty) {
            return null; // Aceita vazio
          }
          try {
            final parsed = UtilBrasilFields.converterMoedaParaDouble(value);
            if (parsed < 0) return 'Valor não pode ser negativo';
          } catch (_) {
            return 'Valor inválido';
          }
          return null;
        },
      ),
    );

    // Tipo do formulário baseado em se é recebimento ou conta a pagar
    final formTypeLabel = widget.isRecebimento ? 'Novo Recebimento' : 'Nova Conta a Pagar';
    final formTypeIcon = widget.isRecebimento ? Icons.arrow_downward : Icons.arrow_upward;
    final formTypeColor = widget.isRecebimento ? Colors.green : Colors.red;

    return Form(
      key: _formKey,
      child: LancamentoFormPadrao(
        useScroll: true,
        typeContent: TextFormField(
          initialValue: widget.accountToEdit != null
              ? (widget.isRecebimento ? 'Editar Recebimento' : 'Editar Conta')
              : formTypeLabel,
          readOnly: true,
          decoration: buildOutlinedInputDecoration(
            label: 'Tipo de lançamento',
            icon: formTypeIcon,
            prefixIcon: Icon(formTypeIcon, color: formTypeColor),
          ),
        ),
        categoryTrailing: TextButton(
          onPressed: _showCategoriesDialog,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Gerenciar categorias'),
        ),
        extraClassificationContent: _buildTypeDropdown(),
        categoryContent: _buildCategorySection(),
        launchContent: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_entryMode == 0) _buildInstallmentDropdown(),
            if (_entryMode == 1) ...[
              // Opção de ajuste para feriados/fins de semana
              const Text("Em caso de feriado/fim de semana:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: false,
                      label: Text('Pagar Depois'),
                      icon: Icon(Icons.arrow_forward)),
                  ButtonSegment(
                      value: true,
                      label: Text('Antecipar'),
                      icon: Icon(Icons.arrow_back))
                ],
                selected: {_payInAdvance},
                onSelectionChanged: (Set<bool> sel) =>
                    setState(() => _payInAdvance = sel.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  minimumSize: WidgetStateProperty.all(const Size(0, 40)),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  side: WidgetStateProperty.all(
                    BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
                  ),
                ),
              ),
            ],
          ],
        ),
        descriptionValueContent: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 780;
                final itemWidth = isWide
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(width: itemWidth, child: _buildDescriptionField()),
                    SizedBox(width: itemWidth, child: valueField),
                  ],
                );
              },
            ),
          ],
        ),
        datesContent: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Switch para ativar recorrência (antes do campo de data)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  Icon(Icons.repeat, color: colorScheme.onSurfaceVariant, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Conta recorrente',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Switch(
                    value: _entryMode == 1,
                    onChanged: (value) {
                      setState(() {
                        _entryMode = value ? 1 : 0;
                        if (value) {
                          // Ao ativar recorrência, extrair dia da data atual
                          if (_dateController.text.isNotEmpty) {
                            try {
                              final date = DateFormat('dd/MM/yy').parse(_dateController.text);
                              _recurrentDay = date.day;
                            } catch (_) {}
                          }
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_entryMode == 0) ...[
              dateField,
              if (_mainOriginalDueDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data original: ${DateFormat('dd/MM/yyyy').format(_mainOriginalDueDate!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_mainDueDateWasAdjusted && _mainAdjustedDueDate != null)
                        Text(
                          'Data ajustada: ${DateFormat('dd/MM/yyyy').format(_mainAdjustedDueDate!)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
            ] else ...[
              // Campos de recorrência: Dia Venc., Mês Inicial, Ano Inicial
              Row(children: [
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<int>(
                    value: _recurrentDay,
                    decoration: buildOutlinedInputDecoration(
                      label: 'Dia Venc.',
                      icon: Icons.calendar_today,
                    ),
                    items: List.generate(
                        31,
                        (index) => DropdownMenuItem(
                            value: index + 1, child: Text("${index + 1}"))),
                    onChanged: (val) => setState(() => _recurrentDay = val!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<int>(
                    value: _recurrentStartMonth,
                    decoration: buildOutlinedInputDecoration(
                      label: 'Mês Inicial',
                      icon: Icons.calendar_month,
                    ),
                    items: List.generate(12, (index) {
                      return DropdownMenuItem(
                        value: index,
                        child: Text(_monthShortLabels[index]),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _recurrentStartMonth = val);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _recurrentStartYearController,
                    keyboardType: TextInputType.number,
                    decoration: buildOutlinedInputDecoration(
                      label: 'Ano Inicial',
                      icon: Icons.event,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    validator: (value) {
                      if (_entryMode != 1) return null;
                      if (value == null || value.isEmpty) {
                        return 'Obrigatório';
                      }
                      final year = int.tryParse(value);
                      if (year == null || year < 2000 || year > 2100) {
                        return 'Ano inválido';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null) {
                        _recurrentStartYear = parsed;
                      }
                    },
                  ),
                ),
              ]),
            ],
          ],
        ),
        optionsContent: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColorPickerField(
              label: 'Cor do lançamento',
              color: Color(_selectedColor),
              subtitle: _selectedColorLabel(),
              onPick: _showColorPicker,
            ),
            const SizedBox(height: 12),
            _buildFieldWithIcon(
              icon: Icons.note,
              label: 'Observações (opcional)',
              child: TextFormField(
                controller: _observationController,
                decoration: buildOutlinedInputDecoration(
                  label: 'Observações (opcional)',
                  icon: Icons.note,
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
            ),
          ],
        ),
        parcelasContent: showInstallmentsList ? _buildInstallmentsList(colorScheme) : null,
      ),
    );
  }

  Widget _buildInstallmentsList(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Parcelas',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: _installments.map((item) {
            final index = item.index - 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    children: [
                      Container(
                        height: 2,
                        color: colorScheme.primary.withValues(alpha: 0.6),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                                ),
                              ),
                              child: Text(
                                '#${item.index}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: item.dateController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                decoration: buildOutlinedInputDecoration(
                                  label: 'Venc: dd/mm/aaaa',
                                  icon: Icons.calendar_today,
                                  dense: true,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      Icons.calendar_month,
                                      size: 18,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    onPressed: () => _selectInstallmentDate(index),
                                    tooltip: 'Selecionar data',
                                  ),
                                ),
                                inputFormatters: [_dateMaskFormatter],
                                onChanged: (val) => _onTableDateChanged(index, val),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: item.valueController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.end,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                decoration: buildOutlinedInputDecoration(
                                  label: 'Valor',
                                  icon: Icons.attach_money,
                                  dense: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  CentavosInputFormatter(moeda: true),
                                ],
                                onChanged: (val) {
                                  final trimmed = val.trim();
                                  item.value = trimmed.isNotEmpty
                                      ? UtilBrasilFields.converterMoedaParaDouble(trimmed)
                                      : 0.0;
                                  setState(() {});
                                },
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
          }).toList(),
        ),
      ],
    );
  }

  // Widget com os botões de ação
  Widget _buildActionButtons() {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: _isSaving ? null : _closeScreen,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Cancelar'),
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                  backgroundColor: colorScheme.primary,
                  disabledBackgroundColor: colorScheme.primary.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isSaving ? null : _saveAccount,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _saveButtonLabel(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    try {
      debugPrint('🏗️ AccountFormScreen.build INÍCIO');
      
      // Se está carregando dados iniciais, mostrar loading indicator
      if (_isLoadingData) {
        debugPrint('🏗️ AccountFormScreen.build: Mostrando loading indicator (_isLoadingData=true)');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Carregando formulário...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        );
      }

      debugPrint('🏗️ AccountFormScreen.build: Dados carregados, construindo UI');
      debugPrint('  - widget.accountToEdit: ${widget.accountToEdit?.description}');
      debugPrint('  - widget.isRecebimento: ${widget.isRecebimento}');
      debugPrint('  - _selectedType: ${_selectedType?.name}');
      debugPrint('  - _selectedCategory: ${_selectedCategory?.categoria}');
      
      final appBarTitle = widget.accountToEdit != null 
          ? (widget.isRecebimento ? 'Editar Recebimento' : 'Editar Conta')
          : (widget.isRecebimento ? 'Novo Recebimento' : 'Nova Conta');

      debugPrint('🏗️ AccountFormScreen.build: appBarTitle="$appBarTitle"');

      // Se não mostrar AppBar (usado em Dialog), retorna Column simples
      if (!widget.showAppBar) {
        debugPrint('🏗️ AccountFormScreen.build: Modo Dialog (showAppBar=false)');
        return Column(
          children: [
            Expanded(child: _buildFormContent()),
            _buildActionButtons(),
          ],
        );
      }

      // Se mostrar AppBar (página completa), usa Scaffold com SafeArea
      debugPrint('🏗️ AccountFormScreen.build: Modo Scaffold (showAppBar=true)');
      debugPrint('🏗️ AccountFormScreen.build FIM - retornando Scaffold');
      return Scaffold(
        appBar: AppBar(
          title: Text(appBarTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _closeScreen,
          ),
        ),
        body: SafeArea(
          child: _buildFormContent(),
        ),
        bottomNavigationBar: _buildActionButtons(),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ CRASH em AccountFormScreen.build: $e');
      debugPrint('Stack trace:\n$stackTrace');
      return Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Erro ao carregar formulário:\n$e'),
            ],
          ),
        ),
      );
    }
  }

  Future<int?> _showInstallmentScopeDialog(Account acc) async {
    final total = acc.installmentTotal ?? 0;
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aplicar alteração em parcelas?'),
        content: Text(
          'A conta "${acc.description}" tem $total parcelas. Deseja aplicar a edição apenas nesta, nesta e nas futuras ou em todas as parcelas?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 0),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 1),
            child: const Text('Somente essa'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 2),
            child: const Text('Essa e as futuras'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(ctx, 3),
            child: const Text('Todas as parcelas'),
          ),
        ],
      ),
    );
  }

  bool _shouldUpdateInstallment(Account installment, Account base, int scope) {
    if (scope == 3) return true;
    if (scope == 2) {
      if (base.installmentIndex != null && installment.installmentIndex != null) {
        return installment.installmentIndex! >= base.installmentIndex!;
      }
      final baseDate = _installmentDate(base);
      final instDate = _installmentDate(installment);
      return !instDate.isBefore(baseDate);
    }
    return installment.id == base.id;
  }

  DateTime _installmentDate(Account account) {
    final year = account.year ?? DateTime.now().year;
    final month = account.month ?? DateTime.now().month;
    final day = _validateAndAdjustDay(account.dueDay, month, year);
    return DateTime(year, month, day);
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    if (widget.lockTypeSelection ||
        (widget.typeNameFilter != null &&
            widget.typeNameFilter!.trim().isNotEmpty)) {
      return;
    }

    // NÃO sobrescrever o tipo se está editando uma conta existente
    if (widget.accountToEdit != null) {
      debugPrint('🔧 _loadPreferences: Pulando (está editando conta existente)');
      return;
    }

    // Carregar tipo preferido (usando _typesList já carregado em _loadInitialData)
    final typeId = prefs.getInt('last_account_type_id');
    if (typeId != null && _typesList.isNotEmpty) {
      final foundType = _typesList.firstWhere((t) => t.id == typeId,
          orElse: () => _typesList.first);
      debugPrint('🔧 _loadPreferences: Carregando preferência - typeId=$typeId, tipo=${foundType.name}');
      _selectedType = foundType;
      await _loadCategories();
    }

    setState(() {});
  }

  // --- LÓGICAS DE SALVAMENTO ---
  Future<void> _saveAccount() async {
    if (_isSaving) return;
    if (_entryMode == 0 && _installments.isEmpty) _updateInstallments();

    // Validação inicial para campos no modo Recorrente Fixa
    if (!_formKey.currentState!.validate() || _selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Preencha todos os campos obrigatórios."),
          backgroundColor: AppColors.error));
      return;
    }

    setState(() => _isSaving = true);

    // Salvar preferências
    final prefs = await SharedPreferences.getInstance();
    if (!widget.lockTypeSelection &&
        (widget.typeNameFilter == null ||
            widget.typeNameFilter!.trim().isEmpty) &&
        _selectedType != null) {
      await prefs.setInt('last_account_type_id', _selectedType!.id!);
    }

    try {
      // MODO EDIÇÃO - Se accountToEdit não é null, fazer UPDATE
      if (widget.accountToEdit != null) {
        final acc = widget.accountToEdit!;

        if (_entryMode == 1) {
          // Editar recorrente
          final avgText = _recurrentValueController.text.trim();
          final launchedText = _recurrentLaunchedValueController.text.trim();
          double averageVal = avgText.isNotEmpty
              ? UtilBrasilFields.converterMoedaParaDouble(avgText)
              : 0.0;
          double launchedVal = launchedText.isNotEmpty
              ? UtilBrasilFields.converterMoedaParaDouble(launchedText)
              : 0.0;

          debugPrint('🔍 EDIÇÃO RECORRÊNCIA:');
          debugPrint('  Valor Médio (controller): "${_recurrentValueController.text}" = $averageVal');
          debugPrint('  Valor Lançado (controller): "${_recurrentLaunchedValueController.text}" = $launchedVal');

          // Usar o Valor Lançado se foi preenchido, senão usar o Valor Médio
          double updateVal = launchedVal > 0.01 ? launchedVal : averageVal;
          debugPrint('  → Valor final para salvar: $updateVal (lançado=$launchedVal, médio=$averageVal)');

          // Valor anterior (usar _editingAccount que pode ser pai, não acc que pode ser filha)
          double previousValue = _editingAccount?.value ?? acc.value;
          debugPrint('  Valor anterior: $previousValue');

          // Verificar se houve mudança significativa de valor
          int? option;
          if ((updateVal - previousValue).abs() > 0.01) {
            // HOUVE MUDANÇA - perguntar
            debugPrint('  ⚠️  VALOR ALTERADO de $previousValue para $updateVal');

            if (!mounted) return;
            final changeOption = await showDialog<int>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Confirmar Mudança de Valor'),
                content: RichText(
                  text: TextSpan(
                    text: 'O valor de ',
                    children: [
                      TextSpan(
                        text: UtilBrasilFields.obterReal(previousValue),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      const TextSpan(text: ' foi alterado para '),
                      TextSpan(
                        text: UtilBrasilFields.obterReal(updateVal),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                        const TextSpan(text: '.\n\nEssa alteração será somente para essa conta ou para essa e para todas as futuras?'),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, 0),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, 1),
                      child: const Text('Somente essa'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, 2),
                      child: const Text('Essa e as futuras'),
                    ),
                  ],
                ),
              );

              if (!mounted) return;
              option = changeOption;
            } else {
              // SEM MUDANÇA - atualizar normalmente (apenas a conta)
              debugPrint('  ✓ Sem mudança significativa de valor');
              option = 1; // Apenas esta conta
            }

            if (option == null || option == 0) {
              setState(() => _isSaving = false);
              return;
            }

          // Usar _editingAccount se for disponível (pode ser a recorrência pai), senão usar acc (original)
          final accountToUpdate = _editingAccount ?? acc;

          // Criar Account atualizada
          final updated = accountToUpdate.copyWith(
            typeId: _selectedType!.id!,
            categoryId: _selectedCategory?.id ?? accountToUpdate.categoryId,
            description: _descController.text,
            value: 0,  // ✅ PAI RECORRENTE SEMPRE COM VALUE = 0 (é apenas um template!)
            estimatedValue: averageVal,
            dueDay: _recurrentDay,
            isRecurrent: true,
            payInAdvance: _payInAdvance,
            month: null,
            year: null,
            recurrenceId: null,
            observation: _observationController.text,
            cardColor: _selectedColor,
          );

          // Verificar mudança de dia base e perguntar escopo
          final previousDay = accountToUpdate.dueDay;
          final dayChanged = _recurrentDay != previousDay;
          int dayOption = 1;
          if (dayChanged) {
            if (!mounted) return;
            final changeDayOption = await showDialog<int>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Confirmar Mudança de Dia Base'),
                content: RichText(
                  text: TextSpan(
                    text: 'O dia base de ',
                    children: [
                      TextSpan(
                        text: previousDay.toString().padLeft(2, '0'),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      const TextSpan(text: ' foi alterado para '),
                      TextSpan(
                        text: _recurrentDay.toString().padLeft(2, '0'),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      const TextSpan(text: '.\n\nAplicar somente nessa, nas futuras, ou em todas as parcelas?'),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, 0), child: const Text('Cancelar')),
                  TextButton(onPressed: () => Navigator.pop(ctx, 1), child: const Text('Somente essa')),
                  TextButton(onPressed: () => Navigator.pop(ctx, 2), child: const Text('Essa e as futuras')),
                  FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.success), onPressed: () => Navigator.pop(ctx, 3), child: const Text('Todas as parcelas')),
                ],
              ),
            );
            if (!mounted) return;
            if (changeDayOption == 0) {
              setState(() => _isSaving = false);
              return;
            }
            dayOption = (changeDayOption ?? 1);
          }

          if (option == 1 && dayOption == 1) {
            // Apenas esta conta (comportamento atual)
            debugPrint('  Account.value antes de atualizar: ${updated.value}');
            await DatabaseHelper.instance.updateAccount(updated);
            debugPrint('  Account atualizada com id: ${updated.id}');
          } else {
            // Esta e daqui pra frente - APENAS ATUALIZA, NÃO CRIA

            // 1. Atualizar o pai (definição da recorrência)
            debugPrint('  Account.value antes de atualizar: ${updated.value}');
            await DatabaseHelper.instance.updateAccount(updated);
            debugPrint('  Account atualizada com id: ${updated.id}');

            // 2. Buscar e atualizar parcelas futuras
            final currentMonth = DateTime.now().month;
            final currentYear = DateTime.now().year;

            // Determinar o ID da recorrência (pai)
            final recurrenceId = accountToUpdate.isRecurrent
                ? accountToUpdate.id
                : accountToUpdate.recurrenceId;

            if (recurrenceId == null) {
              debugPrint('  ⚠️ Recorrência sem ID pai. Nenhuma parcela futura a atualizar.');
            } else {
              // Buscar apenas as filhas desta recorrência (não TODAS as contas)
              final children = await DatabaseHelper.instance.getAccountsByRecurrenceId(recurrenceId);
              List<Account> accountsToUpdate;
              if (dayOption == 3) {
                accountsToUpdate = children.where((a) => a.month != null && a.year != null).toList();
              } else {
                accountsToUpdate = children.where((a) {
                  final accDate = DateTime(a.year ?? 0, a.month ?? 0, 1);
                  final today = DateTime(currentYear, currentMonth, 1);
                  return accDate.isAtSameMomentAs(today) || accDate.isAfter(today);
                }).where((a) => a.month != null && a.year != null).toList();
              }

              debugPrint('  🔄 Atualizando ${accountsToUpdate.length} parcelas (escopo=${dayOption == 3 ? 'todas' : 'futuras'}) (recurrence_id=$recurrenceId)');

              final duplicatesToRemove = <Account>[];
              final groupedByPeriod = <String, List<Account>>{};
              for (final future in accountsToUpdate) {
                if (future.month == null || future.year == null) continue;
                final key = '${future.year}-${future.month}-${future.dueDay}';
                groupedByPeriod.putIfAbsent(key, () => []).add(future);
              }

              groupedByPeriod.forEach((key, list) {
                if (list.length > 1) {
                  list.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
                  duplicatesToRemove.addAll(list.skip(1));
                }
              });

              if (duplicatesToRemove.isNotEmpty) {
                debugPrint(
                    '  ⚠️ Removendo ${duplicatesToRemove.length} parcelas duplicadas futuras');
                for (final dup in duplicatesToRemove) {
                  if (dup.id != null) {
                    await DatabaseHelper.instance.deleteAccount(dup.id!);
                  }
                }
                final duplicateIds = duplicatesToRemove
                    .map((d) => d.id)
                    .whereType<int>()
                    .toSet();
                accountsToUpdate = accountsToUpdate
                  .where((a) => !duplicateIds.contains(a.id))
                  .toList();
              }

              for (final future in accountsToUpdate) {
                final updatedFuture = future.copyWith(
                  typeId: _selectedType!.id!,
                  categoryId: _selectedCategory?.id ?? future.categoryId,
                  description: _descController.text,
                  value: launchedVal > 0.01 ? launchedVal : 0,
                  estimatedValue: averageVal,
                  observation: _observationController.text,
                  cardColor: _selectedColor,
                );
                if (dayChanged) {
                  final raw = DateTime(future.year!, future.month!, _recurrentDay);
                  final city = PrefsService.cityNotifier.value;
                  final adj = HolidayService.adjustDateToBusinessDay(raw, city);
                  final adjDate = adj.date;
                  final applied = updatedFuture.copyWith(dueDay: adjDate.day, month: adjDate.month, year: adjDate.year);
                  await DatabaseHelper.instance.updateAccount(applied);
                } else {
                  await DatabaseHelper.instance.updateAccount(updatedFuture);
                }
                debugPrint(
                    '  ✓ Atualizada: ${future.description} (${future.month}/${future.year})');
              }

              debugPrint('  ✅ ${accountsToUpdate.length} parcelas atualizadas');
            }
          }
        } else {
          // Editar avulsa/parcelada - Extract date from form
            DateTime editDate = DateTime.now();
            try {
              // Normalizar data para completar com ano corrente se necessário
              final normalizedDate = DateFormatter.normalizeDate(_dateController.text);
              editDate = UtilData.obterDateTime(normalizedDate);
            } catch (e) {
              final year = acc.year ?? DateTime.now().year;
              final month = acc.month ?? DateTime.now().month;
              final day = _validateAndAdjustDay(acc.dueDay, month, year);
              editDate = DateTime(year, month, day);
            }

            final newValueText = _totalValueController.text.trim();
            final newValue = newValueText.isNotEmpty
                ? UtilBrasilFields.converterMoedaParaDouble(newValueText)
                : 0.0;

            final updated = acc.copyWith(
              typeId: _selectedType!.id!,
              categoryId: _selectedCategory?.id ?? acc.categoryId,
              description: _descController.text,
              value: newValue,
              dueDay: editDate.day,
              month: editDate.month,
              year: editDate.year,
              isRecurrent: false,
              payInAdvance: _payInAdvance,
              observation: _observationController.text,
              cardColor: _selectedColor,
            );

            final isInstallmentSeries = acc.installmentTotal != null &&
                acc.installmentTotal! > 1 &&
                acc.recurrenceId == null;
            int installmentScope = 1;
            if (isInstallmentSeries) {
              final userChoice = await _showInstallmentScopeDialog(acc);
              if (userChoice == null || userChoice == 0) {
                setState(() => _isSaving = false);
                return;
              }
              installmentScope = userChoice;
            }

            if (installmentScope == 1) {
              await DatabaseHelper.instance.updateAccount(updated);
            } else {
              final allInstallments = await DatabaseHelper.instance
                  .getAccountsByInstallmentTotal(
                      acc.installmentTotal!, acc.description);
              for (final installment in allInstallments) {
                if (!_shouldUpdateInstallment(
                    installment, acc, installmentScope)) {
                  continue;
                }
                final isCurrent = installment.id == acc.id;
                if (!isCurrent) {
                  final targetDay = editDate.day;
                  final baseYear = installment.year ?? DateTime.now().year;
                  final baseMonth = installment.month ?? DateTime.now().month;
                  final raw = DateTime(baseYear, baseMonth, targetDay);
                  final city = PrefsService.cityNotifier.value;
                  final adj = HolidayService.adjustDateToBusinessDay(raw, city);
                  final adjDate = adj.date;
                  final updatedInstallment = installment.copyWith(
                    typeId: _selectedType!.id!,
                    categoryId: _selectedCategory?.id ?? installment.categoryId,
                    description: _descController.text,
                    value: newValue,
                    payInAdvance: _payInAdvance,
                    observation: _observationController.text,
                    cardColor: _selectedColor,
                    dueDay: adjDate.day,
                    month: adjDate.month,
                    year: adjDate.year,
                  );
                  if (updatedInstallment.id != null) {
                    await DatabaseHelper.instance.updateAccount(updatedInstallment);
                  }
                } else {
                  final updatedInstallment = installment.copyWith(
                    typeId: _selectedType!.id!,
                    categoryId:
                        _selectedCategory?.id ?? installment.categoryId,
                    description: _descController.text,
                    value: newValue,
                    payInAdvance: _payInAdvance,
                    observation: _observationController.text,
                    cardColor: _selectedColor,
                    dueDay: editDate.day,
                    month: editDate.month,
                    year: editDate.year,
                  );
                  if (updatedInstallment.id != null) {
                    await DatabaseHelper.instance
                        .updateAccount(updatedInstallment);
                  }
                }
              }
            }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Conta atualizada com sucesso!"),
              backgroundColor: AppColors.success));
          _closeScreen();
        }
        return;
      }

      // MODO CRIAÇÃO - Criar novo
      if (_entryMode == 1) {
        // Modo Recorrente Fixa - valor é opcional

        final parsedStartYear =
            int.tryParse(_recurrentStartYearController.text.trim());
        if (parsedStartYear != null) {
          _recurrentStartYear = parsedStartYear;
        }

        final startYear = _recurrentStartYear;
        final startMonthIndex = _recurrentStartMonth; // 0-based
        if (startYear < 2000 || startYear > 2100) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Informe um ano de início válido (>= 2000)."),
                backgroundColor: AppColors.error));
          }
          setState(() => _isSaving = false);
          return;
        }
  final startMonth = startMonthIndex + 1; // converter para 1-12
  final earliestAllowed = DateTime(startYear, startMonth, 1);

  debugPrint('  → Configuração de início: mês=$startMonth ano=$startYear');

        final valText = _recurrentValueController.text.trim();
        final launchedText = _recurrentLaunchedValueController.text.trim();
        double val = valText.isNotEmpty
            ? UtilBrasilFields.converterMoedaParaDouble(valText)
            : 0.0;
        double launchedVal = launchedText.isNotEmpty
            ? UtilBrasilFields.converterMoedaParaDouble(launchedText)
            : 0.0;
        debugPrint('🔍 SALVAMENTO RECORRÊNCIA:');
        debugPrint('  Controller text: "$valText"');
        debugPrint('  Valor convertido: $val');
        debugPrint('  Valor Lançado: $launchedVal');
        final acc = Account(
            typeId: _selectedType!.id!,
            categoryId: _selectedCategory?.id,
            description: _descController.text,
            value: 0,  // ✅ PAI RECORRENTE SEMPRE COM VALUE = 0 (é apenas um template!)
            estimatedValue: val,
            dueDay: _recurrentDay,
            isRecurrent: true,
            payInAdvance: _payInAdvance,
            month: startMonth,
            year: startYear,
            observation: _observationController.text,
            cardColor: _selectedColor);
        debugPrint('  Account.value antes de salvar: ${acc.value}');
        debugPrint('  Account.typeId: ${acc.typeId} (tipo: ${_selectedType!.name})');

        // 1. Criar a conta recorrente pai - somente se estouro validado
        int? parentId = await DatabaseHelper.instance.createAccount(acc);
        debugPrint('  Account salva com id: $parentId');

        // 2. Gerar instâncias mensais futuras da recorrência
        // ignore: unnecessary_null_comparison
        if (parentId != null) {
          debugPrint('  Gerando instâncias mensais futuras da recorrência...');

          int createdCount = 0;

          int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

          for (int i = 0; i < 12; i++) {
            final totalMonths = (startMonth - 1) + i;
            final targetYear = startYear + (totalMonths ~/ 12);
            final targetMonth = (totalMonths % 12) + 1;

            if (targetYear < startYear ||
                (targetYear == startYear && targetMonth < startMonth)) {
              debugPrint(
                  '  ⚠️ Ignorando instância $targetMonth/$targetYear por estar antes do início configurado $startMonth/$startYear.');
              continue;
            }

            final referenceDate = DateTime(targetYear, targetMonth, 1);
            final maxDay = daysInMonth(targetYear, targetMonth);
            final dueDay = _recurrentDay.clamp(1, maxDay).toInt();
            final rawDueDate = DateTime(targetYear, targetMonth, dueDay);
            final city = PrefsService.cityNotifier.value;
            final adjustmentResult = HolidayService.adjustDateToBusinessDay(
              rawDueDate,
              city
            );
            final adjustedDate = adjustmentResult.date;
            final adjustedDay = adjustedDate.day;
            final adjustedMonth = adjustedDate.month;
            final adjustedYear = adjustedDate.year;

            if (adjustedDate.isBefore(earliestAllowed)) {
              debugPrint(
                  '  ⚠️ Ignorando instância retroativa $adjustedMonth/$adjustedYear (antes do início configurado $startMonth/$startYear).');
              continue;
            }

            final plannedMonth = referenceDate.month;
            final plannedYear = referenceDate.year;
            debugPrint(
                '  → Instância planejada: $plannedMonth/$plannedYear (ajustada para $adjustedDay/$adjustedMonth/$adjustedYear, cidade=$city)');

            // 🚀 AUTO-LANÇAMENTO: Se Valor Lançado > 0, todas as instâncias são criadas já lançadas
            final launchedText = _recurrentLaunchedValueController.text.trim();
            final launchedValue = launchedText.isNotEmpty
                ? UtilBrasilFields.converterMoedaParaDouble(launchedText)
                : 0.0;
            final shouldAutoLaunch = launchedValue > 0;
            
            final monthlyAccount = Account(
              typeId: _selectedType!.id!,
              categoryId: _selectedCategory?.id,
              description: _descController.text,
              value: shouldAutoLaunch ? launchedValue : 0,
              estimatedValue: val,
              dueDay: adjustedDate.day,
              month: adjustedDate.month,
              year: adjustedDate.year,
              isRecurrent: false,
              payInAdvance: _payInAdvance,
              recurrenceId: parentId,
              observation: _observationController.text,
              cardColor: _selectedColor,
            );
            
            if (shouldAutoLaunch) {
              debugPrint('  💰 Instância auto-lançada com valor R\$ ${launchedValue.toStringAsFixed(2)}');
            }

            await DatabaseHelper.instance.createAccount(monthlyAccount);
            debugPrint('  ✓ Instância criada: ${adjustedDate.month}/${adjustedDate.year}');
            createdCount++;
          }

          debugPrint('  ✅ $createdCount instâncias mensais criadas com sucesso');
        }
      } else {
        // Modo Avulsa / Parcelada
        if (_installments.isEmpty) _updateInstallments();

        // VALIDAÇÃO CRÍTICA: Se ainda estiver vazia, não salvar
        if (_installments.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    "Erro: Não foi possível gerar parcelas. Verifique se data e valor estão preenchidos."),
                backgroundColor: AppColors.error));
          }
          setState(() => _isSaving = false);
          return;
        }

        // Se for assinatura, criar como recorrente
        if (_installmentsQtyController.text == "-1") {
          final valText = _totalValueController.text.trim();
          double val = valText.isNotEmpty
              ? UtilBrasilFields.converterMoedaParaDouble(valText)
              : 0.0;
          try {
            // Normalizar data para completar com ano corrente se necessário
            final normalizedDate = DateFormatter.normalizeDate(_dateController.text);
            DateTime dt = UtilData.obterDateTime(normalizedDate);
            final acc = Account(
              typeId: _selectedType!.id!,
              categoryId: _selectedCategory?.id,
              description: _descController.text + " (Assinatura)",
              value: 0,  // ✅ PAI RECORRENTE SEMPRE COM VALUE = 0
              estimatedValue: val,
              dueDay: dt.day,
              month: dt.month,
              year: dt.year,
              isRecurrent: true,
              payInAdvance: _payInAdvance,
              observation: _observationController.text,
              cardColor: _selectedColor,
            );
            await DatabaseHelper.instance.createAccount(acc);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text("Erro na data: $e"),
                    backgroundColor: AppColors.error),
              );
            }
            setState(() => _isSaving = false);
            return;
          }
        } else {
          int totalItems = _installments.length;
          final baseDescription = cleanInstallmentDescription(_descController.text.trim());
          debugPrint('💾 Salvando $totalItems parcelas de "$baseDescription"');
          for (var item in _installments) {
            final acc = Account(
              typeId: _selectedType!.id!,
              categoryId: _selectedCategory?.id,
              description: baseDescription,
              value: item.value,
              dueDay: item.adjustedDate.day,
              month: item.adjustedDate.month,
              year: item.adjustedDate.year,
              isRecurrent: false,
              payInAdvance: _payInAdvance,
              observation: _observationController.text,
              cardColor: _selectedColor,
              installmentIndex: item.index,
              installmentTotal: totalItems,
            );
            debugPrint('   📝 Parcela ${item.index}/$totalItems: R\$ ${item.value} em ${item.adjustedDate.day}/${item.adjustedDate.month}/${item.adjustedDate.year}');
            await DatabaseHelper.instance.createAccount(acc);
          }
          debugPrint('✅ $totalItems parcelas salvas com sucesso');
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Contas lançadas com sucesso!"),
            backgroundColor: AppColors.success));
        _closeScreen();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Erro ao salvar: $e"), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _totalValueController.dispose();
    _installmentsQtyController.dispose();
    _recurrentValueController.dispose();
    _recurrentLaunchedValueController.dispose();
    _recurrentStartYearController.dispose();
    _dateController.dispose();
    _observationController.dispose();
    for (final draft in _installments) {
      draft.valueController.dispose();
      draft.dateController.dispose();
    }
    super.dispose();
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

  InputDecoration _buildFilledDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
    );
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
      prefixIcon: Icon(icon, color: colorScheme.onSurfaceVariant),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colorScheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: baseBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    );
  }

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

    // Verificar se já existe
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
    final colorScheme = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir categoria?'),
        content: const Text('Deseja remover esta categoria?'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
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
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final media = MediaQuery.of(context);
          final colorScheme = Theme.of(context).colorScheme;
          final maxW = media.size.width < 600 ? media.size.width * 0.92 : 480.0;
          final minW = media.size.width < 360 ? media.size.width * 0.92 : 360.0;
          final baseBorder = OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.0)),
          );

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
            ),
            backgroundColor: colorScheme.surface,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: minW,
                maxWidth: maxW,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  AppModalHeader(
                    title: 'Editar Categoria',
                    onClose: () => Navigator.pop(context),
                    showDivider: false,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nome da categoria',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Ex: Alimentação',
                      prefixIcon: Icon(Icons.label, color: colorScheme.onSurfaceVariant),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerLow,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: baseBorder,
                      enabledBorder: baseBorder,
                      focusedBorder: baseBorder.copyWith(
                        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ícone (emoji)',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          logoController.text.isNotEmpty
                              ? logoController.text
                              : '🙂',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          logoController.text.isNotEmpty
                              ? 'Selecionado'
                              : 'Nenhum selecionado',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          final selectedIcon = await showIconPickerDialog(
                            ctx,
                            initialIcon: logoController.text.isNotEmpty
                                ? logoController.text
                                : null,
                          );
                          if (selectedIcon != null) {
                            logoController.text = selectedIcon;
                            setStateDialog(() {});
                          }
                        },
                        icon: const Icon(Icons.emoji_emotions_outlined),
                        label: const Text('Escolher'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 120,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            minimumSize: const Size(0, 44),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            minimumSize: const Size(0, 44),
                          ),
                          onPressed: () {
                            final name = controller.text.trim();
                            final logo = logoController.text.trim();
                            Navigator.pop(ctx, {'name': name, 'logo': logo});
                          },
                          child: const Text('Salvar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        },
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
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      backgroundColor: colorScheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppModalHeader(
                title: 'Gerenciar Categorias',
                onClose: () => Navigator.pop(context),
                showDivider: false,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newCategoriaController,
                      decoration: _buildFilledDecoration(
                        label: 'Nova categoria',
                        icon: Icons.add,
                        suffixIcon: _newCategoriaController.text.isEmpty
                            ? null
                            : IconButton(
                                icon: Icon(Icons.clear, size: 20, color: colorScheme.onSurfaceVariant),
                                onPressed: () =>
                                    setState(() => _newCategoriaController.clear()),
                              ),
                      ),
                      onChanged: (val) => setState(() {}),
                      onSubmitted: (val) => _addCategory(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _addCategory,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: _categorias.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhuma categoria cadastrada',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _categorias.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, idx) {
                          final cat = _categorias[idx];
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              leading: Text(
                                cat.logo != null && cat.logo!.isNotEmpty ? cat.logo! : '📁',
                                style: const TextStyle(fontSize: 20),
                              ),
                              title: Text(
                                cat.categoria,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, color: colorScheme.onSurfaceVariant, size: 20),
                                    onPressed: () => _editCategory(cat),
                                    tooltip: 'Editar',
                                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                    padding: const EdgeInsets.all(12),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: colorScheme.error.withValues(alpha: 0.85), size: 20),
                                    onPressed: () => _deleteCategory(cat.id!),
                                    tooltip: 'Excluir',
                                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                    padding: const EdgeInsets.all(12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
