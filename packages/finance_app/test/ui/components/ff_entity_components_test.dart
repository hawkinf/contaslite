import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_app/ui/components/ff_design_system.dart';

/// Testes para os componentes de Entidade do Design System.
///
/// Inclui testes para:
/// - FFEntityDensity
/// - FFEntityActionsBar
/// - FFEntityListItem (nova versão)
/// - FFMenuActionCard
/// - FFEntityPageScaffold
void main() {
  // =============================================
  // FFEntityDensity TESTS
  // =============================================

  group('FFEntityDensity', () {
    test('compact has smaller values than regular', () {
      expect(FFEntityDensity.compact.listItemHeight, lessThan(FFEntityDensity.regular.listItemHeight));
      expect(FFEntityDensity.compact.titleFontSize, lessThan(FFEntityDensity.regular.titleFontSize));
      expect(FFEntityDensity.compact.iconSize, lessThan(FFEntityDensity.regular.iconSize));
    });

    test('regular has smaller values than desktop', () {
      expect(FFEntityDensity.regular.listItemHeight, lessThan(FFEntityDensity.desktop.listItemHeight));
      expect(FFEntityDensity.regular.titleFontSize, lessThan(FFEntityDensity.desktop.titleFontSize));
      expect(FFEntityDensity.regular.iconSize, lessThan(FFEntityDensity.desktop.iconSize));
    });

    test('compact has correct listItemHeight', () {
      expect(FFEntityDensity.compact.listItemHeight, 48.0);
    });

    test('regular has correct listItemHeight', () {
      expect(FFEntityDensity.regular.listItemHeight, 56.0);
    });

    test('desktop has correct listItemHeight', () {
      expect(FFEntityDensity.desktop.listItemHeight, 64.0);
    });

    test('buttonHeight varies by density', () {
      expect(FFEntityDensity.compact.buttonHeight, 36.0);
      expect(FFEntityDensity.regular.buttonHeight, 40.0);
      expect(FFEntityDensity.desktop.buttonHeight, 48.0);
    });
  });

  group('FFEntityDensityHelper', () {
    test('fromWidth returns compact for small screens', () {
      expect(FFEntityDensityHelper.fromWidth(400), FFEntityDensity.compact);
      expect(FFEntityDensityHelper.fromWidth(599), FFEntityDensity.compact);
    });

    test('fromWidth returns regular for medium screens', () {
      expect(FFEntityDensityHelper.fromWidth(600), FFEntityDensity.regular);
      expect(FFEntityDensityHelper.fromWidth(1000), FFEntityDensity.regular);
      expect(FFEntityDensityHelper.fromWidth(1199), FFEntityDensity.regular);
    });

    test('fromWidth returns desktop for large screens', () {
      expect(FFEntityDensityHelper.fromWidth(1200), FFEntityDensity.desktop);
      expect(FFEntityDensityHelper.fromWidth(1920), FFEntityDensity.desktop);
    });

    testWidgets('fromContext detects screen width', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      FFEntityDensity? detectedDensity;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              detectedDensity = FFEntityDensityHelper.fromContext(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(detectedDensity, FFEntityDensity.desktop);
    });
  });

  // =============================================
  // FFEntityActionsBar TESTS
  // =============================================

  group('FFEntityActionsBar', () {
    testWidgets('renders primary action button', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFEntityActionsBar(
              primaryAction: FFEntityAction(
                label: 'Novo Item',
                icon: Icons.add,
                onPressed: () => pressed = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Novo Item'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);

      await tester.tap(find.text('Novo Item'));
      await tester.pump();

      expect(pressed, isTrue);
    });

    testWidgets('renders secondary action button', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFEntityActionsBar(
              secondaryAction: FFEntityAction(
                label: 'Popular',
                icon: Icons.auto_awesome,
                onPressed: () => pressed = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Popular'), findsOneWidget);

      await tester.tap(find.text('Popular'));
      await tester.pump();

      expect(pressed, isTrue);
    });

    testWidgets('renders both primary and secondary actions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFEntityActionsBar(
              primaryAction: FFEntityAction(
                label: 'Criar',
                icon: Icons.add,
                onPressed: () {},
              ),
              secondaryAction: FFEntityAction(
                label: 'Popular',
                icon: Icons.auto_awesome,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Criar'), findsOneWidget);
      expect(find.text('Popular'), findsOneWidget);
    });

    testWidgets('shows loading indicator when isLoading is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFEntityActionsBar(
              primaryAction: FFEntityAction(
                label: 'Loading',
                icon: Icons.add,
                onPressed: () {},
                isLoading: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('respects density parameter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFEntityActionsBar(
              density: FFEntityDensity.desktop,
              primaryAction: FFEntityAction(
                label: 'Test',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FFEntityActionsBar), findsOneWidget);
    });

    testWidgets('renders without overflow in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: FFEntityActionsBar(
              primaryAction: FFEntityAction(
                label: 'Dark Mode Action',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Dark Mode Action'), findsOneWidget);
    });
  });

  group('FFEntityAction', () {
    test('default isLoading is false', () {
      const action = FFEntityAction(label: 'Test');
      expect(action.isLoading, isFalse);
    });

    test('default useTonal is true', () {
      const action = FFEntityAction(label: 'Test');
      expect(action.useTonal, isTrue);
    });

    test('accepts all parameters', () {
      const action = FFEntityAction(
        label: 'Test',
        icon: Icons.add,
        isLoading: true,
        useTonal: false,
      );

      expect(action.label, 'Test');
      expect(action.icon, Icons.add);
      expect(action.isLoading, isTrue);
      expect(action.useTonal, isFalse);
    });
  });

  // =============================================
  // FFEntityListItem TESTS (new entity folder version)
  // =============================================

  group('FFEntityListItem (entity folder)', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFEntityListItem(
              title: 'Item Title',
            ),
          ),
        ),
      );

      expect(find.text('Item Title'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFEntityListItem(
              title: 'Title',
              subtitle: 'Subtitle',
            ),
          ),
        ),
      );

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Subtitle'), findsOneWidget);
    });

    testWidgets('shows edit button when onEdit provided', (tester) async {
      bool edited = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFEntityListItem(
              title: 'Item',
              onEdit: () => edited = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pump();

      expect(edited, isTrue);
    });

    testWidgets('shows delete button when onDelete provided', (tester) async {
      bool deleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFEntityListItem(
              title: 'Item',
              onDelete: () => deleted = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      expect(deleted, isTrue);
    });

    testWidgets('uses FFEntityDensity for sizing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFEntityListItem(
              title: 'Compact Item',
              density: FFEntityDensity.compact,
            ),
          ),
        ),
      );

      // Find the container and check its height
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(FFEntityListItem),
          matching: find.byType(Container),
        ).first,
      );

      expect(container.constraints?.maxHeight, FFEntityDensity.compact.listItemHeight);
    });

    testWidgets('category factory renders emoji', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFEntityListItem.category(
              emoji: '🍔',
              name: 'Alimentação',
              onEdit: () {},
            ),
          ),
        ),
      );

      expect(find.text('🍔'), findsOneWidget);
      expect(find.text('Alimentação'), findsOneWidget);
    });

    testWidgets('paymentMethod factory renders icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFEntityListItem.paymentMethod(
              icon: Icons.credit_card,
              name: 'Cartão',
              onEdit: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.credit_card), findsOneWidget);
      expect(find.text('Cartão'), findsOneWidget);
    });

    testWidgets('bankAccount factory renders correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFEntityListItem.bankAccount(
              emoji: '🏦',
              name: 'Conta Principal',
              bankName: 'Banco do Brasil',
              onEdit: () {},
            ),
          ),
        ),
      );

      expect(find.text('🏦'), findsOneWidget);
      expect(find.text('Conta Principal'), findsOneWidget);
      expect(find.text('Banco do Brasil'), findsOneWidget);
    });

    testWidgets('renders in dark mode without overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: FFEntityListItem(
              title: 'Dark Mode Item',
              subtitle: 'Test subtitle',
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Dark Mode Item'), findsOneWidget);
    });
  });

  // =============================================
  // FFMenuActionCard TESTS
  // =============================================

  group('FFMenuActionCard', () {
    testWidgets('renders icon and title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFMenuActionCard(
              icon: Icons.category_outlined,
              title: 'Categorias',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.category_outlined), findsOneWidget);
      expect(find.text('Categorias'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFMenuActionCard(
              icon: Icons.category_outlined,
              title: 'Categorias',
              subtitle: 'Organize suas contas',
            ),
          ),
        ),
      );

      expect(find.text('Organize suas contas'), findsOneWidget);
    });

    testWidgets('responds to onTap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFMenuActionCard(
              icon: Icons.category_outlined,
              title: 'Tappable',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FFMenuActionCard));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('shows chevron by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFMenuActionCard(
              icon: Icons.settings,
              title: 'Settings',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('hides chevron when showChevron is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFMenuActionCard(
              icon: Icons.settings,
              title: 'Settings',
              showChevron: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('uses custom icon color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFMenuActionCard(
              icon: Icons.category_outlined,
              iconColor: Colors.red,
              title: 'Red Icon',
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.category_outlined));
      expect(icon.color, Colors.red);
    });

    testWidgets('renders correctly in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: FFMenuActionCard(
              icon: Icons.settings,
              title: 'Dark Mode',
              subtitle: 'Test',
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Dark Mode'), findsOneWidget);
    });

    testWidgets('respects density parameter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFMenuActionCard(
              icon: Icons.settings,
              title: 'Desktop Density',
              density: FFEntityDensity.desktop,
            ),
          ),
        ),
      );

      expect(find.byType(FFMenuActionCard), findsOneWidget);
    });
  });

  // =============================================
  // FFEntityPageScaffold TESTS
  // =============================================

  group('FFEntityPageScaffold', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FFEntityPageScaffold(
            title: 'Test Page',
            child: SizedBox(),
          ),
        ),
      );

      // Title should be present (in FFScreenScaffold)
      expect(find.byType(FFEntityPageScaffold), findsOneWidget);
    });

    testWidgets('shows empty state when isEmpty is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FFEntityPageScaffold(
            title: 'Empty Page',
            isEmpty: true,
            emptyState: FFEmptyState.categorias(),
            child: const Text('Should not show'),
          ),
        ),
      );

      expect(find.text('Nenhuma categoria'), findsOneWidget);
      expect(find.text('Should not show'), findsNothing);
    });

    testWidgets('shows child when isEmpty is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FFEntityPageScaffold(
            title: 'With Content',
            isEmpty: false,
            child: Text('Content here'),
          ),
        ),
      );

      expect(find.text('Content here'), findsOneWidget);
    });

    testWidgets('shows actions bar when actions provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FFEntityPageScaffold(
            title: 'With Actions',
            primaryAction: FFEntityAction(
              label: 'Add',
              onPressed: () {},
            ),
            child: const SizedBox(),
          ),
        ),
      );

      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('renders without overflow at 1366x768', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: FFEntityPageScaffold(
            title: 'Desktop Test',
            primaryAction: FFEntityAction(
              label: 'New',
              onPressed: () {},
            ),
            child: const Center(child: Text('Content')),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without overflow at 800x600', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: FFEntityPageScaffold(
            title: 'Small Screen Test',
            primaryAction: FFEntityAction(
              label: 'New',
              onPressed: () {},
            ),
            child: const Center(child: Text('Content')),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: FFEntityPageScaffold(
            title: 'Dark Mode Page',
            primaryAction: FFEntityAction(
              label: 'Action',
              onPressed: () {},
            ),
            child: const Text('Dark content'),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Dark content'), findsOneWidget);
    });
  });
}
