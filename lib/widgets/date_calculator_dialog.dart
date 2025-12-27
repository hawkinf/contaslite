import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class DateCalculatorDialog extends StatefulWidget {
  final DateTime referenceDate;
  final List<dynamic> holidays;
  final dynamic selectedCity;

  const DateCalculatorDialog({
    super.key,
    required this.referenceDate,
    required this.holidays,
    required this.selectedCity,
  });

  @override
  State<DateCalculatorDialog> createState() => _DateCalculatorDialogState();
}

class _DateCalculatorDialogState extends State<DateCalculatorDialog> {
  late DateTime _referenceDate;
  late DateTime _calculatedDate;
  late int _daysCount;
  late String _dayType; // 'uteis' ou 'totais'
  late String _direction; // 'frente' ou 'tras'
  late TextEditingController _daysController;
  late String _selectedCityName;

  @override
  void initState() {
    super.initState();
    _referenceDate = widget.referenceDate;
    _calculatedDate = widget.referenceDate;
    _daysCount = 0;
    _dayType = 'uteis';
    _direction = 'frente';
    _daysController = TextEditingController(text: '0');
    // Extrair o nome da cidade do objeto CityData
    _selectedCityName = widget.selectedCity?.name ?? 'Não definida';
  }

  @override
  void dispose() {
    _daysController.dispose();
    super.dispose();
  }

  void _calculateDate() {
    DateTime result = _referenceDate;
    int daysToAdd = _daysCount;
    if (_direction == 'tras') {
      daysToAdd = -daysToAdd;
    }

    if (_dayType == 'uteis') {
      // Calcular apenas dias úteis (ignorando feriados e fins de semana)
      final holidays = _getHolidayDays();
      int count = 0;
      int dayIncrement = daysToAdd > 0 ? 1 : -1;
      while (count.abs() < daysToAdd.abs()) {
        result = result.add(Duration(days: dayIncrement));
        // Verificar se é dia útil (não é sábado=6 nem domingo=7 e não é feriado)
        final dayKey = '${result.year}-${result.month.toString().padLeft(2, '0')}-${result.day.toString().padLeft(2, '0')}';
        if (result.weekday != 6 && result.weekday != 7 && !holidays.contains(dayKey)) {
          count += dayIncrement;
        }
      }
    } else {
      // Calcular dias totais (corridos)
      result = result.add(Duration(days: daysToAdd));
    }

    setState(() {
      _calculatedDate = result;
    });
  }

  Set<String> _getHolidayDays() {
    Set<String> holidays = {};
    for (var holiday in widget.holidays) {
      try {
        final holidayDate = DateTime.parse(holiday.date);
        final key = '${holidayDate.year}-${holidayDate.month.toString().padLeft(2, '0')}-${holidayDate.day.toString().padLeft(2, '0')}';
        holidays.add(key);
      } catch (e) {
        // Ignorar feriados inválidos
      }
    }
    return holidays;
  }

  String _getDayOfWeekName(DateTime date) {
    final dayNames = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
    return dayNames[date.weekday % 7];
  }

  String _getDayTypeLabel() {
    return _dayType == 'uteis' ? 'Úteis' : 'Corridos';
  }

  Map<String, String> _generatePdfData() {
    final refDateFormatted = DateFormat('dd/MM/yyyy', 'pt_BR').format(_referenceDate);
    final calcDateFormatted = DateFormat('dd/MM/yyyy', 'pt_BR').format(_calculatedDate);
    final refDayOfWeek = _getDayOfWeekName(_referenceDate);
    final calcDayOfWeek = _getDayOfWeekName(_calculatedDate);

    return {
      'cidade': _selectedCityName,
      'dataReferencia': '$refDateFormatted ($refDayOfWeek)',
      'dias': '$_daysCount ${_getDayTypeLabel()}',
      'dataCalculada': '$calcDateFormatted ($calcDayOfWeek)',
    };
  }

  void _showPdfPreview(BuildContext context, Map<String, String> data) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isMobile ? 500 : 1000,
            maxHeight: isMobile ? 600 : 700,
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Preview - Exportação em PDF',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // Dois calendários lado a lado
                if (!isMobile)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 350),
                          child: _buildCalendarPanel(_referenceDate, isReference: true),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 350),
                          child: _buildCalendarPanel(_calculatedDate, isReference: false),
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 350),
                        child: _buildCalendarPanel(_referenceDate, isReference: true),
                      ),
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 350),
                        child: _buildCalendarPanel(_calculatedDate, isReference: false),
                      ),
                    ],
                  ),

                const SizedBox(height: 24),

                // Tabela zebrada com resumo
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPdfTableRow('Cidade:', data['cidade']!, true),
                      _buildPdfTableRow('Data Referência:', data['dataReferencia']!, false),
                      _buildPdfTableRow('Dias:', data['dias']!, true),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Botões
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPdfTableRow(String label, String value, bool isStriped) {
    return Container(
      color: isStriped ? Colors.white : Colors.grey[50],
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarPanel(DateTime date, {bool isReference = false}) {
    final firstDay = DateTime(date.year, date.month, 1);
    final lastDay = DateTime(date.year, date.month + 1, 0);
    final firstDayOfWeek = firstDay.weekday % 7; // 0=domingo, 1=segunda, ..., 6=sábado
    final holidays = _getHolidayDays();

    final monthName = DateFormat('MMMM', 'pt_BR').format(date);
    final year = date.year;

    return Card(
      elevation: 2,
      color: isReference ? Colors.white : Colors.grey[400],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.black, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Título Data Referência ou Data Calculada (grande, bold, centralizado)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      isReference ? 'Data Referência' : 'Data Calculada',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                // Botão Reset (apenas para referência)
                if (isReference)
                  IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    icon: const Icon(Icons.refresh),
                    color: Colors.grey[600],
                    tooltip: 'Voltar para hoje',
                    onPressed: () {
                      setState(() {
                        final today = DateTime.now();
                        _referenceDate = DateTime(today.year, today.month, today.day);
                        _calculateDate();
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Seletor de Mês apenas (ANO é exibido mas não navegável)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Seta esquerda do Mês
                IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(Icons.arrow_left),
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: () {
                    setState(() {
                      if (isReference) {
                        if (_referenceDate.month == 1) {
                          _referenceDate = DateTime(_referenceDate.year - 1, 12, 1);
                        } else {
                          _referenceDate = DateTime(_referenceDate.year, _referenceDate.month - 1, 1);
                        }
                        _calculateDate();
                      } else {
                        if (_calculatedDate.month == 1) {
                          _calculatedDate = DateTime(_calculatedDate.year - 1, 12, 1);
                        } else {
                          _calculatedDate = DateTime(_calculatedDate.year, _calculatedDate.month - 1, 1);
                        }
                      }
                    });
                  },
                ),
                // Mês e Ano (lado a lado)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      monthName.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    Text(
                      year.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                // Seta direita do Mês
                IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(Icons.arrow_right),
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: () {
                    setState(() {
                      if (isReference) {
                        if (_referenceDate.month == 12) {
                          _referenceDate = DateTime(_referenceDate.year + 1, 1, 1);
                        } else {
                          _referenceDate = DateTime(_referenceDate.year, _referenceDate.month + 1, 1);
                        }
                        _calculateDate();
                      } else {
                        if (_calculatedDate.month == 12) {
                          _calculatedDate = DateTime(_calculatedDate.year + 1, 1, 1);
                        } else {
                          _calculatedDate = DateTime(_calculatedDate.year, _calculatedDate.month + 1, 1);
                        }
                      }
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Header dias da semana
            Row(
              children: ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB']
                  .map((day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            // Grid de dias
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.0,
              ),
              itemCount: firstDayOfWeek + lastDay.day,
              itemBuilder: (context, index) {
                if (index < firstDayOfWeek) {
                  return const SizedBox.shrink();
                }
                final day = index - firstDayOfWeek + 1;
                final currentDate = DateTime(date.year, date.month, day);

                final isReferenceSelected = isReference &&
                    currentDate.year == _referenceDate.year &&
                    currentDate.month == _referenceDate.month &&
                    currentDate.day == _referenceDate.day;

                final isCalculated = !isReference &&
                    currentDate.year == _calculatedDate.year &&
                    currentDate.month == _calculatedDate.month &&
                    currentDate.day == _calculatedDate.day;

                final today = DateTime.now();
                final isToday = isReference &&
                    currentDate.year == today.year &&
                    currentDate.month == today.month &&
                    currentDate.day == today.day;

                final holidayKey = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
                final isHoliday = holidays.contains(holidayKey);

                Color bgColor = Colors.white;
                Color textColor = Colors.black;
                double borderWidth = 1;
                BoxShape shape = BoxShape.rectangle;
                BorderRadius? borderRadius = BorderRadius.circular(4);

                if (isReferenceSelected && isToday) {
                  // Data de referência = hoje: círculo azul com borda preta
                  bgColor = Colors.blue;
                  textColor = Colors.white;
                  borderWidth = 2;
                  shape = BoxShape.circle;
                  borderRadius = null;
                } else if (isReferenceSelected) {
                  // Data de referência selecionada (não é hoje): azul com letras brancas
                  bgColor = Colors.blue;
                  textColor = Colors.white;
                } else if (isToday) {
                  // Dia de hoje (não é data de referência): círculo azul com borda preta
                  bgColor = Colors.blue;
                  textColor = Colors.white;
                  borderWidth = 2;
                  shape = BoxShape.circle;
                  borderRadius = null;
                } else if (isCalculated) {
                  // Data calculada destacada com círculo amarelo e borda preta grossa
                  bgColor = const Color(0xFFFFEB3B);
                  textColor = Colors.black;
                  borderWidth = 3;
                  shape = BoxShape.circle;
                  borderRadius = null;
                } else if (isHoliday) {
                  // Feriados sempre verde com letras brancas
                  bgColor = Colors.green;
                  textColor = Colors.white;
                } else if (currentDate.weekday == 7) { // Domingo
                  bgColor = Colors.red;
                  textColor = Colors.white;
                } else if (currentDate.weekday == 6) { // Sábado
                  bgColor = const Color(0xFFEF9A9A);
                  textColor = Colors.white;
                }

                return GestureDetector(
                  onTap: isReference ? () {
                    setState(() {
                      _referenceDate = currentDate;
                      _calculateDate();
                    });
                  } : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border.all(
                        color: Colors.black,
                        width: borderWidth,
                      ),
                      shape: shape,
                      borderRadius: borderRadius,
                    ),
                    child: Center(
                      child: Text(
                        day.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (!isReference) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.yellow[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black54, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy', 'pt_BR').format(date),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getDayOfWeekName(date),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;
    final isSmallMobile = screenWidth < 600;

    return Container(
      constraints: BoxConstraints(
        maxWidth: isSmallMobile ? 400 : (isMobile ? 500 : 900),
        maxHeight: isSmallMobile ? 1000 : (isMobile ? 800 : 700),
      ),
      padding: EdgeInsets.all(isSmallMobile ? 16 : 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho com cidade fixa (definida nas preferências) e botão de PDF
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Cidade',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedCityName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  color: Colors.grey[600],
                  iconSize: 20,
                  tooltip: 'Exportar PDF',
                  onPressed: () {
                    final pdfData = _generatePdfData();
                    _showPdfPreview(context, pdfData);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Dois painéis de calendário (referência esquerda, calculado direita)
            if (!isMobile)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 400),
                      child: _buildCalendarPanel(_referenceDate, isReference: true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 400),
                      child: _buildCalendarPanel(_calculatedDate, isReference: false),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 400),
                    child: _buildCalendarPanel(_referenceDate, isReference: true),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 400),
                    child: _buildCalendarPanel(_calculatedDate, isReference: false),
                  ),
                ],
              ),


            // Seção de cálculo
            Card(
              child: Padding(
                padding: EdgeInsets.all(isSmallMobile ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calcular Dias',
                      style: TextStyle(
                        fontSize: isSmallMobile ? 12 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: isSmallMobile ? 12 : 16),
                    if (isSmallMobile)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Input de quantidade de dias
                          TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Quantos dias?',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              hintText: '0',
                              isDense: true,
                            ),
                            controller: _daysController,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(5),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _daysCount = int.tryParse(value) ?? 0;
                                _calculateDate();
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          // Dropdown tipo de dias
                          DropdownButtonFormField<String>(
                            initialValue: _dayType,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Tipo de dias',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'uteis',
                                child: Text('Úteis'),
                              ),
                              DropdownMenuItem(
                                value: 'totais',
                                child: Text('Corridos'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _dayType = value ?? 'uteis';
                                _calculateDate();
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          // Dropdown direção
                          DropdownButtonFormField<String>(
                            initialValue: _direction,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Direção',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'frente',
                                child: Text('Para frente'),
                              ),
                              DropdownMenuItem(
                                value: 'tras',
                                child: Text('Para trás'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _direction = value ?? 'frente';
                                _calculateDate();
                              });
                            },
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          // Input de quantidade de dias com máscara 99999
                          Expanded(
                            flex: 2,
                            child: TextField(
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Quantos dias?',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                hintText: '0',
                              ),
                              controller: _daysController,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(5),
                              ],
                              onChanged: (value) {
                                // Calcular ao mudar o valor
                                setState(() {
                                  _daysCount = int.tryParse(value) ?? 0;
                                  _calculateDate();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Dropdown tipo de dias
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              initialValue: _dayType,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'uteis',
                                  child: Text('Úteis'),
                                ),
                                DropdownMenuItem(
                                  value: 'totais',
                                  child: Text('Corridos'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _dayType = value ?? 'uteis';
                                  _calculateDate();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Dropdown direção
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              initialValue: _direction,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'frente',
                                  child: Text('Para frente'),
                                ),
                                DropdownMenuItem(
                                  value: 'tras',
                                  child: Text('Para trás'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _direction = value ?? 'frente';
                                  _calculateDate();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Botão fechar
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
