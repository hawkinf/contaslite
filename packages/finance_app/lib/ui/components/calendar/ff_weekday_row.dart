import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';

/// Linha de cabeçalho com dias da semana do FácilFin Design System.
///
/// Exibe DOM, SEG, TER, QUA, QUI, SEX, SAB com cores diferenciadas
/// para fins de semana.
///
/// Exemplo de uso:
/// ```dart
/// FFWeekdayRow(
///   weekdayLabels: ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB'],
/// )
/// ```
class FFWeekdayRow extends StatelessWidget {
  /// Rótulos dos dias da semana (7 itens)
  final List<String> weekdayLabels;

  /// Altura do cabeçalho
  final double height;

  /// Tamanho da fonte
  final double? fontSize;

  /// Espaçamento entre letras
  final double letterSpacing;

  /// Se deve destacar fins de semana em vermelho
  final bool highlightWeekends;

  /// Índices dos dias considerados fim de semana (0 = DOM, 6 = SAB por padrão)
  final Set<int> weekendIndices;

  /// Cor de fundo customizada
  final Color? backgroundColor;

  /// Se deve mostrar borda inferior
  final bool showBottomBorder;

  const FFWeekdayRow({
    super.key,
    this.weekdayLabels = const ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB'],
    this.height = 36,
    this.fontSize,
    this.letterSpacing = 0.5,
    this.highlightWeekends = true,
    this.weekendIndices = const {0, 6},
    this.backgroundColor,
    this.showBottomBorder = true,
  }) : assert(weekdayLabels.length == 7, 'weekdayLabels deve ter exatamente 7 itens');

  /// Factory para layout compacto (mobile)
  factory FFWeekdayRow.compact({
    Key? key,
    List<String> weekdayLabels = const ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'],
    bool highlightWeekends = true,
  }) {
    return FFWeekdayRow(
      key: key,
      weekdayLabels: weekdayLabels,
      height: 32,
      fontSize: 10,
      letterSpacing: 0.3,
      highlightWeekends: highlightWeekends,
    );
  }

  /// Factory para layout desktop (mais espaçoso)
  factory FFWeekdayRow.desktop({
    Key? key,
    List<String> weekdayLabels = const ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB'],
    bool highlightWeekends = true,
  }) {
    return FFWeekdayRow(
      key: key,
      weekdayLabels: weekdayLabels,
      height: 48,
      fontSize: 15,
      letterSpacing: 0.8,
      highlightWeekends: highlightWeekends,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveFontSize = fontSize ?? 11;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.surfaceContainerLow,
        border: showBottomBorder
            ? Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              )
            : null,
      ),
      child: Row(
        children: List.generate(7, (index) {
          final isWeekend = highlightWeekends && weekendIndices.contains(index);
          return Expanded(
            child: Center(
              child: Text(
                weekdayLabels[index],
                style: TextStyle(
                  fontSize: effectiveFontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: letterSpacing,
                  color: isWeekend
                      ? AppColors.error.withValues(alpha: 0.85)
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
