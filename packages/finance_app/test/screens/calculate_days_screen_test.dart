import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:finance_app/screens/calculate_days_screen.dart';
import 'package:finance_app/ui/components/ff_design_system.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
  });

  Widget buildTestWidget({
    Size size = const Size(1366, 768),
    Brightness brightness = Brightness.light,
  }) {
    return MaterialApp(
      theme: ThemeData(
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: brightness,
        ),
      ),
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: const CalculateDaysScreen(),
      ),
    );
  }

  group('CalculateDaysScreen Layout - No Overflow', () {
    testWidgets('renders without overflow in 1366x768', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(size: const Size(1366, 768)));
      await tester.pumpAndSettle();

      // Should not have any overflow errors
      expect(tester.takeException(), isNull);

      // Main components visible
      expect(find.text('Calcular Dias'), findsOneWidget);
      expect(find.text('Referência'), findsOneWidget);
      expect(find.text('Calculada'), findsOneWidget);

      // Action bar visible with "Calcular dias" and "Ajustar"
      expect(find.text('Calcular dias'), findsOneWidget);
      expect(find.text('Ajustar'), findsOneWidget);
    });

    testWidgets('renders without overflow in 1280x720', (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(size: const Size(1280, 720)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Calcular dias'), findsOneWidget);
      expect(find.text('Ajustar'), findsOneWidget);
    });

    testWidgets('renders without overflow in 1024x600', (tester) async {
      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(size: const Size(1024, 600)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Calcular dias'), findsOneWidget);
      expect(find.text('Ajustar'), findsOneWidget);
    });

    testWidgets('renders without overflow in small 800x600', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(size: const Size(800, 600)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders calendars side by side', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final referenceText = find.text('Referência');
      final calculatedText = find.text('Calculada');

      expect(referenceText, findsOneWidget);
      expect(calculatedText, findsOneWidget);

      // Verify side by side
      final referenceBox = tester.getRect(referenceText);
      final calculatedBox = tester.getRect(calculatedText);
      expect((referenceBox.top - calculatedBox.top).abs(), lessThan(10));
      expect(calculatedBox.left, greaterThan(referenceBox.left));
    });

    testWidgets('action bar is always visible at bottom', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final ajustarButton = find.text('Ajustar');
      expect(ajustarButton, findsOneWidget);

      final ajustarRect = tester.getRect(ajustarButton);
      expect(ajustarRect.bottom, lessThan(768));
    });
  });

  group('CalculateDaysScreen Action Bar', () {
    testWidgets('shows current calculation parameters', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Default values shown in action bar
      expect(find.textContaining('30'), findsWidgets); // days count
      expect(find.textContaining('úteis'), findsWidgets); // day type
    });

    testWidgets('opens modal when tapping Ajustar', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap the "Ajustar" button
      await tester.tap(find.text('Ajustar'));
      await tester.pumpAndSettle();

      // Modal should be open with title "Calcular Dias"
      expect(find.text('Calcular Dias'), findsNWidgets(2)); // screen title + modal title
      expect(find.text('Quantos dias?'), findsOneWidget);
      expect(find.text('Tipo de dias'), findsOneWidget);
      expect(find.text('Direção'), findsOneWidget);
      expect(find.text('Aplicar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('opens modal when tapping action bar', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap the action bar (text "Calcular dias")
      await tester.tap(find.text('Calcular dias'));
      await tester.pumpAndSettle();

      // Modal should be open
      expect(find.text('Quantos dias?'), findsOneWidget);
    });
  });

  group('CalculateDaysScreen Modal', () {
    testWidgets('modal inputs appear correctly', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajustar'));
      await tester.pumpAndSettle();

      // Number input with +/- buttons
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);

      // Segmented buttons for type
      expect(find.text('Úteis'), findsOneWidget);
      expect(find.text('Corridos'), findsOneWidget);

      // Segmented buttons for direction
      expect(find.text('Frente'), findsOneWidget);
      expect(find.text('Trás'), findsOneWidget);
    });

    testWidgets('modal closes on Cancel', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajustar'));
      await tester.pumpAndSettle();

      expect(find.text('Quantos dias?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // Modal should be closed
      expect(find.text('Quantos dias?'), findsNothing);
    });

    testWidgets('modal closes on Apply', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajustar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      // Modal should be closed
      expect(find.text('Quantos dias?'), findsNothing);
    });
  });

  group('CalculateDaysScreen Functionality', () {
    testWidgets('header shows city and stats', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('dias'), findsOneWidget);
      expect(find.text('úteis'), findsWidgets);
    });

    testWidgets('action buttons are present in app bar', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byTooltip('Resetar para Hoje'), findsOneWidget);
      expect(find.byTooltip('Inverter Datas'), findsOneWidget);
      expect(find.byTooltip('Copiar Resultado'), findsOneWidget);
    });

    testWidgets('copy button on calculated card', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Copy icon only on calculated card
      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('dark mode renders correctly', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(brightness: Brightness.dark));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Calcular Dias'), findsOneWidget);
    });
  });

  group('FFCompactCalendar', () {
    testWidgets('shows weekday headers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: FFCompactCalendar(
                focusedDate: DateTime(2026, 1, 15),
                selectedDate: DateTime(2026, 1, 15),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('D'), findsOneWidget);
      expect(find.text('S'), findsNWidgets(3));
      expect(find.text('T'), findsOneWidget);
      expect(find.text('Q'), findsNWidgets(2));
    });

    testWidgets('shows month navigation', (tester) async {
      DateTime? changedDate;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: FFCompactCalendar(
                focusedDate: DateTime(2026, 1, 15),
                selectedDate: DateTime(2026, 1, 15),
                onPageChanged: (date) => changedDate = date,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nextButton = find.byIcon(Icons.chevron_right);
      expect(nextButton, findsOneWidget);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      expect(changedDate?.month, 2);
    });

    testWidgets('supports different densities', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: FFCompactCalendar(
                    focusedDate: DateTime(2026, 1, 15),
                    selectedDate: DateTime(2026, 1, 15),
                    density: FFCompactCalendarDensity.extraCompact,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(FFCompactCalendar), findsOneWidget);
    });
  });
}
