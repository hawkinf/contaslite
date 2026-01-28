import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import 'ff_summary_card.dart';

/// Linha de resumo financeiro combinado do FácilFin Design System.
///
/// Suporta 2 ou 3 cards com layout responsivo:
/// - Desktop: todos em linha
/// - Mobile estreito: wrap para múltiplas linhas
///
/// Exemplo de uso com 2 cards (API simplificada):
/// ```dart
/// FFSummaryRow(
///   receberValue: 'R$ 1.500,00',
///   receberForecast: 'R$ 2.000,00',
///   pagarValue: 'R$ 800,00',
///   pagarForecast: 'R$ 1.000,00',
/// )
/// ```
///
/// Exemplo de uso com lista customizada (2 ou 3 cards):
/// ```dart
/// FFSummaryRow.custom(
///   cards: [
///     FFSummaryCard.receber(value: 'R$ 1.000', forecast: 'R$ 1.500'),
///     FFSummaryCard.pagar(value: 'R$ 500', forecast: 'R$ 800'),
///     FFSummaryCard(title: 'SALDO', value: 'R$ 500', ...),
///   ],
/// )
/// ```
class FFSummaryRow extends StatelessWidget {
  /// Lista de cards a serem exibidos (2 ou 3)
  final List<Widget>? cards;

  /// Valor de recebimentos formatado (API simplificada)
  final String? receberValue;

  /// Previsão de recebimentos formatado
  final String? receberForecast;

  /// Valor de pagamentos formatado
  final String? pagarValue;

  /// Previsão de pagamentos formatado
  final String? pagarForecast;

  /// Modo compacto para headers colapsados
  final bool compact;

  /// Callback ao tocar no card de recebimentos
  final VoidCallback? onReceberTap;

  /// Callback ao tocar no card de pagamentos
  final VoidCallback? onPagarTap;

  /// Padding externo
  final EdgeInsetsGeometry? padding;

  /// Largura mínima para manter em linha (abaixo disso faz wrap)
  final double breakpointWidth;

  /// Gap entre cards
  final double? gap;

  /// Construtor com API simplificada para 2 cards (receber/pagar)
  const FFSummaryRow({
    super.key,
    required String this.receberValue,
    required String this.receberForecast,
    required String this.pagarValue,
    required String this.pagarForecast,
    this.compact = false,
    this.onReceberTap,
    this.onPagarTap,
    this.padding,
    this.breakpointWidth = 400,
    this.gap,
  }) : cards = null;

  /// Construtor com lista customizada de cards (2 ou 3)
  const FFSummaryRow.custom({
    super.key,
    required List<Widget> this.cards,
    this.compact = false,
    this.padding,
    this.breakpointWidth = 500,
    this.gap,
  })  : receberValue = null,
        receberForecast = null,
        pagarValue = null,
        pagarForecast = null,
        onReceberTap = null,
        onPagarTap = null;

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ??
        EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: compact ? 4 : AppSpacing.xs,
        );

    final effectiveGap = gap ?? (compact ? AppSpacing.sm : AppSpacing.md);

    // Se cards customizados foram fornecidos, usa-os
    final cardWidgets = cards ?? _buildDefaultCards();

    return Padding(
      padding: effectivePadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < breakpointWidth;
          final cardCount = cardWidgets.length;

          // Desktop ou largura suficiente: todos em linha
          if (!isNarrow || cardCount <= 2) {
            return Row(
              children: _buildRowChildren(cardWidgets, effectiveGap),
            );
          }

          // Mobile estreito com 3 cards: 2 em cima + 1 embaixo
          if (cardCount == 3) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: cardWidgets[0]),
                    SizedBox(width: effectiveGap),
                    Expanded(child: cardWidgets[1]),
                  ],
                ),
                SizedBox(height: effectiveGap),
                cardWidgets[2],
              ],
            );
          }

          // Fallback: coluna única
          return Column(
            children: cardWidgets
                .map((card) => Padding(
                      padding: EdgeInsets.only(bottom: effectiveGap),
                      child: card,
                    ))
                .toList(),
          );
        },
      ),
    );
  }

  List<Widget> _buildDefaultCards() {
    return [
      FFSummaryCard.receber(
        value: receberValue!,
        forecast: receberForecast!,
        compact: compact,
        onTap: onReceberTap,
      ),
      FFSummaryCard.pagar(
        value: pagarValue!,
        forecast: pagarForecast!,
        compact: compact,
        onTap: onPagarTap,
      ),
    ];
  }

  List<Widget> _buildRowChildren(List<Widget> cardWidgets, double gap) {
    final children = <Widget>[];
    for (int i = 0; i < cardWidgets.length; i++) {
      if (i > 0) {
        children.add(SizedBox(width: gap));
      }
      children.add(Expanded(child: cardWidgets[i]));
    }
    return children;
  }
}
