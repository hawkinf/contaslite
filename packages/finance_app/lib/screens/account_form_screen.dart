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
import '../utils/color_contrast.dart';
import 'account_types_screen.dart';
import 'settings_screen.dart';
import '../widgets/app_input_decoration.dart';
import '../utils/installment_utils.dart';

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
            text: DateFormat('dd/MM/yy').format(adjustedDate));
}

class AccountFormScreen extends StatefulWidget {
  final Account? accountToEdit;
  const AccountFormScreen({super.key, this.accountToEdit});

  @override
  State<AccountFormScreen> createState() => _AccountFormScreenState();
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

  final List<Color> _colors = [
    const Color(0xFFFF0000),
    const Color(0xFFFFFF00),
    const Color(0xFF0000FF),
    const Color(0xFFFFA500),
    const Color(0xFF00FF00),
    const Color(0xFF800080),
    const Color(0xFFFF1493),
    const Color(0xFF4B0082),
    const Color(0xFF00CED1),
    const Color(0xFF008080),
    const Color(0xFF2E8B57),
    const Color(0xFF6B8E23),
    const Color(0xFFBDB76B),
    const Color(0xFFDAA520),
    const Color(0xFFCD5C5C),
    const Color(0xFFFF7F50),
    const Color(0xFF8B0000),
    const Color(0xFF191970),
    const Color(0xFFFFFFFF),
    const Color(0xFF000000),
    const Color(0xFF808080),
    const Color(0xFF8B4513),
  ];
  int _selectedColor = 0xFFFFFFFF; // Branco padrão

  DateTime? _mainOriginalDueDate;
  DateTime? _mainAdjustedDueDate;
  bool _mainDueDateWasAdjusted = false;

  AccountType? _selectedType;
  AccountCategory? _selectedCategory;
  List<AccountType> _typesList = [];
  List<AccountCategory> _categorias = [];

  List<InstallmentDraft> _installments = [];
  int _recurrentDay = 10;
  int _recurrentStartMonth = 0; // Mês de início da recorrência (0 = janeiro, ...11 = dezembro)
  int _recurrentStartYear = 0; // Ano de início da recorrência
  bool _payInAdvance = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    
    // Inicializar mês/ano com os valores atuais
    final now = DateTime.now();
    _recurrentStartMonth = now.month - 1; // 0-11
    _recurrentStartYear = now.year;
    _recurrentStartYearController.text = _recurrentStartYear.toString();
    
    // Sincronizar Valor Lançado com Valor Médio
    _recurrentValueController.addListener(() {
      if (_recurrentLaunchedValueController.text.isEmpty) {
        _recurrentLaunchedValueController.text = _recurrentValueController.text;
      }
    });
    
    _dateMaskFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
      // Remove non-digits
      String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

      // Limit to 6 digits (ddmmyy)
      if (digitsOnly.length > 6) {
        digitsOnly = digitsOnly.substring(0, 6);
      }

      // Format: dd/mm/yy
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
            final allAccounts =
                await DatabaseHelper.instance.readAllAccountsRaw();
            final parent =
                allAccounts.firstWhere((a) => a.id == parentId, orElse: () => acc);
            if (parent.isRecurrent && parent.id == parentId && mounted) {
              final children = allAccounts
                  .where((a) => a.recurrenceId == parentId && a.month != null && a.year != null)
                  .toList();
              if (children.isNotEmpty) {
                children.sort((a, b) {
                  final dateA = DateTime(a.year!, a.month!, a.dueDay);
                  final dateB = DateTime(b.year!, b.month!, b.dueDay);
                  return dateA.compareTo(dateB);
                });
                final first = children.first;
                _recurrentStartMonth = (first.month ?? DateTime.now().month) - 1;
                _recurrentStartYear = first.year ?? DateTime.now().year;
                _recurrentStartYearController.text = _recurrentStartYear.toString();
              }

              _editingAccount = parent;
              debugPrint(
                  '✅ Recorrência pai carregada: ${parent.description}, valor=${parent.value}');

              setState(() {
                _descController.text = parent.description;
                _totalValueController.text =
                    UtilBrasilFields.obterReal(parent.value);
                _recurrentValueController.text =
                    UtilBrasilFields.obterReal(parent.value);
                _recurrentLaunchedValueController.text =
                    UtilBrasilFields.obterReal(parent.value);
                _recurrentDay = parent.dueDay;
                _payInAdvance = parent.payInAdvance;
                _observationController.text = parent.observation ?? "";
                _selectedColor = parent.cardColor ?? 0xFFFFFFFF;
                _entryMode = 1; // Recorrente
                _dateController.text = DateFormat('dd/MM/yy').format(
                    DateTime(DateTime.now().year, DateTime.now().month,
                        parent.dueDay));
                _installmentsQtyController.text = "recorrente";
              });
            }
          } catch (e) {
            debugPrint('❌ Erro ao carregar recorrência pai: $e');
          }
        });
      } else if (acc.isRecurrent) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            final allAccounts =
                await DatabaseHelper.instance.readAllAccountsRaw();
            final children = allAccounts
                .where((a) => a.recurrenceId == acc.id && a.month != null && a.year != null)
                .toList();
            if (children.isNotEmpty && mounted) {
              children.sort((a, b) {
                final dateA = DateTime(a.year!, a.month!, a.dueDay);
                final dateB = DateTime(b.year!, b.month!, b.dueDay);
                return dateA.compareTo(dateB);
              });
              final first = children.first;
              setState(() {
                _recurrentStartMonth = (first.month ?? DateTime.now().month) - 1;
                _recurrentStartYear = first.year ?? DateTime.now().year;
                _recurrentStartYearController.text =
                    _recurrentStartYear.toString();
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
      _recurrentValueController.text = UtilBrasilFields.obterReal(acc.value);
      _recurrentLaunchedValueController.text = UtilBrasilFields.obterReal(acc.value);
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
        _dateController.text = DateFormat('dd/MM/yy').format(
            DateTime(DateTime.now().year, DateTime.now().month, acc.dueDay));
        debugPrint('✅ _entryMode setado para 1 (Recorrente) por isRecurrent ou recurrenceId');
      } else {
        _entryMode = 0; // Avulsa/Parcelada
        // Carregar valor total e data
        _totalValueController.text = UtilBrasilFields.obterReal(acc.value);
        _dateController.text = DateFormat('dd/MM/yy').format(DateTime(
            acc.year ?? DateTime.now().year,
            acc.month ?? DateTime.now().month,
            acc.dueDay));
        // Definir quantidade de parcelas como 1 (pode ser editado depois)
        _installmentsQtyController.text = "1";
        debugPrint('❌ _entryMode setado para 0 (Avulsa) - não é recorrente');
      }
    } else {
      _setInitialDate();
    }
    _loadInitialData();
    _loadPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onMainDateChanged(_dateController.text);
    });
  }

  Future<void> _loadCategories() async {
    if (_selectedType?.id == null) {
      setState(() {
        _categorias = [];
      });
      return;
    }

    final categorias =
        await DatabaseHelper.instance.readAccountCategories(_selectedType!.id!);

    setState(() {
      _categorias = categorias;
    });
  }

  Future<void> _showCategoriesDialog() async {
    if (_selectedType?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selecione um tipo de conta primeiro'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    await _loadCategories();

    if (!mounted) return;
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
    final types = await DatabaseHelper.instance.readAllTypes();

    final filteredTypes =
        types.where((t) => !t.name.toLowerCase().contains('cart')).toList();

    setState(() {
      _typesList = filteredTypes;

      // INICIALIZAÇÃO SEGURA DE VALORES
      if (widget.accountToEdit != null) {
        try {
          _selectedType = filteredTypes
              .firstWhere((t) => t.id == widget.accountToEdit!.typeId);
        } catch (_) {
          _selectedType = filteredTypes.isNotEmpty ? filteredTypes.first : null;
        }
      } else if (filteredTypes.isNotEmpty) {
        _selectedType = filteredTypes.first;
      }
    });
    await _loadCategories();
  }

  Future<void> _onTypeChanged(AccountType? val) async {
    setState(() {
      _selectedType = val;
      _categorias = [];
      _selectedCategory = null;
      _descController.clear();
    });
    await _loadCategories();
  }

  Future<void> _setInitialDate() async {
    // Corrigido: Data inicial é HOJE (formato dd/mm/yy)
    final date = DateTime.now();
    _dateController.text = DateFormat('dd/MM/yy').format(date);
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
    DateTime initialDate;
    try {
      final text = controller.text.trim();
      if (text.isEmpty || text.length < 8) {
        initialDate = DateTime.now();
      } else {
        // Converter dd/mm/yy para data completa (sempre 20xx)
        List<String> parts = text.split('/');
        if (parts.length == 3) {
          int day = int.parse(parts[0]);
          int month = int.parse(parts[1]);
          int year = int.parse(parts[2]);
          if (year < 100) year = 2000 + year;
          initialDate = DateTime(year, month, day);
        } else {
          initialDate = DateTime.now();
        }
        // Ensure initialDate is within valid range
        if (initialDate.isBefore(DateTime(2020))) {
          initialDate = DateTime.now();
        } else if (initialDate.isAfter(DateTime(2030))) {
          initialDate = DateTime.now();
        }
      }
    } catch (e) {
      initialDate = DateTime.now();
    }

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
        String formatted = DateFormat('dd/MM/yy').format(picked);
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
              backgroundColor: Colors.red),
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

    double totalValue =
        UtilBrasilFields.converterMoedaParaDouble(_totalValueController.text);
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
      String newText = DateFormat('dd/MM/yyyy').format(result.adjustedDate);
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

  // --- HELPER PARA CAMPO COM ÍCONE E LABEL ACIMA ---
  Widget _buildFieldWithIcon({
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return child;
  }

  Widget _buildTypeDropdown() {
    if (_typesList.isEmpty) {
      return InkWell(
        onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AccountTypesScreen()))
            .then((_) => _loadInitialData()),
        child: Container(
          padding: const EdgeInsets.all(16),
          color: Colors.orange.shade50,
          child: Row(
            children: const [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text("Cadastre Tipos Primeiro!")
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFieldWithIcon(
          icon: Icons.account_balance_wallet,
          label: 'Tipo da Conta',
          child: DropdownButtonFormField<AccountType>(
            value: _selectedType,
            decoration: buildOutlinedInputDecoration(
              label: 'Tipo da Conta',
              icon: Icons.account_balance_wallet,
            ),
            items: _typesList
                .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                .toList(),
            onChanged: (val) => _onTypeChanged(val),
            validator: (val) => val == null ? 'Selecione um tipo' : null,
          ),
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
      ],
    );
  }

  Widget _buildColorPaletteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Cor da Conta",
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: _colors
              .map(
                (color) => InkWell(
                  onTap: () => setState(() => _selectedColor = color.value),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: _selectedColor == color.value
                          ? Border.all(
                              color: foregroundColorFor(color),
                              width: 3,
                            )
                          : Border.all(color: Colors.grey.shade400, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4)
                      ],
                    ),
                    child: _selectedColor == color.value
                        ? Icon(
                            Icons.check,
                            color: foregroundColorFor(color),
                            size: 24,
                          )
                        : null,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildLaunchTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Tipo de Lançamento",
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 10),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
                value: 0,
                label: Text("Avulsa / Parcelada"),
                icon: Icon(Icons.receipt_long)),
            ButtonSegment(
                value: 1,
                label: Text("Recorrente Fixa"),
                icon: Icon(Icons.loop)),
          ],
          selected: {_entryMode},
          onSelectionChanged: (Set<int> newSelection) =>
              setState(() => _entryMode = newSelection.first),
        ),
      ],
    );
  }

  Widget _buildAvulsaMode() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 1. INPUT DE DATA COM SELETOR DE CALENDÁRIO
      _buildFieldWithIcon(
        icon: Icons.calendar_month,
        label: 'Dia Base do Vencimento',
        child: TextFormField(
          controller: _dateController,
          keyboardType: TextInputType.number,
          inputFormatters: [_dateMaskFormatter],
          decoration: buildOutlinedInputDecoration(
            label: 'Dia Base do Vencimento',
            icon: Icons.calendar_month,
            hintText: "dd/mm/aa",
            suffixIcon: IconButton(
              icon: Icon(Icons.date_range, color: Colors.blue.shade700),
              tooltip: 'Selecionar Data',
              onPressed: () => _selectDate(_dateController),
            ),
          ),
          onChanged: _onMainDateChanged,
          validator: (value) => value == null || value.length < 8
              ? 'Data incompleta (dd/mm/aa)'
              : null,
        ),
      ),

      if (_mainOriginalDueDate != null)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data original: ${DateFormat('dd/MM/yy').format(_mainOriginalDueDate!)}',
                style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600),
              ),
              if (_mainDueDateWasAdjusted && _mainAdjustedDueDate != null)
                Text(
                  'Data ajustada: ${DateFormat('dd/MM/yy').format(_mainAdjustedDueDate!)}',
                  style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),

      const SizedBox(height: 20),

      // 2. VALOR TOTAL / TIPO (AVULSA OU RECORRENTE)
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 3,
          child: _buildFieldWithIcon(
            icon: Icons.attach_money,
            label: 'Valor Total (R\$)',
            child: TextFormField(
              controller: _totalValueController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CentavosInputFormatter(moeda: true),
              ],
              decoration: buildOutlinedInputDecoration(
                label: 'Valor Total (R\$)',
                icon: Icons.attach_money,
              ),
              onChanged: (val) => _updateInstallments(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _buildFieldWithIcon(
            icon: Icons.repeat,
            label: 'Tipo',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _entryMode == 1 ? Icons.repeat : Icons.credit_card,
                    color: _entryMode == 1 ? Colors.green : Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _entryMode == 1 ? 'Recorrente' : 'À Vista',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _entryMode == 1 ? Colors.green : Colors.blue,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ]),

      const SizedBox(height: 20),

      // CAMPOS ADICIONAIS PARA RECORRÊNCIA
      if (_entryMode == 1)
        Column(
          children: [
            // Seletor de Mês/Ano de Início
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mês
                Expanded(
                  flex: 1,
                  child: _buildFieldWithIcon(
                    icon: Icons.calendar_month,
                    label: 'Mês Início',
                    child: DropdownButtonFormField<int>(
                      value: _recurrentStartMonth,
                      decoration: buildOutlinedInputDecoration(
                        label: 'Mês',
                        icon: Icons.calendar_month,
                      ),
                      items: [
                        ...List.generate(12, (i) {
                          final months = [
                            'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
                            'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
                          ];
                          return DropdownMenuItem(
                            value: i,
                            child: Text(months[i]),
                          );
                        })
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _recurrentStartMonth = val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Ano
                Expanded(
                  flex: 1,
                  child: _buildFieldWithIcon(
                    icon: Icons.today,
                    label: 'Ano Início',
                    child: TextFormField(
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: buildOutlinedInputDecoration(
                        label: 'Ano (YYYY)',
                        icon: Icons.today,
                      ),
                      initialValue: _recurrentStartYear == 0
                          ? DateTime.now().year.toString()
                          : _recurrentStartYear.toString(),
                      onChanged: (val) {
                        setState(() {
                          _recurrentStartYear =
                              int.tryParse(val) ?? DateTime.now().year;
                          _recurrentStartYearController.text =
                              _recurrentStartYear.toString();
                        });
                      },
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Ano obrigatório';
                        final year = int.tryParse(val);
                        if (year == null || year < 2000 || year > 2100) {
                          return 'Ano inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),

      // 3. TABELA DE PARCELAS EDITÁVEIS (SÓ APARECE PARA AVULSA/PARCELADA)
      if (_entryMode == 0 && _installments.isNotEmpty && _installmentsQtyController.text != "-1")
        Column(children: [
          // Cabeçalho da Tabela
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(children: [
                SizedBox(width: 30),
                Expanded(
                    flex: 3,
                    child: Text("VENCIMENTO",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(
                    flex: 2,
                    child: Text("VALOR R\$",
                        textAlign: TextAlign.end,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11))),
              ])),
          // Lista de Parcelas
          Container(

              decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8)),
              child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _installments.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _installments[index];
                    return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Row(children: [
                          // Parcela #
                          CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.blue.shade100,
                              child: Text("${item.index}",
                                  style: TextStyle(
                                      color: Colors.blue.shade900,
                                      fontSize: 11))),
                          const SizedBox(width: 8),
                          // Vencimento (Editável)
                          Expanded(
                              flex: 3,
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextFormField(
                                      controller: item.dateController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                      decoration: buildOutlinedInputDecoration(
                                        label: 'Vencimento',
                                        icon: Icons.calendar_today,
                                        dense: true,
                                      ),
                                      inputFormatters: [_dateMaskFormatter],
                                      onChanged: (val) =>
                                          _onTableDateChanged(index, val),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
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
                                              style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                                            ),
                                          if (item.warning != null)
                                            Text(
                                              item.warning!,
                                              style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ])),
                          const SizedBox(width: 8),
                          // Valor R$ (Editável)
                          Expanded(
                              flex: 2,
                              child: TextFormField(
                                  controller: item.valueController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                      color: Colors.blue.shade800,
                                      fontWeight: FontWeight.bold),
                                  decoration: buildOutlinedInputDecoration(
                                    label: 'Valor',
                                    icon: Icons.attach_money,
                                    dense: true,
                                    prefixText: "R\$ ",
                                    prefixStyle: const TextStyle(fontSize: 12),
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    CentavosInputFormatter(moeda: true),
                                  ],
                                  onChanged: (val) {
                                    item.value = UtilBrasilFields
                                        .converterMoedaParaDouble(val);
                                    setState(() {});
                                  }))
                        ]));
                  })),
        ]),

      const SizedBox(height: 20),
      // REMOVIDO: Barra Total
    ]);
  }

  Widget _buildRecurrentMode() {
    return Column(children: [
      // Valor Médio e Valor Lançado
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Valores', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              flex: 1,
              child: _buildFieldWithIcon(
                icon: Icons.trending_flat,
                label: 'Valor Médio',
                child: TextFormField(
                  controller: _recurrentValueController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CentavosInputFormatter(moeda: true),
                  ],
                  decoration: buildOutlinedInputDecoration(
                    label: 'Valor Médio',
                    icon: Icons.trending_flat,
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Valor médio é obrigatório'
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: _buildFieldWithIcon(
                icon: Icons.attach_money,
                label: 'Valor Lançado',
                child: TextFormField(
                  controller: _recurrentLaunchedValueController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CentavosInputFormatter(moeda: true),
                  ],
                  decoration: buildOutlinedInputDecoration(
                    label: 'Valor Lançado',
                    icon: Icons.attach_money,
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
      const SizedBox(height: 20),
      // Dia Vencimento
      Row(children: [
        Expanded(
          flex: 2,
          child: _buildFieldWithIcon(
            icon: Icons.calendar_today,
            label: 'Dia Venc.',
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
        )
      ]),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(
          flex: 1,
          child: _buildFieldWithIcon(
            icon: Icons.calendar_month,
            label: 'Mês Inicial',
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
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 1,
          child: _buildFieldWithIcon(
            icon: Icons.event,
            label: 'Ano Inicial',
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
                if (value == null || value.isEmpty) {
                  return 'Ano inicial obrigatório';
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
        ),
      ]),
      const SizedBox(height: 20),
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
      )
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
        widget.accountToEdit != null ? "Editar Lançamento" : "Lançar Conta"),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.category),
              tooltip: "Tabelas de Contas",
              onPressed: () {
                Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AccountTypesScreen()))
                    .then((_) => _loadInitialData());
              }),
          IconButton(
              icon: const Icon(Icons.settings),
              tooltip: "Configurações",
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()));
              }),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Card com seleção de cor
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final bool stackVertical = constraints.maxWidth < 640;
                      final paletteSection = _buildColorPaletteSection();
                      final typeSection = SizedBox(
                        width: stackVertical ? double.infinity : 260,
                        child: _buildLaunchTypeSelector(),
                      );

                      if (stackVertical) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            paletteSection,
                            const SizedBox(height: 20),
                            typeSection,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: paletteSection),
                          const SizedBox(width: 24),
                          typeSection,
                        ],
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Card com tipo, categoria e descrição
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTypeDropdown(),
                      const SizedBox(height: 20),
                      // Campo de Categoria (se houver categorias cadastradas)
                      if (_categorias.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldWithIcon(
                              icon: Icons.label,
                              label: 'Categoria',
                              child: DropdownButtonFormField<AccountCategory>(
                                value: _selectedCategory,
                                decoration: buildOutlinedInputDecoration(
                                  label: 'Categoria',
                                  icon: Icons.label,
                                ),
                                validator: (val) => val == null
                                    ? 'Selecione uma categoria'
                                    : null,
                                items: _categorias
                                    .map((cat) => DropdownMenuItem(
                                          value: cat,
                                          child: Text(cat.categoria),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedCategory = val;
                                    // Não preencher automaticamente a descrição
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      _buildFieldWithIcon(
                        icon: Icons.description_outlined,
                        label: 'Descrição (Ex: TV Nova, Aluguel)',
                        child: TextFormField(
                          controller: _descController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: buildOutlinedInputDecoration(
                            label: 'Descrição (Ex: TV Nova, Aluguel)',
                            icon: Icons.description_outlined,
                          ),
                          validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Card com dados específicos do modo
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _entryMode == 0
                      ? _buildAvulsaMode()
                      : _buildRecurrentMode(),
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
                  child: _buildFieldWithIcon(
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
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Carregar tipo preferido
    final typeId = prefs.getInt('last_account_type_id');
    if (typeId != null) {
      await _loadInitialData();
      _selectedType = _typesList.firstWhere((t) => t.id == typeId,
          orElse: () => _typesList.first);
      await _loadCategories();
    }

    setState(() {});
  }

  // Removido bloco duplicado/solto e garantida estrutura correta.

  @override
  void dispose() {
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
            backgroundColor: Colors.orange),
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
              backgroundColor: Colors.red),
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
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
                backgroundColor: Colors.blue.shade700,
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
                                child: Text(
                                  cat.categoria,
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.black87),
                                  overflow: TextOverflow.ellipsis,
                                ),
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
