import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_app/ui/components/ff_design_system.dart';

/// Testes para os componentes do Design System usados nas telas de Tabelas.
///
/// Inclui testes para:
/// - FFActionsBar
/// - FFEntityListItem
/// - FFConfirmDialog
/// - FFEmptyState (factories para tabelas)
void main() {
  // =============================================
  // FFActionsBar TESTS
  // =============================================

  group('FFActionsBar', () {
    testWidgets('renders primary action button', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFActionsBar(
              primaryAction: FFActionsBarAction(
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
            body: FFActionsBar(
              secondaryAction: FFActionsBarAction(
                label: 'Popular',
                icon: Icons.auto_awesome,
                onPressed: () => pressed = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Popular'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);

      await tester.tap(find.text('Popular'));
      await tester.pump();

      expect(pressed, isTrue);
    });

    testWidgets('renders both primary and secondary actions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFActionsBar(
              primaryAction: FFActionsBarAction(
                label: 'Criar',
                icon: Icons.add,
                onPressed: () {},
              ),
              secondaryAction: FFActionsBarAction(
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
            body: FFActionsBar(
              primaryAction: FFActionsBarAction(
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

    testWidgets('uses Wrap by default for responsiveness', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFActionsBar(
              primaryAction: FFActionsBarAction(
                label: 'Test',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Wrap), findsOneWidget);
    });

    testWidgets('uses Row when useWrap is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFActionsBar(
              useWrap: false,
              primaryAction: FFActionsBarAction(
                label: 'Test',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      // Should not have Wrap when useWrap is false
      expect(find.byType(Wrap), findsNothing);
      // Row is used inside
      expect(find.byType(Row), findsAtLeast(1));
    });

    testWidgets('aligns buttons to the end', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFActionsBar(
              primaryAction: FFActionsBarAction(
                label: 'Test',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.alignment, WrapAlignment.end);
    });
  });

  group('FFActionsBarAction', () {
    test('default isLoading is false', () {
      const action = FFActionsBarAction(label: 'Test');
      expect(action.isLoading, isFalse);
    });

    test('default useTonal is true', () {
      const action = FFActionsBarAction(label: 'Test');
      expect(action.useTonal, isTrue);
    });

    test('accepts all parameters', () {
      const action = FFActionsBarAction(
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
  // FFEntityListItem TESTS
  // =============================================

  group('FFEntityListItem', () {
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

    testWidgets('renders leading widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFEntityListItem(
              leading: Text('🍔'),
              title: 'Alimentação',
            ),
          ),
        ),
      );

      expect(find.text('🍔'), findsOneWidget);
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

    testWidgets('shows reorder button when onReorder provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFEntityListItem(
              title: 'Item',
              onReorder: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.drag_handle), findsOneWidget);
    });

    testWidgets('responds to onTap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFEntityListItem(
              title: 'Tappable',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tappable'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('uses InkWell when onTap is provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFEntityListItem(
              title: 'Tappable',
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('compact density has smaller height', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFEntityListItem(
              title: 'Compact',
              density: FFEntityDensity.compact,
            ),
          ),
        ),
      );

      // Compact density = 48px height
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(FFEntityListItem),
          matching: find.byType(Container),
        ).first,
      );

      expect(container.constraints?.maxHeight, 48.0);
    });

    testWidgets('shows divider by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFEntityListItem(
              title: 'With Divider',
            ),
          ),
        ),
      );

      // Should have border on bottom
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(FFEntityListItem),
          matching: find.byType(Container),
        ).first,
      );

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
    });

    testWidgets('hides divider when showDivider is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFEntityListItem(
              title: 'No Divider',
              showDivider: false,
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(FFEntityListItem),
          matching: find.byType(Container),
        ).first,
      );

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNull);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: FFEntityListItem(
              title: 'Dark Mode',
              subtitle: 'Test',
            ),
          ),
        ),
      );

      expect(find.text('Dark Mode'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('FFEntityListItem.category factory', () {
    testWidgets('renders category with emoji', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFEntityListItem.category(
              emoji: '🍔',
              name: 'Alimentação',
              description: 'Categoria de despesas',
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.text('🍔'), findsOneWidget);
      expect(find.text('Alimentação'), findsOneWidget);
      expect(find.text('Categoria de despesas'), findsOneWidget);
    });

    testWidgets('renders category without emoji', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFEntityListItem.category(
              name: 'Sem Emoji',
              onEdit: () {},
            ),
          ),
        ),
      );

      expect(find.text('Sem Emoji'), findsOneWidget);
    });
  });

  group('FFEntityListItem.paymentMethod factory', () {
    testWidgets('renders payment method with emoji', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFEntityListItem.paymentMethod(
              emoji: '💳',
              name: 'Cartão de Crédito',
              type: 'CREDIT_CARD',
              onEdit: () {},
            ),
          ),
        ),
      );

      expect(find.text('💳'), findsOneWidget);
      expect(find.text('Cartão de Crédito'), findsOneWidget);
      expect(find.text('CREDIT_CARD'), findsOneWidget);
    });

    testWidgets('renders payment method with icon', (tester) async {
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

    testWidgets('prefers emoji over icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFEntityListItem.paymentMethod(
              emoji: '💳',
              icon: Icons.credit_card,
              name: 'Test',
            ),
          ),
        ),
      );

      expect(find.text('💳'), findsOneWidget);
      expect(find.byIcon(Icons.credit_card), findsNothing);
    });
  });

  // =============================================
  // FFConfirmDialog TESTS
  // =============================================

  group('FFConfirmDialog', () {
    testWidgets('displays title and message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const FFConfirmDialog(
                      title: 'Test Title',
                      message: 'Test Message',
                    ),
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test Message'), findsOneWidget);
    });

    testWidgets('displays default button labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const FFConfirmDialog(
                      title: 'Title',
                      message: 'Message',
                    ),
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Confirmar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('displays custom button labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const FFConfirmDialog(
                      title: 'Title',
                      message: 'Message',
                      confirmLabel: 'Sim',
                      cancelLabel: 'Não',
                    ),
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Sim'), findsOneWidget);
      expect(find.text('Não'), findsOneWidget);
    });

    testWidgets('displays icon when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const FFConfirmDialog(
                      title: 'Title',
                      message: 'Message',
                      icon: Icons.warning,
                    ),
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('returns false when Cancel is pressed', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await FFConfirmDialog.show(
                    context: context,
                    title: 'Title',
                    message: 'Message',
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('returns true when Confirm is pressed', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await FFConfirmDialog.show(
                    context: context,
                    title: 'Title',
                    message: 'Message',
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const FFConfirmDialog(
                      title: 'Dark Mode',
                      message: 'Test',
                    ),
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Dark Mode'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('FFConfirmDialog.showDelete', () {
    testWidgets('displays delete-specific title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  FFConfirmDialog.showDelete(
                    context: context,
                    itemName: 'Alimentação',
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Excluir "Alimentação"?'), findsOneWidget);
    });

    testWidgets('displays delete icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  FFConfirmDialog.showDelete(
                    context: context,
                    itemName: 'Item',
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('displays Excluir button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  FFConfirmDialog.showDelete(
                    context: context,
                    itemName: 'Item',
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Excluir'), findsOneWidget);
    });

    testWidgets('displays custom message when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  FFConfirmDialog.showDelete(
                    context: context,
                    itemName: 'Item',
                    customMessage: 'Custom delete message',
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Custom delete message'), findsOneWidget);
    });
  });

  // =============================================
  // FFEmptyState FACTORIES FOR TABLES
  // =============================================

  group('FFEmptyState.categorias', () {
    testWidgets('displays correct icon and text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFEmptyState.categorias(),
          ),
        ),
      );

      expect(find.byIcon(Icons.category_outlined), findsOneWidget);
      expect(find.text('Nenhuma categoria'), findsOneWidget);
    });

    testWidgets('displays action button when onAction provided', (tester) async {
      bool actionCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFEmptyState.categorias(
              onAction: () => actionCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Nova Categoria'), findsOneWidget);

      await tester.tap(find.text('Nova Categoria'));
      await tester.pump();

      expect(actionCalled, isTrue);
    });
  });

  group('FFEmptyState.bancos', () {
    testWidgets('displays correct icon and text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFEmptyState.bancos(),
          ),
        ),
      );

      expect(find.byIcon(Icons.account_balance_outlined), findsOneWidget);
      expect(find.text('Nenhum banco cadastrado'), findsOneWidget);
    });

    testWidgets('displays action button when onAction provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFEmptyState.bancos(
              onAction: () {},
            ),
          ),
        ),
      );

      expect(find.text('Novo Banco'), findsOneWidget);
    });
  });

  group('FFEmptyState.formasPagamento', () {
    testWidgets('displays correct icon and text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFEmptyState.formasPagamento(),
          ),
        ),
      );

      expect(find.byIcon(Icons.payment_outlined), findsOneWidget);
      expect(find.text('Nenhuma forma de pagamento'), findsOneWidget);
    });

    testWidgets('displays action button when onAction provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFEmptyState.formasPagamento(
              onAction: () {},
            ),
          ),
        ),
      );

      expect(find.text('Novo Item'), findsOneWidget);
    });
  });

  group('FFEmptyState.tabelas', () {
    testWidgets('displays correct icon and text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFEmptyState.tabelas(),
          ),
        ),
      );

      expect(find.byIcon(Icons.table_chart_outlined), findsOneWidget);
      expect(find.text('Nenhum cadastro'), findsOneWidget);
    });
  });
}
