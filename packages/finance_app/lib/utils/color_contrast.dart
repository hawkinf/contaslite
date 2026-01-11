import 'package:flutter/material.dart';

/// Retorna a melhor cor de foreground (escura/clara) para garantir contraste
/// contra um background arbitrário.
///
/// Usa um limiar simples de luminância para contraste consistente.
Color foregroundColorFor(Color background, {Color dark = Colors.black, Color light = Colors.white}) {
  // Para amarelos, força texto/ícone preto (checkmark preto em fundos amarelos).
  final int argb = background.toARGB32();
  final int r = (argb >> 16) & 0xFF;
  final int g = (argb >> 8) & 0xFF;
  final int b = argb & 0xFF;
  final isYellowLike = r >= 200 && g >= 200 && b <= 140;

  if (isYellowLike) return dark;

  final bg = background.computeLuminance();
  return bg >= 0.6 ? dark : light;
}
