import 'package:flutter/material.dart';

class PdfExportDialog extends StatefulWidget {
  final String cityName;
  final String calendarType; // 'mensal', 'semanal', 'anual'
  final int selectedYear;
  final int selectedMonth;
  final VoidCallback onCalendarTypeChanged;
  final Map<String, dynamic> stats; // Contém informações de estatísticas
  final List<dynamic> holidays;

  const PdfExportDialog({
    super.key,
    required this.cityName,
    required this.calendarType,
    required this.selectedYear,
    required this.selectedMonth,
    required this.onCalendarTypeChanged,
    required this.stats,
    required this.holidays,
  });

  @override
  State<PdfExportDialog> createState() => _PdfExportDialogState();
}

class _PdfExportDialogState extends State<PdfExportDialog> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isMobile ? 500 : 1200,
          maxHeight: isMobile ? 800 : 900,
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Preview - Exportação em PDF',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Cidade
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cidade:',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.cityName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tipo de calendário
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tipo de Calendário:',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.calendarType.replaceFirst(
                        widget.calendarType[0],
                        widget.calendarType[0].toUpperCase(),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Informação sobre o calendário
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Período:',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getPeriodText(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Resumo em tabela zebrada
              _buildStatsTable(context),
              const SizedBox(height: 24),

              // Botões
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      // A geração real do PDF é feita através do botão "Imprimir Relatório"
                      // Este é apenas um preview dialog
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Fechar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPeriodText() {
    final monthNames = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro'
    ];

    if (widget.calendarType == 'anual') {
      return 'Ano ${widget.selectedYear}';
    } else {
      return '${monthNames[widget.selectedMonth - 1]} de ${widget.selectedYear}';
    }
  }

  Widget _buildStatsTable(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumo de Feriados',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
          ),
          const SizedBox(height: 12),
          // Linhas da tabela zebrada
          _buildTableRow('Total de Feriados', _getTotalHolidays().toString(), true),
          _buildTableRow('Dias Úteis', _getBusinessDays().toString(), false),
          _buildTableRow('Fins de Semana', _getWeekendDays().toString(), true),
          _buildTableRow('Feriados Nacionais', _getHolidaysByType('Nacional').toString(), false),
          _buildTableRow('Feriados Municipais', _getHolidaysByType('Municipal').toString(), true),
          _buildTableRow('Feriados Bancários', _getHolidaysByType('Bancário').toString(), false),
          _buildTableRow('Feriados Estaduais', _getHolidaysByType('Estadual').toString(), true),
        ],
      ),
    );
  }

  Widget _buildTableRow(String label, String value, bool isStriped) {
    return Container(
      color: isStriped ? Colors.white : Colors.grey[50],
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods para calcular estatísticas
  int _getTotalHolidays() {
    final Set<String> uniqueDates = {};
    for (var holiday in widget.holidays) {
      try {
        final date = DateTime.parse(holiday.date);
        // Filtrar apenas do ano/mês selecionados dependendo do tipo
        if (widget.calendarType == 'anual') {
          if (date.year == widget.selectedYear) {
            uniqueDates.add(holiday.date);
          }
        } else if (widget.calendarType == 'mensal') {
          if (date.year == widget.selectedYear && date.month == widget.selectedMonth) {
            uniqueDates.add(holiday.date);
          }
        } else if (widget.calendarType == 'semanal') {
          if (date.year == widget.selectedYear && date.month == widget.selectedMonth) {
            uniqueDates.add(holiday.date);
          }
        }
      } catch (e) {
        // Ignorar erros de parse
      }
    }
    return uniqueDates.length;
  }

  int _getBusinessDays() {
    int count = 0;
    for (var holiday in widget.holidays) {
      try {
        final date = DateTime.parse(holiday.date);
        // Contar apenas se for dia útil (seg-sex) e dentro do período
        if (date.weekday >= DateTime.monday && date.weekday <= DateTime.friday) {
          if (widget.calendarType == 'anual') {
            if (date.year == widget.selectedYear) count++;
          } else if (widget.calendarType == 'mensal' || widget.calendarType == 'semanal') {
            if (date.year == widget.selectedYear && date.month == widget.selectedMonth) count++;
          }
        }
      } catch (e) {
        // Ignorar erros
      }
    }
    return count;
  }

  int _getWeekendDays() {
    int count = 0;
    for (var holiday in widget.holidays) {
      try {
        final date = DateTime.parse(holiday.date);
        // Contar apenas se for fim de semana
        if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
          if (widget.calendarType == 'anual') {
            if (date.year == widget.selectedYear) count++;
          } else if (widget.calendarType == 'mensal' || widget.calendarType == 'semanal') {
            if (date.year == widget.selectedYear && date.month == widget.selectedMonth) count++;
          }
        }
      } catch (e) {
        // Ignorar erros
      }
    }
    return count;
  }

  int _getHolidaysByType(String type) {
    int count = 0;
    final Set<String> uniqueDates = {};
    for (var holiday in widget.holidays) {
      try {
        if (holiday.types != null && holiday.types is List) {
          bool hasType = false;
          for (var t in holiday.types) {
            if (t.toString().contains(type)) {
              hasType = true;
              break;
            }
          }
          if (hasType) {
            final date = DateTime.parse(holiday.date);
            if (widget.calendarType == 'anual') {
              if (date.year == widget.selectedYear && !uniqueDates.contains(holiday.date)) {
                uniqueDates.add(holiday.date);
                count++;
              }
            } else if (widget.calendarType == 'mensal' || widget.calendarType == 'semanal') {
              if (date.year == widget.selectedYear &&
                  date.month == widget.selectedMonth &&
                  !uniqueDates.contains(holiday.date)) {
                uniqueDates.add(holiday.date);
                count++;
              }
            }
          }
        }
      } catch (e) {
        // Ignorar erros
      }
    }
    return count;
  }
}
