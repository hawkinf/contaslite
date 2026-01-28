import 'package:flutter/material.dart';
import 'ff_card_header_summary.dart';

/// Header de cartão colapsável do FácilFin Design System.
///
/// Envolve o FFCardHeaderSummary com animação suave entre
/// os estados expandido e compacto.
///
/// Exemplo de uso:
/// ```dart
/// FFCollapsibleCardHeader(
///   cardTitle: 'Nubank • Mastercard',
///   cardColor: Colors.purple,
///   cardBrand: 'Mastercard',
///   closingDate: DateTime(2024, 1, 25),
///   dueDate: DateTime(2024, 2, 1),
///   summary: FFCardInvoiceSummary(...),
///   isCollapsed: _isHeaderCollapsed,
///   onToggle: () => setState(() => _isHeaderCollapsed = !_isHeaderCollapsed),
/// )
/// ```
class FFCollapsibleCardHeader extends StatelessWidget {
  /// Título do cartão
  final String cardTitle;

  /// Cor do cartão
  final Color cardColor;

  /// Bandeira do cartão
  final String? cardBrand;

  /// Data de fechamento
  final DateTime closingDate;

  /// Data de vencimento
  final DateTime dueDate;

  /// Resumo da fatura
  final FFCardInvoiceSummary summary;

  /// Se o header está colapsado
  final bool isCollapsed;

  /// Callback ao alternar estado
  final VoidCallback? onToggle;

  /// Duração da animação
  final Duration animationDuration;

  /// Curva da animação
  final Curve animationCurve;

  /// Padding externo
  final EdgeInsetsGeometry? padding;

  const FFCollapsibleCardHeader({
    super.key,
    required this.cardTitle,
    required this.cardColor,
    this.cardBrand,
    required this.closingDate,
    required this.dueDate,
    required this.summary,
    this.isCollapsed = false,
    this.onToggle,
    this.animationDuration = const Duration(milliseconds: 250),
    this.animationCurve = Curves.easeInOut,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: animationDuration,
      switchInCurve: animationCurve,
      switchOutCurve: animationCurve,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1,
            child: child,
          ),
        );
      },
      child: isCollapsed
          ? KeyedSubtree(
              key: const ValueKey('compact'),
              child: FFCardHeaderSummary(
                cardTitle: cardTitle,
                cardColor: cardColor,
                cardBrand: cardBrand,
                closingDate: closingDate,
                dueDate: dueDate,
                summary: summary,
                compact: true,
                padding: padding,
                onTap: onToggle,
              ),
            )
          : KeyedSubtree(
              key: const ValueKey('expanded'),
              child: FFCardHeaderSummary(
                cardTitle: cardTitle,
                cardColor: cardColor,
                cardBrand: cardBrand,
                closingDate: closingDate,
                dueDate: dueDate,
                summary: summary,
                compact: false,
                padding: padding,
                onTap: onToggle,
              ),
            ),
    );
  }
}
