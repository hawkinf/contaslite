import 'package:flutter/material.dart';

/// Retorna a melhor cor de foreground (escura/clara) para garantir contraste
/// contra um background arbitrário.
///
/// Usa a fórmula de contraste (WCAG) com a luminância relativa.
Color foregroundColorFor(Color background, {Color dark = Colors.black, Color light = Colors.white}) {
  final bg = background.computeLuminance();
  final darkL = dark.computeLuminance();
  final lightL = light.computeLuminance();

  double contrast(double l1, double l2) {
    final maxL = l1 > l2 ? l1 : l2;
    final minL = l1 > l2 ? l2 : l1;
    return (maxL + 0.05) / (minL + 0.05);
  }

  final cDark = contrast(bg, darkL);
  final cLight = contrast(bg, lightL);
  return cDark >= cLight ? dark : light;
}
