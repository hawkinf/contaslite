import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:finance_app/models/account.dart';
import 'package:finance_app/models/calendar_export_snapshot.dart';
import 'package:finance_app/ui/components/ff_design_system.dart';
import 'package:finance_app/widgets/calendar_export_view.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
  });
  group('CalendarExportSnapshot', () {
    test('has correct agendaTitle format', () {
      final snapshot = _createTestSnapshot(
        selectedDate: DateTime(2026, 1, 15),
      );

      expect(snapshot.agendaTitle, 'Itens do dia 15/01/2026');
    });

    test('hasAgenda returns true when items exist', () {
      final snapshot = _createTestSnapshot(
        agendaItems: [_createTestAgendaItem()],
      );

      expect(snapshot.hasAgenda, true);
    });

    test('hasAgenda returns false when no items', () {
      final snapshot = _createTestSnapshot(
        agendaItems: [],
      );

      expect(snapshot.hasAgenda, false);
    });

    test('monthly mode creates correct snapshot', () {
      final snapshot = _createTestSnapshot(
        mode: FFCalendarViewMode.monthly,
      );

      expect(snapshot.mode, FFCalendarViewMode.monthly);
      expect(snapshot.monthCells.length, 42); // 6 weeks
    });

    test('weekly mode creates correct snapshot', () {
      final snapshot = _createTestSnapshot(
        mode: FFCalendarViewMode.weekly,
      );

      expect(snapshot.mode, FFCalendarViewMode.weekly);
      expect(snapshot.weekDays.length, 7);
    });

    test('yearly mode creates correct snapshot', () {
      final snapshot = _createTestSnapshot(
        mode: FFCalendarViewMode.yearly,
      );

      expect(snapshot.mode, FFCalendarViewMode.yearly);
      expect(snapshot.yearMonths.length, 12);
    });
  });

  group('CalendarDayCellModel', () {
    test('stores day properties correctly', () {
      final cell = CalendarDayCellModel(
        date: DateTime(2026, 1, 15),
        isToday: true,
        isSelected: false,
        isWeekend: false,
        isHoliday: true,
        holidayName: 'Test Holiday',
        isOutsideMonth: false,
        totals: const FFDayTotals(
          totalPagar: 100,
          totalReceber: 200,
          countPagar: 1,
          countReceber: 2,
        ),
      );

      expect(cell.date.day, 15);
      expect(cell.isToday, true);
      expect(cell.isHoliday, true);
      expect(cell.holidayName, 'Test Holiday');
      expect(cell.totals.totalPagar, 100);
    });
  });

  group('CalendarWeekDayModel', () {
    test('stores week day properties correctly', () {
      final weekDay = CalendarWeekDayModel(
        date: DateTime(2026, 1, 15),
        dayName: 'QUA',
        isToday: false,
        isWeekend: false,
        totals: FFDayTotals.empty,
      );

      expect(weekDay.dayName, 'QUA');
      expect(weekDay.isWeekend, false);
    });

    test('weekend flag is set correctly', () {
      final saturday = CalendarWeekDayModel(
        date: DateTime(2026, 1, 17), // Saturday
        dayName: 'SAB',
        isToday: false,
        isWeekend: true,
        totals: FFDayTotals.empty,
      );

      expect(saturday.isWeekend, true);
    });
  });

  group('CalendarMiniMonthModel', () {
    test('stores month properties correctly', () {
      const month = CalendarMiniMonthModel(
        month: 1,
        year: 2026,
        monthName: 'JAN',
        isCurrentMonth: true,
        totals: FFPeriodTotals.empty,
      );

      expect(month.month, 1);
      expect(month.year, 2026);
      expect(month.monthName, 'JAN');
      expect(month.isCurrentMonth, true);
    });
  });

  group('CalendarAgendaItem', () {
    test('stores agenda item properties correctly', () {
      final account = Account(
        id: 1,
        typeId: 1,
        description: 'Test Account',
        value: 150.0,
        dueDay: 15,
        isRecurrent: false,
        payInAdvance: false,
      );

      final item = CalendarAgendaItem(
        account: account,
        effectiveDate: DateTime(2026, 1, 15),
        isRecebimento: false,
        isCard: false,
        isRecurrent: false,
        isPrevisao: false,
        displayValue: 150.0,
        typeName: 'Despesas',
      );

      expect(item.displayValue, 150.0);
      expect(item.isRecebimento, false);
      expect(item.typeName, 'Despesas');
    });

    test('isPrevisao is true for preview items', () {
      final item = _createTestAgendaItem(isPrevisao: true);

      expect(item.isPrevisao, true);
      expect(item.isRecurrent, true); // previsao implies recurrent
    });

    test('isCard flag is set correctly', () {
      final cardItem = _createTestAgendaItem(isCard: true);

      expect(cardItem.isCard, true);
    });
  });

  group('CalendarExportView', () {
    testWidgets('renders period header', (tester) async {
      final snapshot = _createTestSnapshot(
        periodLabel: 'Janeiro 2026',
        mode: FFCalendarViewMode.monthly,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarExportView(snapshot: snapshot),
          ),
        ),
      );

      expect(find.text('Janeiro 2026'), findsOneWidget);
      expect(find.text('Calendário Mensal'), findsOneWidget);
    });

    testWidgets('renders FFCalendarModeSelector', (tester) async {
      final snapshot = _createTestSnapshot(
        mode: FFCalendarViewMode.monthly,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarExportView(snapshot: snapshot),
          ),
        ),
      );

      expect(find.byType(FFCalendarModeSelector), findsOneWidget);
    });

    testWidgets('renders FFCalendarTotalsBar', (tester) async {
      final snapshot = _createTestSnapshot();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarExportView(snapshot: snapshot),
          ),
        ),
      );

      expect(find.byType(FFCalendarTotalsBar), findsOneWidget);
    });

    testWidgets('renders FFWeekDayCard in weekly mode', (tester) async {
      final snapshot = _createTestSnapshot(
        mode: FFCalendarViewMode.weekly,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarExportView(snapshot: snapshot),
          ),
        ),
      );

      // Should render 7 week day cards
      expect(find.byType(FFWeekDayCard), findsNWidgets(7));
    });

    testWidgets('renders FFDayTile in monthly mode', (tester) async {
      final snapshot = _createTestSnapshot(
        mode: FFCalendarViewMode.monthly,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarExportView(snapshot: snapshot),
          ),
        ),
      );

      // Should render 42 day tiles (6 weeks)
      expect(find.byType(FFDayTile), findsNWidgets(42));
    });

    testWidgets('renders FFMiniMonthCard in yearly mode', (tester) async {
      final snapshot = _createTestSnapshot(
        mode: FFCalendarViewMode.yearly,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarExportView(snapshot: snapshot),
          ),
        ),
      );

      // Should render 12 mini month cards
      expect(find.byType(FFMiniMonthCard), findsNWidgets(12));
    });

    testWidgets('renders FFEmptyState when no agenda items', (tester) async {
      final snapshot = _createTestSnapshot(
        agendaItems: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarExportView(snapshot: snapshot),
          ),
        ),
      );

      expect(find.byType(FFEmptyState), findsOneWidget);
      expect(find.text('Nenhum lançamento para este dia.'), findsOneWidget);
    });

    testWidgets('renders FFAccountItemCard when agenda has items', (tester) async {
      final snapshot = _createTestSnapshot(
        agendaItems: [
          _createTestAgendaItem(),
          _createTestAgendaItem(),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarExportView(snapshot: snapshot),
          ),
        ),
      );

      expect(find.byType(FFAccountItemCard), findsNWidgets(2));
    });

    testWidgets('renders FFDateGroupHeader', (tester) async {
      final snapshot = _createTestSnapshot();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarExportView(snapshot: snapshot),
          ),
        ),
      );

      expect(find.byType(FFDateGroupHeader), findsOneWidget);
    });
  });
}

/// Helper to create test snapshot
CalendarExportSnapshot _createTestSnapshot({
  FFCalendarViewMode mode = FFCalendarViewMode.monthly,
  DateTime? selectedDate,
  String periodLabel = 'Janeiro 2026',
  List<CalendarAgendaItem>? agendaItems,
}) {
  final anchor = DateTime(2026, 1, 15);
  final selected = selectedDate ?? anchor;

  // Generate 42 month cells
  final monthCells = List.generate(42, (i) {
    final date = DateTime(2026, 1, 1).add(Duration(days: i - 4)); // Start before month
    return CalendarDayCellModel(
      date: date,
      isToday: i == 18, // Jan 15
      isSelected: DateUtils.isSameDay(date, selected),
      isWeekend: date.weekday == DateTime.saturday || date.weekday == DateTime.sunday,
      isHoliday: false,
      isOutsideMonth: date.month != 1,
      totals: FFDayTotals.empty,
    );
  });

  // Generate 7 week days
  final weekDays = List.generate(7, (i) {
    final date = DateTime(2026, 1, 11 + i); // Sun-Sat
    return CalendarWeekDayModel(
      date: date,
      dayName: ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB'][i],
      isToday: i == 4, // Thursday
      isWeekend: i == 0 || i == 6,
      totals: FFDayTotals.empty,
    );
  });

  // Generate 12 months
  final yearMonths = List.generate(12, (i) {
    return CalendarMiniMonthModel(
      month: i + 1,
      year: 2026,
      monthName: ['JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN',
                  'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'][i],
      isCurrentMonth: i == 0, // January
      totals: FFPeriodTotals.empty,
    );
  });

  return CalendarExportSnapshot(
    mode: mode,
    density: FFCalendarDensity.regular,
    anchorDate: anchor,
    selectedDate: selected,
    periodLabel: periodLabel,
    periodTotals: const FFPeriodTotals(
      totalPagar: 1000,
      totalReceber: 2000,
      countPagar: 5,
      countReceber: 3,
    ),
    monthCells: monthCells,
    weekDays: weekDays,
    yearMonths: yearMonths,
    agendaItems: agendaItems ?? [_createTestAgendaItem()],
    typeNames: const {},
  );
}

/// Helper to create test agenda item
CalendarAgendaItem _createTestAgendaItem({
  bool isPrevisao = false,
  bool isCard = false,
}) {
  return CalendarAgendaItem(
    account: Account(
      id: isPrevisao ? null : 1,
      typeId: 1,
      description: 'Test Account',
      value: 150.0,
      dueDay: 15,
      isRecurrent: isPrevisao,
      payInAdvance: false,
    ),
    effectiveDate: DateTime(2026, 1, 15),
    isRecebimento: false,
    isCard: isCard,
    isRecurrent: isPrevisao,
    isPrevisao: isPrevisao,
    displayValue: 150.0,
    typeName: 'Despesas',
  );
}
