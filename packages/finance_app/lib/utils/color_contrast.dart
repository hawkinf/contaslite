import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Resultado da análise de contraste entre duas cores
enum ContrastResult {
  /// Contraste excelente - pode usar sem restrições
  excellent,
  /// Contraste bom - recomendado para uso geral
  good,
  /// Contraste marginal - usar apenas para textos grandes ou elementos decorativos
  marginal,
  /// Contraste insuficiente - não usar
  poor,
}

/// Classe utilitária para análise e gestão de contraste de cores
///
/// Implementa as diretrizes WCAG para acessibilidade de cores:
/// - Contraste mínimo de 4.5:1 para texto normal (AA)
/// - Contraste mínimo de 3:1 para texto grande (AA)
/// - Contraste mínimo de 7:1 para texto normal (AAA)
class ColorContrast {
  ColorContrast._();

  /// Limiar de luminância para decidir entre texto claro/escuro
  /// Cores com luminância >= 0.5 usam texto escuro, caso contrário texto claro
  static const double _luminanceThreshold = 0.5;

  /// Calcula a razão de contraste entre duas cores (WCAG)
  /// Retorna um valor entre 1 e 21
  static double contrastRatio(Color foreground, Color background) {
    final fgLuminance = foreground.computeLuminance();
    final bgLuminance = background.computeLuminance();

    final lighter = fgLuminance > bgLuminance ? fgLuminance : bgLuminance;
    final darker = fgLuminance > bgLuminance ? bgLuminance : fgLuminance;

    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Avalia o resultado do contraste baseado na razão WCAG
  static ContrastResult evaluateContrast(double ratio) {
    if (ratio >= 7.0) return ContrastResult.excellent;
    if (ratio >= 4.5) return ContrastResult.good;
    if (ratio >= 3.0) return ContrastResult.marginal;
    return ContrastResult.poor;
  }

  /// Verifica se duas cores têm contraste suficiente para texto normal
  static bool hasMinimumContrast(Color foreground, Color background, {double minRatio = 4.5}) {
    return contrastRatio(foreground, background) >= minRatio;
  }

  /// Verifica se a cor é considerada "clara"
  static bool isLightColor(Color color) {
    return color.computeLuminance() >= _luminanceThreshold;
  }

  /// Verifica se a cor é considerada "escura"
  static bool isDarkColor(Color color) {
    return color.computeLuminance() < _luminanceThreshold;
  }

  /// Detecta se a cor é amarelada (requer tratamento especial)
  static bool isYellowish(Color color) {
    final int argb = color.toARGB32();
    final int r = (argb >> 16) & 0xFF;
    final int g = (argb >> 8) & 0xFF;
    final int b = argb & 0xFF;
    return r >= 200 && g >= 200 && b <= 140;
  }

  /// Detecta se a cor é alaranjada (pode usar preto ou branco)
  static bool isOrangish(Color color) {
    final int argb = color.toARGB32();
    final int r = (argb >> 16) & 0xFF;
    final int g = (argb >> 8) & 0xFF;
    final int b = argb & 0xFF;
    // Laranja típico: alto vermelho, médio verde, baixo azul
    return r >= 200 && g >= 100 && g <= 180 && b <= 80;
  }

  /// Retorna a melhor cor de texto para um dado fundo
  ///
  /// Analisa a luminância e características especiais da cor de fundo
  /// para determinar se deve usar texto claro ou escuro.
  static Color bestTextColor(Color background, {
    Color dark = Colors.black,
    Color light = Colors.white,
  }) {
    // Amarelos sempre usam texto preto
    if (isYellowish(background)) return dark;

    // Laranjas preferem texto preto para melhor legibilidade
    if (isOrangish(background)) {
      final ratioWithBlack = contrastRatio(dark, background);
      final ratioWithWhite = contrastRatio(light, background);
      // Prefere preto se tiver contraste razoável
      if (ratioWithBlack >= 3.0) return dark;
      return ratioWithWhite > ratioWithBlack ? light : dark;
    }

    // Regra geral baseada em luminância
    return background.computeLuminance() >= _luminanceThreshold ? dark : light;
  }

  /// Encontra a melhor cor da paleta para usar sobre um fundo específico
  ///
  /// Retorna a cor da paleta com melhor contraste contra o fundo,
  /// excluindo a própria cor de fundo se estiver na paleta.
  static Color bestPaletteColorFor(Color background, {
    List<Color>? palette,
    double minContrast = 4.5,
  }) {
    final colors = palette ?? AppColors.essentialPalette;

    Color bestColor = Colors.white;
    double bestRatio = 0;

    for (final color in colors) {
      // Pula se for a mesma cor ou muito similar
      if (_isSameOrSimilar(color, background)) continue;

      final ratio = contrastRatio(color, background);
      if (ratio > bestRatio) {
        bestRatio = ratio;
        bestColor = color;
      }
    }

    return bestColor;
  }

  /// Verifica se duas cores são iguais ou muito similares
  static bool _isSameOrSimilar(Color a, Color b, {double tolerance = 0.05}) {
    final lumA = a.computeLuminance();
    final lumB = b.computeLuminance();
    return (lumA - lumB).abs() < tolerance;
  }

  /// Retorna uma cor de destaque que contrasta bem com o fundo
  ///
  /// Útil para ícones de ação, links, etc.
  static Color accentColorFor(Color background) {
    final luminance = background.computeLuminance();

    // Fundos claros: usar cores escuras vibrantes
    if (luminance >= 0.6) {
      return AppColors.primary; // Azul para fundos claros
    }

    // Fundos médios: verificar qual funciona melhor
    if (luminance >= 0.3) {
      final ratioWithPrimary = contrastRatio(AppColors.primary, background);
      final ratioWithPrimaryLight = contrastRatio(AppColors.primaryLight, background);
      return ratioWithPrimary > ratioWithPrimaryLight
          ? AppColors.primary
          : AppColors.primaryLight;
    }

    // Fundos escuros: usar cores claras
    return AppColors.primaryLight;
  }

  /// Retorna cores para estado de sucesso com contraste adequado
  static Color successColorFor(Color background) {
    final luminance = background.computeLuminance();
    if (luminance >= 0.5) return AppColors.successDark;
    if (luminance >= 0.2) return AppColors.success;
    return AppColors.successLight;
  }

  /// Retorna cores para estado de erro com contraste adequado
  static Color errorColorFor(Color background) {
    final luminance = background.computeLuminance();
    if (luminance >= 0.5) return AppColors.errorDark;
    if (luminance >= 0.2) return AppColors.error;
    return AppColors.errorLight;
  }

  /// Retorna cores para estado de alerta com contraste adequado
  static Color warningColorFor(Color background) {
    final luminance = background.computeLuminance();
    if (luminance >= 0.5) return AppColors.warningDark;
    if (luminance >= 0.2) return AppColors.warning;
    return AppColors.warningLight;
  }

  /// Gera uma versão mais clara ou mais escura de uma cor para melhor contraste
  static Color adjustForContrast(Color color, Color background, {double targetRatio = 4.5}) {
    final currentRatio = contrastRatio(color, background);
    if (currentRatio >= targetRatio) return color;

    final bgLuminance = background.computeLuminance();
    final HSLColor hsl = HSLColor.fromColor(color);

    // Se o fundo é claro, escurece a cor; se é escuro, clareia
    if (bgLuminance >= 0.5) {
      // Escurecer progressivamente
      for (double l = hsl.lightness; l >= 0; l -= 0.05) {
        final adjusted = hsl.withLightness(l).toColor();
        if (contrastRatio(adjusted, background) >= targetRatio) {
          return adjusted;
        }
      }
    } else {
      // Clarear progressivamente
      for (double l = hsl.lightness; l <= 1; l += 0.05) {
        final adjusted = hsl.withLightness(l).toColor();
        if (contrastRatio(adjusted, background) >= targetRatio) {
          return adjusted;
        }
      }
    }

    // Se não conseguiu ajustar, retorna preto ou branco
    return bgLuminance >= 0.5 ? Colors.black : Colors.white;
  }

  /// Verifica se uma combinação de cores é acessível
  static bool isAccessible(Color foreground, Color background, {
    bool largeText = false,
  }) {
    final ratio = contrastRatio(foreground, background);
    // WCAG AA: 4.5:1 para texto normal, 3:1 para texto grande
    return ratio >= (largeText ? 3.0 : 4.5);
  }

  /// Retorna informações detalhadas sobre o contraste entre duas cores
  static Map<String, dynamic> analyzeContrast(Color foreground, Color background) {
    final ratio = contrastRatio(foreground, background);
    final result = evaluateContrast(ratio);

    return {
      'ratio': ratio,
      'result': result,
      'passesAA': ratio >= 4.5,
      'passesAALarge': ratio >= 3.0,
      'passesAAA': ratio >= 7.0,
      'recommendation': _getRecommendation(result),
    };
  }

  static String _getRecommendation(ContrastResult result) {
    switch (result) {
      case ContrastResult.excellent:
        return 'Excelente contraste - pode usar sem restrições';
      case ContrastResult.good:
        return 'Bom contraste - recomendado para uso geral';
      case ContrastResult.marginal:
        return 'Contraste marginal - usar apenas para textos grandes';
      case ContrastResult.poor:
        return 'Contraste insuficiente - não usar esta combinação';
    }
  }
}

/// Retorna a melhor cor de foreground (escura/clara) para garantir contraste
/// contra um background arbitrário.
///
/// Esta é a função principal de conveniência para uso em todo o app.
/// Usa um limiar simples de luminância para contraste consistente.
Color foregroundColorFor(Color background, {Color dark = Colors.black, Color light = Colors.white}) {
  return ColorContrast.bestTextColor(background, dark: dark, light: light);
}

/// Extensão para facilitar o uso de contraste em cores
extension ColorContrastExtension on Color {
  /// Retorna a melhor cor de texto para usar sobre esta cor
  Color get bestTextColor => ColorContrast.bestTextColor(this);

  /// Retorna a razão de contraste com outra cor
  double contrastWith(Color other) => ColorContrast.contrastRatio(this, other);

  /// Verifica se esta cor é clara
  bool get isLight => ColorContrast.isLightColor(this);

  /// Verifica se esta cor é escura
  bool get isDark => ColorContrast.isDarkColor(this);

  /// Verifica se tem contraste suficiente com outra cor
  bool hasContrastWith(Color other, {double minRatio = 4.5}) {
    return ColorContrast.hasMinimumContrast(this, other, minRatio: minRatio);
  }

  /// Retorna a cor de sucesso adequada para usar sobre esta cor
  Color get successColor => ColorContrast.successColorFor(this);

  /// Retorna a cor de erro adequada para usar sobre esta cor
  Color get errorColor => ColorContrast.errorColorFor(this);

  /// Retorna a cor de alerta adequada para usar sobre esta cor
  Color get warningColor => ColorContrast.warningColorFor(this);

  /// Retorna a cor de destaque adequada para usar sobre esta cor
  Color get accentColor => ColorContrast.accentColorFor(this);
}
