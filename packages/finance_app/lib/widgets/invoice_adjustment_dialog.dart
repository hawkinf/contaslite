import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/holiday_service.dart';
import '../services/prefs_service.dart';

/// Resultado do dialog de ajuste de fatura
class InvoiceAdjustmentResult {
  final int month;
  final int year;
  final DateTime dueDate;

  const InvoiceAdjustmentResult({
    required this.month,
    required this.year,
    required this.dueDate,
  });
}

/// Dialog para ajuste de fatura quando a competência selecionada difere da sugerida.
class InvoiceAdjustmentDialog extends StatefulWidget {
  /// Mês sugerido (calculado pela data de compra + fechamento)
  final int suggestedMonth;
  /// Ano sugerido
  final int suggestedYear;
  /// Mês atualmente selecionado (pode diferir do sugerido)
  final int selectedMonth;
  /// Ano atualmente selecionado
  final int selectedYear;
  /// Dia de vencimento do cartão
  final int cardDueDay;
  /// Dia de fechamento do cartão
  final int? cardClosingDay;

  const InvoiceAdjustmentDialog({
    super.key,
    required this.suggestedMonth,
    required this.suggestedYear,
    required this.selectedMonth,
    required this.selectedYear,
    required this.cardDueDay,
    this.cardClosingDay,
  });

  @override
  State<InvoiceAdjustmentDialog> createState() => _InvoiceAdjustmentDialogState();
}

class _InvoiceAdjustmentDialogState extends State<InvoiceAdjustmentDialog> {
  late int _selectedMonth;
  late int _selectedYear;
  late DateTime _selectedDueDate;

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.selectedMonth;
    _selectedYear = widget.selectedYear;
    _selectedDueDate = _calculateDueDate(_selectedMonth, _selectedYear);
  }

  /// Valida o dia para um mês específico (garante que não ultrapasse o último dia)
  int _validDayForMonth(int desiredDay, int month, int year) {
    final lastDay = DateTime(year, month + 1, 0).day;
    if (desiredDay < 1) return 1;
    if (desiredDay > lastDay) return lastDay;
    return desiredDay;
  }

  /// Calcula a data de vencimento considerando feriados e fins de semana
  DateTime _calculateDueDate(int month, int year) {
    final safeDay = _validDayForMonth(widget.cardDueDay, month, year);
    DateTime dueDate = DateTime(year, month, safeDay);
    final city = PrefsService.cityNotifier.value;

    // Ajustar para próximo dia útil se cair em feriado ou fim de semana
    while (HolidayService.isWeekend(dueDate) ||
           HolidayService.isHoliday(dueDate, city)) {
      dueDate = dueDate.add(const Duration(days: 1));
    }

    return dueDate;
  }

  void _useSuggested() {
    setState(() {
      _selectedMonth = widget.suggestedMonth;
      _selectedYear = widget.suggestedYear;
      _selectedDueDate = _calculateDueDate(_selectedMonth, _selectedYear);
    });
  }

  void _updateCompetencia(int month, int year) {
    setState(() {
      _selectedMonth = month;
      _selectedYear = year;
      _selectedDueDate = _calculateDueDate(month, year);
    });
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate,
      firstDate: DateTime(_selectedYear, _selectedMonth, 1),
      lastDate: DateTime(_selectedYear, _selectedMonth + 1, 0),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() => _selectedDueDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final suggestedLabel = '${DateFormat('MMMM', 'pt_BR').format(DateTime(widget.suggestedYear, widget.suggestedMonth, 1))}/${widget.suggestedYear}';
    final suggestedDueDate = _calculateDueDate(widget.suggestedMonth, widget.suggestedYear);
    final suggestedDueLabel = DateFormat('dd/MM/yyyy (EEEE)', 'pt_BR').format(suggestedDueDate);

    final selectedLabel = '${DateFormat('MMMM', 'pt_BR').format(DateTime(_selectedYear, _selectedMonth, 1))}/$_selectedYear';
    final selectedDueLabel = DateFormat('dd/MM/yyyy (EEEE)', 'pt_BR').format(_selectedDueDate);

    final isSameAsSuggested = _selectedMonth == widget.suggestedMonth && _selectedYear == widget.suggestedYear;

    // Gerar lista de meses para seleção (6 meses antes e 12 meses depois)
    final now = DateTime.now();
    final months = <MapEntry<String, (int, int)>>[];
    for (int i = -6; i <= 12; i++) {
      final date = DateTime(now.year, now.month + i, 1);
      final label = '${DateFormat('MMMM', 'pt_BR').format(date)}/${date.year}';
      months.add(MapEntry(label, (date.month, date.year)));
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: colorScheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, minWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Título
              Row(
                children: [
                  Icon(Icons.calendar_month, color: colorScheme.primary, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ajuste de Fatura',
                      style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 20,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Fatura sugerida (read-only)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.primary.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 16, color: colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Fatura Sugerida',
                          style: textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Competência', style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                              Text(suggestedLabel, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Vencimento', style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                              Text(suggestedDueLabel, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Fatura selecionada (editável)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lançar na Fatura',
                      style: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Competência (dropdown)
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Competência',
                        prefixIcon: const Icon(Icons.event_note),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedLabel,
                          isDense: true,
                          isExpanded: true,
                          items: months.map((entry) {
                            final isSuggested = entry.value.$1 == widget.suggestedMonth &&
                                               entry.value.$2 == widget.suggestedYear;
                            return DropdownMenuItem<String>(
                              value: entry.key,
                              child: Text(
                                isSuggested ? '${entry.key} (sugerido)' : entry.key,
                                style: isSuggested
                                    ? TextStyle(fontWeight: FontWeight.w600, color: colorScheme.primary)
                                    : null,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            final entry = months.firstWhere((e) => e.key == value || '${e.key} (sugerido)' == value);
                            _updateCompetencia(entry.value.$1, entry.value.$2);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Vencimento (date picker)
                    InkWell(
                      onTap: _pickDueDate,
                      borderRadius: BorderRadius.circular(10),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Vencimento',
                          prefixIcon: const Icon(Icons.calendar_today),
                          suffixIcon: const Icon(Icons.edit_calendar, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        child: Text(selectedDueLabel),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Botão "Usar fatura sugerida"
              if (!isSameAsSuggested)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: OutlinedButton.icon(
                    onPressed: _useSuggested,
                    icon: const Icon(Icons.lightbulb_outline, size: 18),
                    label: const Text('Usar fatura sugerida'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: colorScheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),

              // Botões de ação
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                          InvoiceAdjustmentResult(
                            month: _selectedMonth,
                            year: _selectedYear,
                            dueDate: _selectedDueDate,
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Gravar com ajustes', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
