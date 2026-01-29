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


  Widget _buildCalendarPanel(DateTime date, {bool isReference = false}) {
    final firstDay = DateTime(date.year, date.month, 1);
    final lastDay = DateTime(date.year, date.month + 1, 0);
    final firstDayOfWeek = firstDay.weekday % 7; // 0=domingo, 1=segunda, ..., 6=sábado
    final holidays = _getHolidayDays();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final monthName = DateFormat('MMMM', 'pt_BR').format(date);
    final year = date.year;
    final monthLabel = toBeginningOfSentenceCase(monthName);
    final title = isReference ? 'Data Referência' : 'Data Calculada';

    return Card(
      elevation: 1,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            // Seletor de Mês apenas (ANO é exibido mas não navegável)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Seta esquerda do Mês
                IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(Icons.chevron_left),
                  color: colorScheme.onSurfaceVariant,
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
                      monthLabel,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      year.toString(),
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                // Seta direita do Mês
                IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  icon: const Icon(Icons.chevron_right),
                  color: colorScheme.onSurfaceVariant,
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
                            style: textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
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

                final isWeekend = currentDate.weekday == DateTime.saturday ||
                    currentDate.weekday == DateTime.sunday;

                Color bgColor = colorScheme.surface;
                Color textColor = colorScheme.onSurface;
                Color borderColor = colorScheme.outlineVariant.withValues(alpha: 0.55);
                double borderWidth = 1;

                if (isWeekend) {
                  bgColor = colorScheme.surfaceContainerLow;
                }

                if (isReferenceSelected) {
                  bgColor = colorScheme.primary;
                  textColor = colorScheme.onPrimary;
                  borderColor = colorScheme.primary;
                } else if (isCalculated) {
                  bgColor = colorScheme.secondaryContainer;
                  textColor = colorScheme.onSecondaryContainer;
                  borderColor = colorScheme.secondaryContainer;
                } else if (isToday) {
                  borderColor = colorScheme.primary;
                  borderWidth = 1.5;
                }

                final showTodayDot = isToday && !isReferenceSelected && !isCalculated;
                final showHolidayDot = isHoliday && !isReferenceSelected && !isCalculated;

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
                        color: borderColor,
                        width: borderWidth,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            day.toString(),
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                        if (showTodayDot || showHolidayDot)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showTodayDot)
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  if (showTodayDot && showHolidayDot)
                                    const SizedBox(width: 4),
                                  if (showHolidayDot)
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: colorScheme.error,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (!isReference) ...[
              const SizedBox(height: 12),
              _buildResultCard(date),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(DateTime date) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final formattedDate = DateFormat('dd/MM/yyyy', 'pt_BR').format(date);

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formattedDate,
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getDayOfWeekName(date),
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copiar',
              icon: const Icon(Icons.copy),
              iconSize: 18,
              color: colorScheme.onSurfaceVariant,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: formattedDate));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copiado')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String labelText, {String? hintText}) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      isDense: true,
      filled: true,
      fillColor: colorScheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;
    final isSmallMobile = screenWidth < 600;
    final isWide = screenWidth >= 1100;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = isSmallMobile ? 12.0 : 20.0;

    final headerSection = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cidade',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _selectedCityName,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(
              tooltip: 'Reiniciar para hoje',
              icon: const Icon(Icons.refresh),
              iconSize: 20,
              color: colorScheme.onSurfaceVariant,
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
      ],
    );

    final calendarsSection = !isMobile
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 400),
                  child: _buildCalendarPanel(_referenceDate, isReference: true),
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 400),
                  child: _buildCalendarPanel(_calculatedDate, isReference: false),
                ),
              ),
            ],
          )
        : Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 400),
                child: _buildCalendarPanel(_referenceDate, isReference: true),
              ),
              SizedBox(height: spacing),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 400),
                child: _buildCalendarPanel(_calculatedDate, isReference: false),
              ),
            ],
          );

    return Container(
      constraints: BoxConstraints(
        maxWidth: isSmallMobile ? 420 : (isMobile ? 560 : 1200),
        maxHeight: isSmallMobile ? 1000 : (isMobile ? 800 : 700),
      ),
      padding: EdgeInsets.all(isSmallMobile ? 16 : 24),
      color: colorScheme.surface,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: headerSection),
                  SizedBox(width: spacing),
                  Expanded(flex: 2, child: calendarsSection),
                ],
              )
            else ...[
              headerSection,
              SizedBox(height: spacing),
              calendarsSection,
            ],

            SizedBox(height: spacing),

            // Seção de cálculo
            Card(
              elevation: 0,
              color: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: Padding(
                padding: EdgeInsets.all(isSmallMobile ? 16 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calcular dias',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
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
                            decoration: _buildInputDecoration('Quantos dias?', hintText: '0'),
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
                            decoration: _buildInputDecoration('Tipo de dias'),
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
                            decoration: _buildInputDecoration('Direção'),
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
                              decoration: _buildInputDecoration('Quantos dias?', hintText: '0'),
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
                              isExpanded: true,
                              decoration: _buildInputDecoration('Tipo de dias'),
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
                              isExpanded: true,
                              decoration: _buildInputDecoration('Direção'),
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

            SizedBox(height: spacing),

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
