import 'package:flutter/material.dart';

/// Cores padronizadas do aplicativo para manter consistencia visual
/// Use estas cores em vez de cores hardcoded como Colors.blue.shade700
class AppColors {
  AppColors._();

  // === CORES PRIMARIAS ===

  /// Cor primaria do app (azul)
  static const Color primary = Color(0xFF1976D2); // blue.shade700
  static const Color primaryLight = Color(0xFF42A5F5); // blue.shade400
  static const Color primaryDark = Color(0xFF0D47A1); // blue.shade900

  // === CORES DE ACAO ===

  /// Verde para sucesso, confirmacao, receitas
  static const Color success = Color(0xFF43A047); // green.shade600
  static const Color successLight = Color(0xFF66BB6A); // green.shade400
  static const Color successDark = Color(0xFF2E7D32); // green.shade700

  /// Vermelho para erro, exclusao, despesas
  static const Color error = Color(0xFFE53935); // red.shade600
  static const Color errorLight = Color(0xFFEF5350); // red.shade400
  static const Color errorDark = Color(0xFFC62828); // red.shade700

  /// Laranja para alertas, avisos, pendencias
  static const Color warning = Color(0xFFFB8C00); // orange.shade600
  static const Color warningLight = Color(0xFFFFB74D); // orange.shade300
  static const Color warningDark = Color(0xFFEF6C00); // orange.shade800
  static const Color warningBackground = Color(0xFFFFF3E0); // orange.shade50

  // === CORES SECUNDARIAS ===

  /// Roxo para cartoes de credito e items especiais
  static const Color cardPurple = Color(0xFF7B1FA2); // purple.shade700
  static const Color cardPurpleLight = Color(0xFF9C27B0); // purple.shade500
  static const Color cardPurpleDark = Color(0xFF4A148C); // purple.shade900

  /// Indigo para elementos secundarios
  static const Color secondary = Color(0xFF3949AB); // indigo.shade600

  // === CORES DE TEXTO E FUNDO ===

  /// Cinza para textos secundarios e elementos desabilitados
  static const Color textSecondary = Color(0xFF757575); // grey.shade600
  static const Color textHint = Color(0xFF9E9E9E); // grey.shade500
  static const Color textDisabled = Color(0xFFBDBDBD); // grey.shade400

  /// Backgrounds
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color backgroundCard = Colors.white;
  static const Color backgroundDark = Color(0xFF121212);
  static const Color backgroundCardDark = Color(0xFF1E1E1E);

  // === CORES ESPECIAIS ===

  /// Cores para categorias financeiras
  static const Color expense = error; // Despesas em vermelho
  static const Color income = success; // Receitas em verde
  static const Color creditCard = cardPurple; // Cartao de credito em roxo
  static const Color installment = Color(0xFFFFAB40); // orange.accent200 para parcelado
  static const Color subscription = Color(0xFFAB47BC); // purple.shade400 para assinaturas
  static const Color oneOff = primaryLight; // Avista em azul claro

  /// Paleta essencial de cores (substitui a paleta estendida)
  static const List<Color> essentialPalette = [
    error, // vermelho
    warning, // laranja
    success, // verde
    primary, // azul
    secondary, // indigo
    cardPurple, // roxo
    backgroundCard, // branco
    Colors.black, // preto
    textSecondary, // cinza
  ];

  /// Obtem cor adaptativa baseada no brilho do tema
  static Color adaptive(BuildContext context, {
    required Color light,
    Color? dark,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? (dark ?? light) : light;
  }

  /// Cor de texto secundario que se adapta ao tema
  static Color adaptiveTextSecondary(BuildContext context) {
    return adaptive(context, light: textSecondary, dark: Colors.grey.shade400);
  }

  /// Cor de fundo de card que se adapta ao tema
  static Color adaptiveCardBackground(BuildContext context) {
    return adaptive(context, light: backgroundCard, dark: backgroundCardDark);
  }
}

/// Extensao para facilitar uso de cores do tema
extension AppColorsContext on BuildContext {
  /// Retorna a cor primaria do tema
  Color get primaryColor => Theme.of(this).colorScheme.primary;

  /// Retorna a cor de texto sobre a cor primaria
  Color get onPrimaryColor => Theme.of(this).colorScheme.onPrimary;

  /// Verifica se o tema atual e escuro
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
