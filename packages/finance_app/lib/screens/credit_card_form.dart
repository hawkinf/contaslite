import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:brasil_fields/brasil_fields.dart';
import '../database/db_helper.dart';
import '../models/account_type.dart';
import '../models/account_category.dart';
import '../models/account.dart';
import '../utils/color_contrast.dart';
import '../utils/app_colors.dart';
import '../widgets/app_input_decoration.dart';
import '../services/prefs_service.dart';
import '../widgets/date_range_app_bar.dart';
import '../widgets/dialog_close_button.dart';

class _CreditCardForm extends StatefulWidget {
  final Account? cardToEdit;
  const _CreditCardForm({this.cardToEdit});
  @override
  State<_CreditCardForm> createState() => _CreditCardFormScreenState();
}

class CreditCardFormScreen extends StatelessWidget {
  final Account? cardToEdit;
  const CreditCardFormScreen({super.key, this.cardToEdit});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final viewInsets = MediaQuery.of(context).viewInsets;

    // Calcular dimensões responsivas
    final maxWidth = (screenSize.width * 0.9).clamp(280.0, 600.0);
    final availableHeight = screenSize.height - viewInsets.bottom;
    final maxHeight = (availableHeight * 0.85).clamp(400.0, 900.0);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
      child: _CreditCardForm(cardToEdit: cardToEdit),
    );
  }
}

class _CreditCardFormScreenState extends State<_CreditCardForm> {
  final _formKey = GlobalKey<FormState>();
  final _bankController = TextEditingController();
  final _limitController = TextEditingController();
  
  AccountType? _selectedType;
  String? _selectedBrand;
  int _dueDay = 10;
  int? _bestBuyDay = 3; 
  bool _payInAdvance = false;
  
  int _selectedColor = 0xFFFF0000;

  final List<String> _defaultBrands = const ['Mastercard', 'Visa', 'ELO', 'AMEX', 'Hipercard'];
  List<String> _brands = [];
  
  final List<Color> _colors = [
    const Color(0xFFFF0000), const Color(0xFFFFFF00), const Color(0xFF0000FF),
    const Color(0xFFFFA500), const Color(0xFF00FF00), const Color(0xFF800080),
    const Color(0xFFFF1493), const Color(0xFF4B0082), const Color(0xFF00CED1),
    const Color(0xFF008080), const Color(0xFF2E8B57), const Color(0xFF6B8E23),
    const Color(0xFFBDB76B), const Color(0xFFDAA520), const Color(0xFFCD5C5C),
    const Color(0xFFFF7F50), const Color(0xFF8B0000), const Color(0xFF191970),
    const Color(0xFFFFFFFF), const Color(0xFF000000), const Color(0xFF808080),
    const Color(0xFF8B4513),
  ];

  @override
  void initState() {
    super.initState();
    _brands = _defaultBrands;
    _findCreditCardType();
    
    if (widget.cardToEdit != null) {
      _bankController.text = widget.cardToEdit!.cardBank ?? '';
      _limitController.text = UtilBrasilFields.obterReal(widget.cardToEdit!.cardLimit ?? 0.0);
      _dueDay = widget.cardToEdit!.dueDay;
      _bestBuyDay = widget.cardToEdit!.bestBuyDay;
      _selectedBrand = widget.cardToEdit!.cardBrand;
      _payInAdvance = widget.cardToEdit!.payInAdvance;
      if (widget.cardToEdit!.cardColor != null) {
        _selectedColor = widget.cardToEdit!.cardColor!;
        if (_colors.every((color) => color.value != _selectedColor)) {
          _colors.insert(0, Color(_selectedColor));
        }
      }
    } else {
      _calculateBestDay(_dueDay);
    }
  }

  @override
  void dispose() {
    _bankController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _findCreditCardType() async {
    final types = await DatabaseHelper.instance.readAllTypes();
    AccountType? ccType;
    try {
      ccType = types.firstWhere((t) => t.name.toLowerCase().contains('cart'));
    } catch (_) {
      ccType = types.isNotEmpty ? types.first : null;
    }
    setState(() => _selectedType = ccType);
    await _loadBrandOptions();
  }

  Future<void> _loadBrandOptions() async {
    if (_selectedType == null) {
      setState(() {
        _brands = _dedupBrands(_defaultBrands);
        _selectedBrand ??= _brands.first;
      });
      return;
    }
    List<AccountCategory> categorias = [];
    try {
      categorias = await DatabaseHelper.instance.readAccountCategories(_selectedType!.id!);
    } catch (_) {}

    final names = categorias.map((d) => d.categoria).toList();
    if (names.isEmpty) {
      setState(() {
        _brands = _dedupBrands(_defaultBrands);
        _selectedBrand ??= _brands.first;
      });
    } else {
      setState(() {
        _brands = _dedupBrands(names);
        if (_selectedBrand == null || !_brands.contains(_selectedBrand)) {
          _selectedBrand = _brands.first;
        }
      });
    }
  }

  void _calculateBestDay(int dueDay) {
    int best = dueDay - 7;
    if (best < 1) best = 31 + best;
    setState(() { _bestBuyDay = best; });
  }

  List<String> _dedupBrands(List<String> names) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in names) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      result.add(trimmed);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTimeRange>(
      valueListenable: PrefsService.dateRangeNotifier,
      builder: (context, range, _) {
        return Scaffold(
      appBar: DateRangeAppBar(
          title: widget.cardToEdit != null ? 'Editar Cartão' : 'Novo Cartão',
          range: range,
          onPrevious: () => PrefsService.shiftDateRange(-1),
          onNext: () => PrefsService.shiftDateRange(1),
          backgroundColor: Colors.deepPurple.shade700,
          foregroundColor: Colors.white,
          actions: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: DialogCloseButton(
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Escolha a Cor', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
                children: _colors.map((color) => InkWell(
                  onTap: () => setState(() => _selectedColor = color.value),
                    child: Container(
                    width: 45, height: 45,
                    decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle,
                      border: _selectedColor == color.value
                          ? Border.all(color: foregroundColorFor(color), width: 3)
                          : Border.all(color: Colors.grey.shade400),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)]
                    ),
                      child: _selectedColor == color.value
                          ? Center(
                              child: Text(
                                'Aa',
                                style: TextStyle(
                                  color: foregroundColorFor(color),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null
                    ),
                )).toList()
              ),
              
              const SizedBox(height: 30),

              TextFormField(
                initialValue: 'Cartões de Crédito',
                readOnly: true,
                style: TextStyle(color: Colors.grey.shade600),
                decoration: buildOutlinedInputDecoration(
                  label: 'Categoria no App',
                  icon: Icons.lock,
                ).copyWith(
                  filled: true,
                  fillColor: const Color(0xFFEEEEEE),
                ),
              ),
              
              const SizedBox(height: 20),
              
              DropdownButtonFormField<String>(
                value: _brands.contains(_selectedBrand) ? _selectedBrand : null,
                decoration: buildOutlinedInputDecoration(
                  label: 'Bandeira',
                  icon: Icons.flag,
                ),
                items: _brands.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                onChanged: (val) => setState(() => _selectedBrand = val),
                hint: const Text('Selecione'),
              ),
              
              const SizedBox(height: 20),
              
              TextFormField(
                controller: _bankController,
                textCapitalization: TextCapitalization.words,
                decoration: buildOutlinedInputDecoration(
                  label: 'Banco Emissor',
                  icon: Icons.account_balance,
                  hintText: 'Ex: Nubank',
                ),
                validator: (v) => v!.isEmpty ? 'Obrigatório informar o banco' : null,
              ),
              
              const SizedBox(height: 20),
              
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _dueDay,
                      decoration: buildOutlinedInputDecoration(
                        label: 'Vencimento',
                        icon: Icons.calendar_today,
                      ),
                      items: List.generate(31, (i) => DropdownMenuItem(value: i + 1, child: Text('Dia ${i + 1}'))),
                      onChanged: (val) { setState(() => _dueDay = val!); _calculateBestDay(val!); },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: _bestBuyDay,
                      decoration: buildOutlinedInputDecoration(
                        label: 'Melhor Dia',
                        icon: Icons.shopping_bag,
                      ),
                      items: [const DropdownMenuItem(value: null, child: Text('Não sei')), ...List.generate(31, (i) => DropdownMenuItem(value: i + 1, child: Text('Dia ${i + 1}')))],
                      onChanged: (val) => setState(() => _bestBuyDay = val),
                    ),
                  ),
                ],
              ),
              
              if (_bestBuyDay != null) Padding(padding: const EdgeInsets.only(top: 8, left: 12), child: Text('Estimativa de fechamento: Dia $_bestBuyDay', style: TextStyle(fontSize: 12, color: Color(_selectedColor), fontStyle: FontStyle.italic))),
              
              const SizedBox(height: 20),
              
              TextFormField(
                controller: _limitController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, CentavosInputFormatter(moeda: true)],
                decoration: buildOutlinedInputDecoration(
                  label: 'Limite (R\$) - Opcional',
                  icon: Icons.attach_money,
                ),
              ),
              
              const SizedBox(height: 30),
              
              const Text('Se o vencimento cair em feriado/fim de semana:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              SegmentedButton<bool>(
                segments: const [ButtonSegment(value: false, label: Text('Pagar Depois'), icon: Icon(Icons.arrow_forward)), ButtonSegment(value: true, label: Text('Antecipar'), icon: Icon(Icons.arrow_back))],
                selected: {_payInAdvance},
                onSelectionChanged: (sel) => setState(() => _payInAdvance = sel.first),
                style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
              
              const SizedBox(height: 40),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('Cancelar'),
                      onPressed: () => Navigator.pop(context),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _saveCard,
                      icon: const Icon(Icons.check_circle, size: 24),
                      label: const Text(
                        'Gravar',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
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
    );
  }

  Future<void> _saveCard() async {
    if (_selectedType == null || !_formKey.currentState!.validate()) return;
    double limitVal = 0.0;
    if (_limitController.text.isNotEmpty) limitVal = UtilBrasilFields.converterMoedaParaDouble(_limitController.text);
    final brand = _selectedBrand ?? (_brands.isNotEmpty ? _brands.first : _defaultBrands.first);
    final cardAccount = Account(id: widget.cardToEdit?.id, typeId: _selectedType!.id!, description: '${_bankController.text} - $brand', value: 0.0, dueDay: _dueDay, isRecurrent: true, payInAdvance: _payInAdvance, month: null, year: null, bestBuyDay: _bestBuyDay, cardBrand: brand, cardBank: _bankController.text, cardLimit: limitVal, cardColor: _selectedColor);
    if (widget.cardToEdit == null) { await DatabaseHelper.instance.createAccount(cardAccount); } else { await DatabaseHelper.instance.updateAccount(cardAccount); }
    if (mounted) Navigator.pop(context, true);
  }
}
// ignore_for_file: deprecated_member_use
