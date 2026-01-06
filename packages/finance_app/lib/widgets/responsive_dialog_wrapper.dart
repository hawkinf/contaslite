import 'package:flutter/material.dart';

/// Widget responsivo para envolver conteúdo de diálogos.
/// Adapta-se automaticamente ao tamanho da tela sem causar overflow.
class ResponsiveDialogWrapper extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool useScrollable;
  final double maxWidthPercent;
  final double maxHeightPercent;

  const ResponsiveDialogWrapper({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.useScrollable = true,
    this.maxWidthPercent = 0.9,
    this.maxHeightPercent = 0.85,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final viewInsets = MediaQuery.of(context).viewInsets;

    // Calcular dimensões máximas baseadas na porcentagem da tela
    final maxWidth = screenSize.width * maxWidthPercent;
    final maxHeight = (screenSize.height - viewInsets.bottom) * maxHeightPercent;

    final content = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
      child: useScrollable
          ? SingleChildScrollView(
              padding: padding,
              child: child,
            )
          : Padding(
              padding: padding,
              child: child,
            ),
    );

    return Dialog(
      insetPadding: EdgeInsets.all(
        (screenSize.width - maxWidth) / 2,
      ),
      child: content,
    );
  }
}

/// Wrapper de Dialog simples que calcula automaticamente as dimensões
class ConstrainedDialog extends StatelessWidget {
  final Widget child;
  final double maxWidthPercent;
  final double maxHeightPercent;
  final EdgeInsets insetPadding;

  const ConstrainedDialog({
    super.key,
    required this.child,
    this.maxWidthPercent = 0.9,
    this.maxHeightPercent = 0.85,
    this.insetPadding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final viewInsets = MediaQuery.of(context).viewInsets;

    final maxWidth = (screenSize.width * maxWidthPercent).clamp(0.0, 600.0);
    final maxHeight =
        ((screenSize.height - viewInsets.bottom) * maxHeightPercent)
            .clamp(0.0, 900.0);

    return Dialog(
      insetPadding: insetPadding,
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
      child: child,
    );
  }
}

/// Componente de conteúdo scrollável para dialogs
class ScrollableDialogContent extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? backgroundColor;

  const ScrollableDialogContent({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultBgColor = theme.dialogTheme.backgroundColor ?? Colors.white;

    return Container(
      color: backgroundColor ?? defaultBgColor,
      child: SingleChildScrollView(
        padding: padding,
        child: child,
      ),
    );
  }
}
