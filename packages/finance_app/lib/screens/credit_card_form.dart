import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:brasil_fields/brasil_fields.dart';
import '../database/db_helper.dart';
import '../models/account_type.dart';
import '../models/account_category.dart';
import '../models/account.dart';
import '../utils/color_contrast.dart';
import '../utils/app_colors.dart';
import '../widgets/mastercard_logo.dart';
import '../widgets/visa_logo.dart';
import '../widgets/elo_logo.dart';
import '../widgets/amex_logo.dart';

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

    final maxWidth = (screenSize.width * 0.92).clamp(320.0, 860.0);
    final availableHeight = screenSize.height - viewInsets.bottom;
    final maxHeight = math.min(620.0, availableHeight * 0.85);

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

  final List<Color> _colors = List<Color>.from(AppColors.essentialPalette);

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
        if (_colors.every((color) => color.toARGB32() != _selectedColor)) {
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
    setState(() {
      _bestBuyDay = best;
    });
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

  Widget _buildBrandRow(String brand, {bool compactLogo = false}) {
    final normalized = brand.trim().toUpperCase();
    Widget? logo;
    Widget? assetLogo;
    if (normalized == 'MASTERCARD' || normalized == 'MASTER CARD' || normalized == 'MASTER') {
      assetLogo = Image.asset(
        'assets/icons/cc_mc.png',
        package: 'finance_app',
        width: 28,
        height: 18,
        fit: BoxFit.contain,
      );
      logo = compactLogo ? assetLogo : const MastercardLogo(width: 28, height: 18);
    } else if (normalized == 'ELO') {
      assetLogo = Image.asset(
        'assets/icons/cc_elo.png',
        package: 'finance_app',
        width: 28,
        height: 18,
        fit: BoxFit.contain,
      );
      logo = compactLogo ? assetLogo : const EloLogo(width: 28, height: 18);
    } else if (normalized == 'VISA') {
      assetLogo = Image.asset(
        'assets/icons/cc_visa.png',
        package: 'finance_app',
        width: 28,
        height: 18,
        fit: BoxFit.contain,
      );
      logo = compactLogo ? assetLogo : const VisaLogo(width: 32, height: 18);
    } else if (normalized == 'AMEX' || normalized == 'AMERICAN EXPRESS' || normalized == 'AMERICANEXPRESS') {
      assetLogo = Image.asset(
        'assets/icons/cc_amex.png',
        package: 'finance_app',
        width: 28,
        height: 18,
        fit: BoxFit.contain,
      );
      logo = compactLogo ? assetLogo : const AmexLogo(width: 28, height: 18);
    }
    final displayLogo = compactLogo ? (assetLogo ?? logo) : logo;
    return Row(
      children: [
        SizedBox(
          width: 34,
          height: 20,
          child: Center(
            child: displayLogo ?? const Icon(Icons.credit_card, size: 18),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            brand,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEditing = widget.cardToEdit != null;
    final editColor = isEditing && widget.cardToEdit?.cardColor != null
        ? Color(widget.cardToEdit!.cardColor!)
        : colorScheme.surface;
    final editFg = foregroundColorFor(editColor);

    InputDecoration inputDecoration({
      required String label,
      IconData? icon,
      String? hintText,
      String? helperText,
      bool isDense = false,
    }) {
      return InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        isDense: isDense,
        prefixIcon: icon != null ? Icon(icon) : null,
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
        contentPadding: isDense
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Cartão' : 'Novo Cartão'),
        backgroundColor: colorScheme.surface,
        foregroundColor: editFg,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: const [],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double maxWidth = constraints.maxWidth < 820
              ? constraints.maxWidth
              : 820.0;
            final bool compactPadding = constraints.maxHeight < 620;
            final bool tightLayout = constraints.maxHeight < 580;
            final EdgeInsets contentPadding = compactPadding
              ? const EdgeInsets.fromLTRB(12, 10, 12, 10)
              : const EdgeInsets.fromLTRB(16, 12, 16, 12);
            final EdgeInsets sectionPadding = compactPadding
              ? const EdgeInsets.all(12)
              : const EdgeInsets.all(16);
            final double gapSm = compactPadding ? 8 : 10;
            final double gapMd = compactPadding ? 10 : 12;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: contentPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: sectionPadding,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: Color(_selectedColor),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Cor do cartão',
                                          style: TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      OutlinedButton(
                                        onPressed: _showColorPicker,
                                        child: const Text('Escolher'),
                                      ),
                                    ],
                                  ),
                                  if (!tightLayout) ...[
                                    SizedBox(height: gapSm),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Chip(
                                        label: Text('Cor: ${_selectedColorLabel()}'),
                                        backgroundColor: colorScheme.surfaceContainerHighest,
                                        side: BorderSide(
                                          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                                        ),
                                        avatar: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: Color(_selectedColor),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  SizedBox(height: gapSm),
                                  TextFormField(
                                    initialValue: 'Cartões de Crédito',
                                    readOnly: true,
                                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                                    decoration: inputDecoration(
                                      label: 'Categoria no App',
                                      icon: Icons.lock,
                                      isDense: compactPadding,
                                    ),
                                  ),
                                  SizedBox(height: gapSm),
                                  DropdownButtonFormField<String>(
                                    initialValue: _brands.contains(_selectedBrand)
                                        ? _selectedBrand
                                        : null,
                                    isExpanded: true,
                                    selectedItemBuilder: (context) => _brands
                                        .map((b) => _buildBrandRow(b, compactLogo: true))
                                        .toList(),
                                    decoration: inputDecoration(
                                      label: 'Bandeira',
                                      icon: Icons.flag,
                                      isDense: compactPadding,
                                    ),
                                    items: _brands
                                        .map(
                                          (b) => DropdownMenuItem(
                                            value: b,
                                            child: _buildBrandRow(b, compactLogo: true),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) => setState(() => _selectedBrand = val),
                                    hint: const Text('Selecione'),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: gapSm),
                            Container(
                              padding: sectionPadding,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: _bankController,
                                    textCapitalization: TextCapitalization.words,
                                    decoration: inputDecoration(
                                      label: 'Banco Emissor',
                                      icon: Icons.account_balance,
                                      hintText: 'Ex: Nubank',
                                      isDense: compactPadding,
                                    ),
                                    validator: (v) =>
                                        v!.isEmpty ? 'Obrigatório informar o banco' : null,
                                  ),
                                  SizedBox(height: gapSm),
                                  LayoutBuilder(
                                    builder: (context, rowConstraints) {
                                      final isWide = rowConstraints.maxWidth >= 600;
                                      final helper = !tightLayout && _bestBuyDay != null
                                          ? 'Estimativa de fechamento: Dia $_bestBuyDay'
                                          : null;
                                      final fields = [
                                        Expanded(
                                          child: DropdownButtonFormField<int>(
                                            initialValue: _dueDay,
                                            decoration: inputDecoration(
                                              label: 'Vencimento',
                                              icon: Icons.calendar_today,
                                              isDense: compactPadding,
                                            ),
                                            items: List.generate(
                                              31,
                                              (i) => DropdownMenuItem(
                                                value: i + 1,
                                                child: Text('Dia ${i + 1}'),
                                              ),
                                            ),
                                            onChanged: (val) {
                                              setState(() => _dueDay = val!);
                                              _calculateBestDay(val!);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 10, height: 10),
                                        Expanded(
                                          child: DropdownButtonFormField<int?>(
                                            initialValue: _bestBuyDay,
                                            decoration: inputDecoration(
                                              label: 'Melhor Dia',
                                              icon: Icons.shopping_bag,
                                              helperText: helper,
                                              isDense: compactPadding,
                                            ),
                                            items: [
                                              const DropdownMenuItem(
                                                value: null,
                                                child: Text('Não sei'),
                                              ),
                                              ...List.generate(
                                                31,
                                                (i) => DropdownMenuItem(
                                                  value: i + 1,
                                                  child: Text('Dia ${i + 1}'),
                                                ),
                                              ),
                                            ],
                                            onChanged: (val) => setState(() => _bestBuyDay = val),
                                          ),
                                        ),
                                      ];

                                      return isWide
                                          ? Row(children: fields)
                                          : Column(children: fields);
                                    },
                                  ),
                                  SizedBox(height: gapSm),
                                  TextFormField(
                                    controller: _limitController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      CentavosInputFormatter(moeda: true),
                                    ],
                                    decoration: inputDecoration(
                                      label: 'Limite (R\$) - Opcional',
                                      icon: Icons.attach_money,
                                      isDense: compactPadding,
                                    ),
                                  ),
                                  SizedBox(height: gapMd),
                                  const Text(
                                    'Se o vencimento cair em feriado/fim de semana:',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  SizedBox(height: gapSm),
                                  SegmentedButton<bool>(
                                    segments: const [
                                      ButtonSegment(
                                        value: false,
                                        label: Text('Pagar depois'),
                                        icon: Icon(Icons.arrow_forward),
                                      ),
                                      ButtonSegment(
                                        value: true,
                                        label: Text('Antecipar'),
                                        icon: Icon(Icons.arrow_back),
                                      ),
                                    ],
                                    selected: {_payInAdvance},
                                    onSelectionChanged: (sel) =>
                                        setState(() => _payInAdvance = sel.first),
                                    style: const ButtonStyle(
                                      visualDensity: VisualDensity.compact,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      minimumSize: WidgetStatePropertyAll(Size(0, 32)),
                                      padding: WidgetStatePropertyAll(
                                        EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          SizedBox(height: gapMd),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        contentPadding.left,
                        0,
                        contentPadding.right,
                        contentPadding.bottom,
                      ),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 12,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _saveCard,
                              child: const Text('Gravar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _selectedColorLabel() {
    final selected = Color(_selectedColor);
    final index = _colors.indexWhere((c) => c.toARGB32() == selected.toARGB32());
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
                children: _colors
                    .map(
                      (color) => InkWell(
                        onTap: () {
                          setState(() => _selectedColor = color.toARGB32());
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
                              color: _selectedColor == color.toARGB32()
                                  ? colorScheme.onSurface
                                  : colorScheme.outlineVariant.withValues(alpha: 0.6),
                              width: _selectedColor == color.toARGB32() ? 2 : 1,
                            ),
                          ),
                          child: _selectedColor == color.toARGB32()
                              ? Icon(
                                  Icons.check,
                                  size: 14,
                                  color: foregroundColorFor(color),
                                )
                              : null,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveCard() async {
    if (_selectedType == null || !_formKey.currentState!.validate()) return;
    double limitVal = 0.0;
    if (_limitController.text.isNotEmpty) {
      limitVal = UtilBrasilFields.converterMoedaParaDouble(_limitController.text);
    }
    final brand = _selectedBrand ?? (_brands.isNotEmpty ? _brands.first : _defaultBrands.first);
    final cardAccount = Account(
      id: widget.cardToEdit?.id,
      typeId: _selectedType!.id!,
      description: '${_bankController.text} - $brand',
      value: 0.0,
      dueDay: _dueDay,
      isRecurrent: true,
      payInAdvance: _payInAdvance,
      month: null,
      year: null,
      bestBuyDay: _bestBuyDay,
      cardBrand: brand,
      cardBank: _bankController.text,
      cardLimit: limitVal,
      cardColor: _selectedColor,
    );
    if (widget.cardToEdit == null) {
      await DatabaseHelper.instance.createAccount(cardAccount);
    } else {
      await DatabaseHelper.instance.updateAccount(cardAccount);
    }
    if (mounted) Navigator.pop(context, true);
  }
}
