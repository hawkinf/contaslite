import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import 'ff_app_bar.dart';

/// Scaffold wrapper padrão do FácilFin Design System.
///
/// Responsabilidades:
/// - Aplica background padrão do tema
/// - Padding horizontal default (20)
/// - SafeArea automática
/// - Scroll padrão quando useScrollView = true
class FFScreenScaffold extends StatelessWidget {
  /// Título da tela (exibido na AppBar)
  final String title;

  /// Ações da AppBar
  final List<Widget>? appBarActions;

  /// Widget leading da AppBar
  final Widget? appBarLeading;

  /// Conteúdo principal da tela
  final Widget child;

  /// Se deve usar ScrollView automaticamente
  final bool useScrollView;

  /// Padding horizontal customizado (padrão 20)
  final double horizontalPadding;

  /// Padding vertical customizado (padrão 24)
  final double verticalPadding;

  /// Se deve aplicar SafeArea
  final bool useSafeArea;

  /// FloatingActionButton opcional
  final Widget? floatingActionButton;

  /// Posição do FAB
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// Bottom navigation bar opcional
  final Widget? bottomNavigationBar;

  /// Widget de bottom da AppBar (ex: TabBar)
  final PreferredSizeWidget? appBarBottom;

  /// Se deve mostrar a AppBar
  final bool showAppBar;

  const FFScreenScaffold({
    super.key,
    required this.title,
    required this.child,
    this.appBarActions,
    this.appBarLeading,
    this.useScrollView = true,
    this.horizontalPadding = 20,
    this.verticalPadding = AppSpacing.xl,
    this.useSafeArea = true,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.appBarBottom,
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: child,
    );

    if (useScrollView) {
      content = SingleChildScrollView(
        child: content,
      );
    }

    if (useSafeArea) {
      content = SafeArea(
        child: content,
      );
    }

    return Scaffold(
      appBar: showAppBar
          ? FFAppBar(
              title: title,
              actions: appBarActions,
              leading: appBarLeading,
              bottom: appBarBottom,
            )
          : null,
      body: content,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
