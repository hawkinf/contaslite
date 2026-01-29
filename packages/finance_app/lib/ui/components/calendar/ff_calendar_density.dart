import 'package:flutter/material.dart';

/// Densidades de visualização do calendário.
///
/// Define tamanhos, espaçamentos e fontes para diferentes contextos de uso.
enum FFCalendarDensity {
  /// Layout compacto para mobile (telas < 600px)
  compact,

  /// Layout padrão para tablet (600px - 1100px)
  regular,

  /// Layout espaçoso para desktop (> 1100px)
  desktop,
}

/// Especificações de cada densidade
extension FFCalendarDensitySpecs on FFCalendarDensity {
  /// Altura da linha de weekdays
  double get weekdayRowHeight {
    switch (this) {
      case FFCalendarDensity.compact:
        return 32;
      case FFCalendarDensity.regular:
        return 36;
      case FFCalendarDensity.desktop:
        return 48;
    }
  }

  /// Tamanho da fonte dos weekdays
  double get weekdayFontSize {
    switch (this) {
      case FFCalendarDensity.compact:
        return 10;
      case FFCalendarDensity.regular:
        return 11;
      case FFCalendarDensity.desktop:
        return 15;
    }
  }

  /// Letter spacing dos weekdays
  double get weekdayLetterSpacing {
    switch (this) {
      case FFCalendarDensity.compact:
        return 0.3;
      case FFCalendarDensity.regular:
        return 0.5;
      case FFCalendarDensity.desktop:
        return 0.8;
    }
  }

  /// Tamanho da fonte do número do dia
  double get dayFontSize {
    switch (this) {
      case FFCalendarDensity.compact:
        return 14;
      case FFCalendarDensity.regular:
        return 16;
      case FFCalendarDensity.desktop:
        return 24;
    }
  }

  /// Margem do tile do dia
  EdgeInsets get dayTileMargin {
    switch (this) {
      case FFCalendarDensity.compact:
        return const EdgeInsets.all(1);
      case FFCalendarDensity.regular:
        return const EdgeInsets.all(2);
      case FFCalendarDensity.desktop:
        return const EdgeInsets.all(3);
    }
  }

  /// Padding interno do day tile
  double get dayTilePadding {
    switch (this) {
      case FFCalendarDensity.compact:
        return 2;
      case FFCalendarDensity.regular:
        return 4;
      case FFCalendarDensity.desktop:
        return 8;
    }
  }

  /// Altura da barra de totais
  double get totalsBarHeight {
    switch (this) {
      case FFCalendarDensity.compact:
        return 48;
      case FFCalendarDensity.regular:
        return 56;
      case FFCalendarDensity.desktop:
        return 64;
    }
  }

  /// Altura do mode selector
  double get modeSelectorHeight {
    switch (this) {
      case FFCalendarDensity.compact:
        return 40;
      case FFCalendarDensity.regular:
        return 48;
      case FFCalendarDensity.desktop:
        return 52;
    }
  }

  /// Se usa labels curtos no mode selector
  bool get useShortLabels => this == FFCalendarDensity.compact;

  /// Labels dos weekdays
  List<String> get weekdayLabels {
    switch (this) {
      case FFCalendarDensity.compact:
        return const ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
      case FFCalendarDensity.regular:
        return const ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB'];
      case FFCalendarDensity.desktop:
        return const ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB'];
    }
  }

  /// Detecta automaticamente a densidade com base na largura
  static FFCalendarDensity fromWidth(double width) {
    if (width >= 1100) return FFCalendarDensity.desktop;
    if (width >= 600) return FFCalendarDensity.regular;
    return FFCalendarDensity.compact;
  }
}
