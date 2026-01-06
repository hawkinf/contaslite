import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../database/db_helper.dart';
import '../models/account.dart';
import '../services/holiday_service.dart';
import '../services/prefs_service.dart';
import '../utils/color_contrast.dart';
import '../utils/installment_utils.dart';
import 'app_input_decoration.dart';

class NewExpenseDialog extends StatefulWidget {
  final Account card;

  const NewExpenseDialog({super.key, required this.card});

  @override
  State<NewExpenseDialog> createState() => _NewExpenseDialogState();
}

class _NewExpenseDialogState extends State<NewExpenseDialog> {
  final _valueController = TextEditingController();
  final _establishmentController = TextEditingController();
  final _noteController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController(text: DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()));

  final List<Color> _palette = const [
    Color(0xFFFF0000),
    Color(0xFFFFFF00),
    Color(0xFF0000FF),
    Color(0xFFFFA500),
    Color(0xFF00FF00),
    Color(0xFF800080),
    Color(0xFFFFFFFF),
    Color(0xFF000000),
    Color(0xFF808080),
    Color(0xFF8B4513),
  ];

  String _installmentType = 'À Vista';
  DateTime? _selectedInvoiceMonth;
  DateTime? _defaultInvoiceMonth;
  List<DateTime> _invoiceOptions = [];
  late int _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.card.cardColor ?? Colors.indigo.toARGB32();
    _refreshInvoiceTargets();
  }

  @override
  void dispose() {
    _valueController.dispose();
    _establishmentController.dispose();
    _noteController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _refreshInvoiceTargets() {
    DateTime purchaseDate;
    try {
      purchaseDate = UtilData.obterDateTime(_dateController.text);
    } catch (_) {
      purchaseDate = DateTime.now();
    }
    final bestDay = widget.card.bestBuyDay ?? 1;
    DateTime baseMonth = DateTime(purchaseDate.year, purchaseDate.month, 1);
    if (purchaseDate.day >= bestDay) {
      baseMonth = DateTime(baseMonth.year, baseMonth.month + 1, 1);
    }

    final options = List<DateTime>.generate(6, (i) {
      final target = DateTime(baseMonth.year, baseMonth.month + i, 1);
      return DateTime(target.year, target.month, 1);
    });

    setState(() {
      _invoiceOptions = options;
      _defaultInvoiceMonth = options.isNotEmpty ? options.first : null;
      final previous = _selectedInvoiceMonth;
      if (previous != null) {
        final match = options.where((opt) => _sameMonth(opt, previous)).toList();
        _selectedInvoiceMonth = match.isNotEmpty ? match.first : options.first;
      } else {
        _selectedInvoiceMonth = options.first;
      }
    });
  }

  DateTime _invoiceMonthForInstallment(int installmentIndexZeroBased) {
    final purchaseDate = UtilData.obterDateTime(_dateController.text);
    final invoiceMonth = _selectedInvoiceMonth ??
        _defaultInvoiceMonth ??
        DateTime(purchaseDate.year, purchaseDate.month, 1);
    return DateTime(invoiceMonth.year, invoiceMonth.month + installmentIndexZeroBased, 1);
  }

  DateTime _dueDateForInvoiceMonth(DateTime invoiceMonth) {
    final dueDay = widget.card.dueDay;
    final bestDay = widget.card.bestBuyDay ?? 1;
    DateTime effectiveMonth = invoiceMonth;
    if (dueDay < bestDay) {
      effectiveMonth = DateTime(invoiceMonth.year, invoiceMonth.month + 1, 1);
    }
    final rawDate = DateTime(effectiveMonth.year, effectiveMonth.month, dueDay);
    final city = PrefsService.cityNotifier.value;
    final adjusted = HolidayService.adjustDateToBusinessDay(rawDate, city);
    return adjusted.date;
  }

  int _getInstallments() {
    if (_installmentType == 'À Vista') return 1;
    if (_installmentType.toLowerCase().contains('assin')) return 1;
    final match = RegExp(r'(\d+)x').firstMatch(_installmentType);
    return match != null ? int.parse(match.group(1)!) : 1;
  }

  Future<void> _launchExpense() async {
    if (_valueController.text.isEmpty) {
      _showError('Informe o valor da despesa');
      return;
    }

    double totalValue;
    try {
      totalValue = UtilBrasilFields.converterMoedaParaDouble(_valueController.text);
    } catch (_) {
      _showError('Valor inválido');
      return;
    }

    if (totalValue <= 0) {
      _showError('Valor deve ser maior que zero');
      return;
    }

    final purchaseDate = UtilData.obterDateTime(_dateController.text);
    final startInvoiceMonth = _selectedInvoiceMonth ??
      _defaultInvoiceMonth ??
      DateTime(purchaseDate.year, purchaseDate.month, 1);
    final normalizedStartInvoiceMonth = DateTime(startInvoiceMonth.year, startInvoiceMonth.month, 1);
    final uid = DateTime.now().microsecondsSinceEpoch.toString();

    try {
      final baseDescText = _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : (widget.card.cardBank ?? 'Assinatura');

      final isSubscription = _installmentType.toLowerCase().contains('assin');
      final sanitizedDescription = cleanInstallmentDescription(baseDescText.trim());

      if (isSubscription) {
        final firstDueDate = _dueDateForInvoiceMonth(normalizedStartInvoiceMonth);
        final account = Account(
          typeId: widget.card.typeId,
          description: sanitizedDescription,
          value: totalValue,
          dueDay: firstDueDate.day,
          month: normalizedStartInvoiceMonth.month,
          year: normalizedStartInvoiceMonth.year,
          isRecurrent: true,
          payInAdvance: widget.card.payInAdvance,
          cardId: widget.card.id,
          observation: _noteController.text,
          establishment: _establishmentController.text,
          cardColor: _selectedColor,
          purchaseUuid: uid,
          purchaseDate: purchaseDate.toIso8601String(),
          creationDate: DateTime.now().toIso8601String(),
        );
        await DatabaseHelper.instance.createAccount(account);
      } else {
        final installments = _getInstallments();
        final installmentValue = totalValue / installments;

        for (int i = 0; i < installments; i++) {
          // Importante: recalcula o vencimento de cada mês usando o dueDay do cartão.
          // Não pode usar o dia já ajustado do primeiro mês, senão “carrega” o ajuste
          // (ex.: caiu no fim de semana) para as próximas parcelas.
          final installmentInvoiceMonth = _invoiceMonthForInstallment(i);
          final adjustedDueDate = _dueDateForInvoiceMonth(installmentInvoiceMonth);
          final account = Account(
            typeId: widget.card.typeId,
            description: sanitizedDescription,
            value: installmentValue,
            dueDay: adjustedDueDate.day,
            month: installmentInvoiceMonth.month,
            year: installmentInvoiceMonth.year,
            isRecurrent: false,
            payInAdvance: widget.card.payInAdvance,
            cardId: widget.card.id,
            observation: _noteController.text,
            establishment: _establishmentController.text,
            cardColor: _selectedColor,
            purchaseUuid: uid,
            purchaseDate: purchaseDate.toIso8601String(),
            creationDate: DateTime.now().toIso8601String(),
            installmentIndex: i + 1,
            installmentTotal: installments,
          );
          await DatabaseHelper.instance.createAccount(account);
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Erro ao lançar despesa: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  Future<void> _pickPurchaseDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;

    final dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      _dateController.text = DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    });
    _refreshInvoiceTargets();
  }

  @override
  Widget build(BuildContext context) {
    final headerColor = Color(_selectedColor);
    final onHeader = foregroundColorFor(headerColor);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova despesa no cartão'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [headerColor, headerColor.withValues(alpha: 0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: headerColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.card.description,
                    style: TextStyle(
                      color: onHeader,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.card.cardBrand ?? 'Bandeira'}  •  ${widget.card.cardBank ?? 'Emissor'}',
                    style: TextStyle(color: onHeader.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _infoChip(label: 'Vencimento', value: 'Dia ${widget.card.dueDay}', color: onHeader),
                      _infoChip(
                        label: 'Melhor dia',
                        value: 'Dia ${widget.card.bestBuyDay ?? widget.card.dueDay}',
                        color: onHeader,
                      ),
                      if (widget.card.cardLimit != null)
                        _infoChip(
                          label: 'Limite',
                          value: UtilBrasilFields.obterReal(widget.card.cardLimit!),
                          color: onHeader,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Cor do lançamento'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _palette.map(_buildColorOption).toList(),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Dados da compra'),
            const SizedBox(height: 12),
            TextField(
              controller: _dateController,
              readOnly: true,
              onTap: _pickPurchaseDateTime,
              decoration: buildOutlinedInputDecoration(
                label: 'Data/Hora da compra',
                icon: Icons.access_time,
                suffixIcon: const Icon(Icons.edit_calendar_outlined),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DateTime>(
              isExpanded: true,
              key: ValueKey(_selectedInvoiceMonth?.millisecondsSinceEpoch ?? 0),
              initialValue: _selectedInvoiceMonth != null && _invoiceOptions.isNotEmpty
                  ? _invoiceOptions.firstWhere(
                      (opt) => _sameMonth(opt, _selectedInvoiceMonth!),
                      orElse: () => _selectedInvoiceMonth!,
                    )
                  : null,
              decoration: buildOutlinedInputDecoration(
                label: 'Fatura a ser lançada',
                icon: Icons.receipt_long,
                alignLabelWithHint: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              ),
              items: _invoiceOptions
                  .map(
                    (date) => DropdownMenuItem(
                      value: date,
                      child: _buildInvoiceDropdownLabel(date),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() => _selectedInvoiceMonth = val);
              },
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Valores e parcelas'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _valueController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      CentavosInputFormatter(moeda: true),
                    ],
                    decoration: buildOutlinedInputDecoration(
                      label: 'Valor Total (R\$)',
                      icon: Icons.attach_money,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_installmentType),
                    initialValue: _installmentType,
                    decoration: buildOutlinedInputDecoration(
                      label: 'Parcelamento',
                      icon: Icons.layers,
                    ),
                    items: const [
                      'À Vista',
                      'Assinatura',
                      '2x',
                      '3x',
                      '4x',
                      '5x',
                      '6x',
                      '7x',
                      '8x',
                      '9x',
                      '10x',
                      '11x',
                      '12x',
                    ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() => _installmentType = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Detalhes'),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: buildOutlinedInputDecoration(
                label: 'Descrição (opcional)',
                icon: Icons.label_outline,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _establishmentController,
              textCapitalization: TextCapitalization.words,
              decoration: buildOutlinedInputDecoration(
                label: 'Estabelecimento (opcional)',
                icon: Icons.store_mall_directory,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: buildOutlinedInputDecoration(
                label: 'Observações (opcional)',
                icon: Icons.note_alt_outlined,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _launchExpense,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
              backgroundColor: Colors.green.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.check_circle, size: 24),
            label: const Text(
              'Gravar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  String _formatMonthTitle(DateTime date) {
    final formatted = DateFormat('MMMM yyyy', 'pt_BR').format(date);
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  Widget _buildInvoiceDropdownLabel(DateTime date) {
    final month = _formatMonthTitle(date);
    final dueDate = _dueDateForInvoiceMonth(date);
    final due = DateFormat('dd/MM/yy').format(dueDate);
    final days = dueDate.difference(DateTime.now()).inDays;
    final isDefault = _defaultInvoiceMonth != null && _sameMonth(date, _defaultInvoiceMonth!);
    final primaryColor = isDefault ? Colors.blue.shade800 : Colors.black87;

    return Row(
      children: [
        if (isDefault) ...[
          Icon(Icons.star, color: Colors.blue.shade600, size: 16),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            '$month — vence em $due (${days}d)',
            style: TextStyle(
              fontWeight: isDefault ? FontWeight.w700 : FontWeight.w500,
              color: primaryColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  bool _sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

  Widget _infoChip({required String label, required String value, required Color color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildColorOption(Color color) {
    final isSelected = _selectedColor == color.toARGB32();
    return InkWell(
      onTap: () => setState(() => _selectedColor = color.toARGB32()),
      borderRadius: BorderRadius.circular(26),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? foregroundColorFor(color) : Colors.grey.shade300,
            width: isSelected ? 3 : 1.5,
          ),
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                size: 20,
                color: foregroundColorFor(color),
              )
            : null,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade800,
      ),
    );
  }
}
