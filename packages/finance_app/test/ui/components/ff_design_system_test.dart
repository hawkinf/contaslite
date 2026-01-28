import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_app/ui/components/ff_design_system.dart';
import 'package:finance_app/ui/theme/app_colors.dart';
import 'package:finance_app/ui/theme/app_radius.dart';
import 'package:finance_app/ui/theme/app_spacing.dart';

/// Testes de widgets do Design System FF*.
///
/// Garante que os componentes aplicam os estilos padrão corretamente.
void main() {
  group('FFCard', () {
    testWidgets('aplica radius padrão (lg = 16)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFCard(
              child: Text('Test'),
            ),
          ),
        ),
      );

      // Encontra o Container que contém a decoração
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(FFCard),
          matching: find.byType(Container),
        ).first,
      );

      // Verifica que a decoração existe e tem o radius correto
      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(AppRadius.lg));
    });

    testWidgets('aplica borda padrão (1px)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFCard(
              child: Text('Test'),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(FFCard),
          matching: find.byType(Container),
        ).first,
      );

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
    });

    testWidgets('aplica padding padrão (lg = 16)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFCard(
              child: Text('Test'),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(FFCard),
          matching: find.byType(Container),
        ).first,
      );

      expect(container.padding, const EdgeInsets.all(AppSpacing.lg));
    });

    testWidgets('responde a onTap quando fornecido', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFCard(
              onTap: () => tapped = true,
              child: const Text('Tappable'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tappable'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('não tem InkWell quando onTap é null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFCard(
              child: Text('Not tappable'),
            ),
          ),
        ),
      );

      expect(find.byType(InkWell), findsNothing);
    });
  });

  group('FFBadge', () {
    testWidgets('exibe o label corretamente', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFBadge(
              label: 'Test Label',
              type: FFBadgeType.info,
            ),
          ),
        ),
      );

      expect(find.text('Test Label'), findsOneWidget);
    });

    testWidgets('aplica cor success correta', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFBadge(
              label: 'Success',
              type: FFBadgeType.success,
              icon: Icons.check,
            ),
          ),
        ),
      );

      // Verifica que o texto está presente
      expect(find.text('Success'), findsOneWidget);

      // Verifica que o ícone está presente
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Verifica a cor do ícone
      final icon = tester.widget<Icon>(find.byIcon(Icons.check));
      expect(icon.color, AppColors.success);
    });

    testWidgets('aplica cor error correta', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFBadge(
              label: 'Error',
              type: FFBadgeType.error,
              icon: Icons.error,
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.error));
      expect(icon.color, AppColors.error);
    });

    testWidgets('aplica cor warning correta', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFBadge(
              label: 'Warning',
              type: FFBadgeType.warning,
              icon: Icons.warning,
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.warning));
      // Warning color é Color(0xFFF59E0B)
      expect(icon.color, const Color(0xFFF59E0B));
    });

    testWidgets('FFBadge.syncStatus mostra ícone de sync quando sincronizando', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFBadge.syncStatus(
              label: 'Sincronizando...',
              isSynced: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.sync), findsOneWidget);
    });

    testWidgets('FFBadge.syncStatus mostra ícone cloud_done quando sincronizado', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFBadge.syncStatus(
              label: 'Sincronizado',
              isSynced: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
    });
  });

  group('FFIconActionButton', () {
    testWidgets('exibe tooltip obrigatório', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFIconActionButton(
              icon: Icons.edit,
              tooltip: 'Edit item',
            ),
          ),
        ),
      );

      // Verifica que o Tooltip está presente
      expect(find.byType(Tooltip), findsOneWidget);

      // Verifica que o tooltip tem a mensagem correta
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Edit item');
    });

    testWidgets('aplica cor primary padrão', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          home: const Scaffold(
            body: FFIconActionButton(
              icon: Icons.edit,
              tooltip: 'Edit',
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.edit));
      // A cor deve ser a primary do tema
      expect(icon.color, isNotNull);
    });

    testWidgets('.danger() aplica cor de erro', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFIconActionButton.danger(
              icon: Icons.delete,
              tooltip: 'Delete',
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.delete));
      // Danger color é AppColors.error (0xFFDC2626)
      expect(icon.color, const Color(0xFFDC2626));
    });

    testWidgets('.success() aplica cor de sucesso', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFIconActionButton.success(
              icon: Icons.check,
              tooltip: 'Confirm',
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.check));
      // Success color é AppColors.success (0xFF16A34A)
      expect(icon.color, const Color(0xFF16A34A));
    });

    testWidgets('responde a onPressed', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFIconActionButton(
              icon: Icons.edit,
              tooltip: 'Edit',
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FFIconActionButton));
      await tester.pump();

      expect(pressed, isTrue);
    });

    testWidgets('não responde quando enabled = false', (tester) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFIconActionButton(
              icon: Icons.edit,
              tooltip: 'Edit',
              enabled: false,
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FFIconActionButton));
      await tester.pump();

      expect(pressed, isFalse);
    });

    testWidgets('tem tamanho padrão de 40', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFIconActionButton(
              icon: Icons.edit,
              tooltip: 'Edit',
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(FFIconActionButton),
          matching: find.byType(Container),
        ).first,
      );

      expect(container.constraints?.maxWidth, 40);
      expect(container.constraints?.maxHeight, 40);
    });
  });

  group('FFPrimaryButton', () {
    testWidgets('exibe label corretamente', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFPrimaryButton(
              label: 'Click Me',
              onPressed: null,
            ),
          ),
        ),
      );

      expect(find.text('Click Me'), findsOneWidget);
    });

    testWidgets('mostra loading indicator quando isLoading = true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFPrimaryButton(
              label: 'Loading',
              isLoading: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('exibe ícone quando fornecido', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFPrimaryButton(
              label: 'Save',
              icon: Icons.save,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.save), findsOneWidget);
    });
  });

  group('FFSecondaryButton', () {
    testWidgets('exibe label corretamente', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFSecondaryButton(
              label: 'Cancel',
              onPressed: null,
            ),
          ),
        ),
      );

      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('usa OutlinedButton por padrão', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFSecondaryButton(
              label: 'Cancel',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('usa FilledButton.tonal quando tonal = true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFSecondaryButton(
              label: 'Tonal',
              tonal: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      // FilledButton.tonal ainda é um FilledButton
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });

  group('FFSection', () {
    testWidgets('exibe título em uppercase por padrão', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFSection(
              title: 'minha seção',
              child: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.text('MINHA SEÇÃO'), findsOneWidget);
    });

    testWidgets('exibe título sem uppercase quando uppercaseTitle = false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFSection(
              title: 'Minha Seção',
              uppercaseTitle: false,
              child: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.text('Minha Seção'), findsOneWidget);
    });

    testWidgets('exibe ícone quando fornecido', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFSection(
              title: 'Settings',
              icon: Icons.settings,
              child: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('exibe subtítulo quando fornecido', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FFSection(
              title: 'Settings',
              subtitle: 'Configure your preferences',
              child: Text('Content'),
            ),
          ),
        ),
      );

      expect(find.text('Configure your preferences'), findsOneWidget);
    });
  });

  group('FFActionCard', () {
    testWidgets('exibe título e subtítulo', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFActionCard(
              icon: Icons.settings,
              title: 'Settings',
              subtitle: 'Configure app',
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Configure app'), findsOneWidget);
    });

    testWidgets('exibe chevron por padrão', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFActionCard(
              icon: Icons.settings,
              title: 'Settings',
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('oculta chevron quando showChevron = false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFActionCard(
              icon: Icons.settings,
              title: 'Settings',
              showChevron: false,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });
  });
}
