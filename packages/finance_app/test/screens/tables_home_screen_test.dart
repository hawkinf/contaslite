import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_app/screens/tables_home_screen.dart';
import 'package:finance_app/ui/components/ff_design_system.dart';

void main() {
  Widget buildTestWidget({
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
      home: const TablesHomeScreen(),
    );
  }

  group('TablesHomeScreen Layout', () {
    testWidgets('renders without overflow', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('displays section title "Cadastros"', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('CADASTROS'), findsOneWidget);
    });

    testWidgets('displays section subtitle', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Gerencie categorias, bancos e formas de pagamento'), findsOneWidget);
    });
  });

  group('TablesHomeScreen Menu Items', () {
    testWidgets('displays 4 menu items', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(FFMenuActionCard), findsNWidgets(4));
    });

    testWidgets('displays Contas a Pagar option', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Contas a Pagar'), findsOneWidget);
      expect(find.text('Categorias para despesas e pagamentos'), findsOneWidget);
    });

    testWidgets('displays Contas a Receber option', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Contas a Receber'), findsOneWidget);
      expect(find.text('Categorias para receitas e recebimentos'), findsOneWidget);
    });

    testWidgets('displays Contas Bancárias option', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Contas Bancárias'), findsOneWidget);
      expect(find.text('Gerencie suas contas em bancos'), findsOneWidget);
    });

    testWidgets('displays Formas de Pagamento option', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Formas de Pagamento'), findsOneWidget);
      expect(find.text('Cartão, boleto, PIX, dinheiro, etc.'), findsOneWidget);
    });

    testWidgets('displays correct icons', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.payments_outlined), findsOneWidget);
      expect(find.byIcon(Icons.request_quote_outlined), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_outlined), findsOneWidget);
      expect(find.byIcon(Icons.payment_outlined), findsOneWidget);
    });

    testWidgets('displays chevron on all items', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right), findsNWidgets(4));
    });
  });

  group('TablesHomeScreen Dark Mode', () {
    testWidgets('renders correctly in dark mode', (tester) async {
      await tester.pumpWidget(buildTestWidget(brightness: Brightness.dark));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Contas a Pagar'), findsOneWidget);
      expect(find.text('Contas a Receber'), findsOneWidget);
      expect(find.text('Contas Bancárias'), findsOneWidget);
      expect(find.text('Formas de Pagamento'), findsOneWidget);
    });
  });

  group('TablesHomeScreen Responsiveness', () {
    testWidgets('renders without overflow in small screen', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(FFMenuActionCard), findsNWidgets(4));
    });

    testWidgets('renders without overflow in large screen', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
