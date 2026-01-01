import 'package:flutter/material.dart';

/// Retorna a melhor cor de foreground (escura/clara) para garantir contraste
/// contra um background arbitrário.
///
/// Usa um limiar simples de luminância para contraste consistente.
Color foregroundColorFor(Color background, {Color dark = Colors.black, Color light = Colors.white}) {
  final bg = background.computeLuminance();
  return bg >= 0.6 ? dark : light;
}
