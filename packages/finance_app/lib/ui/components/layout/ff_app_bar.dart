import 'package:flutter/material.dart';

/// AppBar padrão do FácilFin Design System.
///
/// Características:
/// - Título centralizado
/// - elevation 0 (visual limpo)
/// - scrolledUnderElevation 1 (sutil elevação ao rolar)
/// - Usa cores do tema automaticamente
class FFAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Título da AppBar
  final String title;

  /// Widget leading (geralmente botão voltar)
  final Widget? leading;

  /// Lista de actions à direita
  final List<Widget>? actions;

  /// Se deve mostrar o botão voltar automático
  final bool automaticallyImplyLeading;

  /// Altura da AppBar (padrão kToolbarHeight)
  final double? toolbarHeight;

  /// Widget de bottom (ex: TabBar)
  final PreferredSizeWidget? bottom;

  const FFAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.toolbarHeight,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: leading,
      actions: actions,
      automaticallyImplyLeading: automaticallyImplyLeading,
      toolbarHeight: toolbarHeight,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        (toolbarHeight ?? kToolbarHeight) + (bottom?.preferredSize.height ?? 0),
      );
}
