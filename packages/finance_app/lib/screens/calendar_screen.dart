import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:brasil_fields/brasil_fields.dart';
import '../database/db_helper.dart';
import '../models/account.dart';
import '../services/holiday_service.dart';
import '../services/prefs_service.dart';
import '../utils/app_colors.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, List<Account>> _events = {};
  List<Account> _selectedEvents = [];
  bool _isLoading = true;
  Set<int> _recebimentosTypeIds = {}; // IDs dos tipos de Recebimentos

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  /// Converte data para chave string no formato "yyyy-MM-dd"
  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Normaliza o ano para 4 dígitos (ex: 26 -> 2026)
  int _normalizeYear(int? year) {
    if (year == null) return DateTime.now().year;
    if (year < 100) {
      // Ano com 2 dígitos - assumir século 21
      return 2000 + year;
    }
    return year;
  }

  /// Calcula a data efetiva de pagamento, ajustando para dia útil
  /// Retorna em UTC para compatibilidade com TableCalendar
  DateTime _resolveEffectiveDate(Account account, DateTime fallbackMonth) {
    final year = _normalizeYear(account.year ?? fallbackMonth.year);
    final month = account.month ?? fallbackMonth.month;
    int day = account.dueDay;
    int maxDays = DateUtils.getDaysInMonth(year, month);
    if (day > maxDays) day = maxDays;

    // Usar data local para cálculos de fim de semana/feriado
    DateTime effectiveDate = DateTime(year, month, day);
    final city = PrefsService.cityNotifier.value;

    // Verificar se é fim de semana ou feriado
    bool needsAdjustment = HolidayService.isWeekend(effectiveDate) ||
        HolidayService.isHoliday(effectiveDate, city);

    if (needsAdjustment) {
      if (account.payInAdvance) {
        // Pagar antecipado: mover para dia útil ANTERIOR
        while (HolidayService.isWeekend(effectiveDate) ||
            HolidayService.isHoliday(effectiveDate, city)) {
          effectiveDate = effectiveDate.subtract(const Duration(days: 1));
        }
      } else {
        // Pagar no próximo dia útil: mover para dia útil POSTERIOR
        while (HolidayService.isWeekend(effectiveDate) ||
            HolidayService.isHoliday(effectiveDate, city)) {
          effectiveDate = effectiveDate.add(const Duration(days: 1));
        }
      }
    }

    // Retornar em UTC para compatibilidade com TableCalendar
    return DateTime.utc(effectiveDate.year, effectiveDate.month, effectiveDate.day);
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);

    try {
      final allAccounts = await DatabaseHelper.instance.readAllAccountsRaw();
      final cards = await DatabaseHelper.instance.readAllCards();
      final types = await DatabaseHelper.instance.readAllTypes();

      // Identificar IDs dos tipos de Recebimentos dinamicamente
      _recebimentosTypeIds = types
          .where((t) => t.name.trim().toLowerCase() == 'recebimentos')
          .map((t) => t.id!)
          .toSet();

      // Definir range de 6 meses antes e 6 meses depois
      final now = DateTime.now();
      final startMonth = DateTime(now.year, now.month - 6, 1);
      final endMonth = DateTime(now.year, now.month + 6 + 1, 0);

      final Map<String, List<Account>> events = {};

      // Separar contas normais e recorrentes
      final normalAccounts = allAccounts.where((a) =>
          a.cardBrand == null && !a.isRecurrent && a.recurrenceId == null).toList();
      final recurrents = allAccounts.where((a) =>
          a.cardBrand == null && a.isRecurrent && a.recurrenceId == null).toList();
      final launchedInstances = allAccounts.where((a) =>
          a.cardBrand == null && a.recurrenceId != null).toList();

      // Índice de lançamentos
      final launchedIndex = <int, Set<String>>{};
      for (var inst in launchedInstances) {
        if (inst.recurrenceId != null && inst.month != null && inst.year != null) {
          launchedIndex.putIfAbsent(inst.recurrenceId!, () => <String>{});
          launchedIndex[inst.recurrenceId!]!.add('${inst.recurrenceId}_${inst.year}_${inst.month}');
        }
      }

      // Processar contas normais
      for (var account in normalAccounts) {
        if (account.month != null && account.year != null) {
          final normalizedYear = _normalizeYear(account.year);
          final effectiveDate = _resolveEffectiveDate(account, DateTime(normalizedYear, account.month!));
          final key = _dateKey(effectiveDate);
          events.putIfAbsent(key, () => []).add(account);
        }
      }

      // Processar instâncias lançadas de recorrências
      for (var account in launchedInstances) {
        if (account.month != null && account.year != null) {
          final normalizedYear = _normalizeYear(account.year);
          final effectiveDate = _resolveEffectiveDate(account, DateTime(normalizedYear, account.month!));
          final key = _dateKey(effectiveDate);
          events.putIfAbsent(key, () => []).add(account);
        }
      }

      // Processar recorrências não lançadas (previsões)
      DateTime current = DateTime(startMonth.year, startMonth.month, 1);
      while (current.isBefore(endMonth)) {
        for (var rec in recurrents) {
          final launchKey = '${rec.id}_${current.year}_${current.month}';
          final wasLaunched = launchedIndex[rec.id]?.contains(launchKey) ?? false;
          if (!wasLaunched) {
            final previewAccount = Account(
              id: null,
              typeId: rec.typeId,
              description: rec.description,
              value: rec.value,
              estimatedValue: rec.estimatedValue,
              dueDay: rec.dueDay,
              isRecurrent: true,
              payInAdvance: rec.payInAdvance,
              month: current.month,
              year: current.year,
              recurrenceId: rec.id,
            );
            final effectiveDate = _resolveEffectiveDate(previewAccount, current);
            final key = _dateKey(effectiveDate);
            events.putIfAbsent(key, () => []).add(previewAccount);
          }
        }
        current = DateTime(current.year, current.month + 1, 1);
      }

      // Processar cartões de crédito
      current = DateTime(startMonth.year, startMonth.month, 1);
      while (current.isBefore(endMonth)) {
        for (var card in cards) {
          final expenses = await DatabaseHelper.instance
              .getCardExpensesForMonth(card.id!, current.month, current.year);
          if (expenses.isNotEmpty) {
            double total = expenses.fold(0.0, (sum, e) => sum + e.value);
            final cardAccount = Account(
              id: card.id,
              typeId: card.typeId,
              description: 'Fatura: ${card.cardBank} - ${card.cardBrand}',
              value: total,
              dueDay: card.dueDay,
              isRecurrent: false,
              payInAdvance: card.payInAdvance,
              month: current.month,
              year: current.year,
              cardBrand: card.cardBrand,
              cardBank: card.cardBank,
              cardColor: card.cardColor,
            );
            final effectiveDate = _resolveEffectiveDate(cardAccount, current);
            final key = _dateKey(effectiveDate);
            events.putIfAbsent(key, () => []).add(cardAccount);
          }
        }
        current = DateTime(current.year, current.month + 1, 1);
      }

      if (mounted) {
        setState(() {
          _events = events;
          _selectedEvents = _getEventsForDay(_selectedDay ?? _focusedDay);
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('❌ Erro ao carregar eventos: $e');
      debugPrint('Stack: $stack');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Account> _getEventsForDay(DateTime day) {
    // Normalizar a data para local (ignorar timezone)
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final key = _dateKey(normalizedDay);
    return _events[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    // Largura de cada célula do calendário (7 colunas)
    final cellWidth = screenWidth / 7;
    // Fonte GRANDE para dias da semana - 70% da largura da célula
    final dayOfWeekFontSize = cellWidth * 0.30; // Fonte grande para DOM, SEG, etc
    final dayFontSize = cellWidth * 0.40; // Número do dia grande

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendário'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEvents,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                TableCalendar<Account>(
                  locale: 'pt_BR',
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  eventLoader: _getEventsForDay,
                  startingDayOfWeek: StartingDayOfWeek.sunday,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                      _selectedEvents = _getEventsForDay(selectedDay);
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                  daysOfWeekHeight: 50,
                  rowHeight: 60,
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                      fontSize: dayOfWeekFontSize,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    weekendStyle: TextStyle(
                      fontSize: dayOfWeekFontSize,
                      fontWeight: FontWeight.w900,
                      color: Colors.red.shade600,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    markersMaxCount: 3,
                    defaultTextStyle: TextStyle(fontSize: dayFontSize),
                    weekendTextStyle: TextStyle(
                      fontSize: dayFontSize,
                      color: Colors.red.shade400,
                    ),
                    outsideTextStyle: TextStyle(
                      fontSize: dayFontSize,
                      color: Colors.grey.shade400,
                    ),
                    todayDecoration: BoxDecoration(
                      color: isDark ? Colors.blue.shade700 : Colors.blue.shade300,
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: TextStyle(
                      fontSize: dayFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: isDark ? AppColors.successDark : Colors.green.shade500,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: TextStyle(
                      fontSize: dayFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isEmpty) return null;

                      // Calcular total do dia
                      double totalPagar = 0;
                      double totalReceber = 0;
                      for (var event in events) {
                        // Verificar se é recebimento pelo ID do tipo
                        if (_recebimentosTypeIds.contains(event.typeId)) {
                          totalReceber += event.value;
                        } else {
                          totalPagar += event.value;
                        }
                      }

                      // Retornar marcador simples
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (totalPagar > 0)
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: Colors.red.shade600,
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (totalReceber > 0)
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: Colors.green.shade600,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                    formatButtonShowsNext: false,
                    titleTextStyle: TextStyle(
                      fontSize: screenWidth / 22,
                      fontWeight: FontWeight.bold,
                    ),
                    formatButtonDecoration: BoxDecoration(
                      border: Border.all(color: isDark ? Colors.white54 : Colors.black54),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const Divider(height: 1),
                // Resumo do dia selecionado
                if (_selectedEvents.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('dd/MM/yyyy (EEEE)', 'pt_BR').format(_selectedDay!),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_selectedEvents.length} ${_selectedEvents.length == 1 ? 'conta' : 'contas'}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                // Lista de eventos do dia
                Expanded(
                  child: _selectedEvents.isEmpty
                      ? Center(
                          child: Text(
                            'Nenhuma conta neste dia',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _selectedEvents.length,
                          itemBuilder: (context, index) {
                            final account = _selectedEvents[index];
                            return _buildEventTile(account);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEventTile(Account account) {
    final isCard = account.cardBrand != null;
    final isRecurrent = account.isRecurrent || account.recurrenceId != null;
    final isPrevisao = isRecurrent && account.id == null;
    final isRecebimento = _recebimentosTypeIds.contains(account.typeId);

    Color valueColor;
    if (isRecebimento) {
      valueColor = AppColors.successDark;
    } else if (isCard) {
      valueColor = AppColors.cardPurple;
    } else {
      valueColor = Colors.red.shade700;
    }

    IconData leadingIcon;
    Color iconBgColor;
    if (isCard) {
      leadingIcon = Icons.credit_card;
      iconBgColor = account.cardColor != null
          ? Color(account.cardColor!)
          : Colors.purple.shade100;
    } else if (isRecebimento) {
      leadingIcon = Icons.arrow_downward;
      iconBgColor = Colors.green.shade100;
    } else {
      leadingIcon = Icons.arrow_upward;
      iconBgColor = Colors.red.shade100;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconBgColor,
          child: Icon(leadingIcon,
              color: isCard && account.cardColor != null
                  ? Colors.white
                  : (isRecebimento ? AppColors.successDark : Colors.red.shade700),
              size: 20),
        ),
        title: Text(
          account.description,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            if (isPrevisao)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PREVISÃO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              )
            else if (isRecurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'LANÇADO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            if (isCard)
              Text(
                '${account.cardBank} - ${account.cardBrand}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
          ],
        ),
        trailing: Text(
          UtilBrasilFields.obterReal(account.value),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: valueColor,
          ),
        ),
      ),
    );
  }
}
