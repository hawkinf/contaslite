import 'package:flutter/material.dart';

/// Densidade de componentes de entidade do FácilFin Design System.
///
/// Controla alturas, paddings e tamanhos de fonte para diferentes contextos.
enum FFEntityDensity {
  /// Compacto - para listas densas e telas menores
  compact,

  /// Regular - uso padrão
  regular,

  /// Desktop - para telas grandes com mais espaço
  desktop,
}

/// Especificações de densidade para componentes de entidade
extension FFEntityDensitySpecs on FFEntityDensity {
  /// Altura do item de lista
  double get listItemHeight {
    switch (this) {
      case FFEntityDensity.compact:
        return 48.0;
      case FFEntityDensity.regular:
        return 56.0;
      case FFEntityDensity.desktop:
        return 64.0;
    }
  }

  /// Altura da barra de ações
  double get actionsBarHeight {
    switch (this) {
      case FFEntityDensity.compact:
        return 40.0;
      case FFEntityDensity.regular:
        return 48.0;
      case FFEntityDensity.desktop:
        return 56.0;
    }
  }

  /// Tamanho da fonte do título
  double get titleFontSize {
    switch (this) {
      case FFEntityDensity.compact:
        return 14.0;
      case FFEntityDensity.regular:
        return 15.0;
      case FFEntityDensity.desktop:
        return 16.0;
    }
  }

  /// Tamanho da fonte do subtítulo
  double get subtitleFontSize {
    switch (this) {
      case FFEntityDensity.compact:
        return 11.0;
      case FFEntityDensity.regular:
        return 12.0;
      case FFEntityDensity.desktop:
        return 13.0;
    }
  }

  /// Tamanho do ícone
  double get iconSize {
    switch (this) {
      case FFEntityDensity.compact:
        return 18.0;
      case FFEntityDensity.regular:
        return 20.0;
      case FFEntityDensity.desktop:
        return 24.0;
    }
  }

  /// Tamanho do container leading
  double get leadingSize {
    switch (this) {
      case FFEntityDensity.compact:
        return 32.0;
      case FFEntityDensity.regular:
        return 40.0;
      case FFEntityDensity.desktop:
        return 48.0;
    }
  }

  /// Padding horizontal
  double get horizontalPadding {
    switch (this) {
      case FFEntityDensity.compact:
        return 12.0;
      case FFEntityDensity.regular:
        return 16.0;
      case FFEntityDensity.desktop:
        return 24.0;
    }
  }

  /// Padding vertical
  double get verticalPadding {
    switch (this) {
      case FFEntityDensity.compact:
        return 8.0;
      case FFEntityDensity.regular:
        return 12.0;
      case FFEntityDensity.desktop:
        return 16.0;
    }
  }

  /// Altura do botão
  double get buttonHeight {
    switch (this) {
      case FFEntityDensity.compact:
        return 36.0;
      case FFEntityDensity.regular:
        return 40.0;
      case FFEntityDensity.desktop:
        return 48.0;
    }
  }
}

/// Helper para detectar densidade automaticamente
class FFEntityDensityHelper {
  FFEntityDensityHelper._();

  /// Detecta densidade baseada na largura da tela
  static FFEntityDensity fromWidth(double width) {
    if (width < 600) return FFEntityDensity.compact;
    if (width < 1200) return FFEntityDensity.regular;
    return FFEntityDensity.desktop;
  }

  /// Detecta densidade a partir do contexto
  static FFEntityDensity fromContext(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return fromWidth(width);
  }
}
