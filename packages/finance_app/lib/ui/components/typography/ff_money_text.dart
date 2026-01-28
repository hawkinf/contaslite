import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';

/// Widget para exibir valores monetários do FácilFin Design System.
///
/// Características:
/// - Formatação automática para Real brasileiro
/// - Cor por sinal (verde para positivo, vermelho para negativo)
/// - Peso tipográfico correto
/// - Suporte a valor oculto
class FFMoneyText extends StatelessWidget {
  /// Valor monetário
  final double value;

  /// Tamanho da fonte (padrão 16)
  final double fontSize;

  /// Peso da fonte (padrão bold)
  final FontWeight fontWeight;

  /// Se deve colorir baseado no sinal
  final bool colorBySig;

  /// Cor positiva customizada
  final Color? positiveColor;

  /// Cor negativa customizada
  final Color? negativeColor;

  /// Cor neutra (quando não colorBySign)
  final Color? neutralColor;

  /// Se deve mostrar o sinal de + para valores positivos
  final bool showPositiveSign;

  /// Se o valor está oculto
  final bool hidden;

  /// Texto a exibir quando oculto (padrão: ••••••)
  final String hiddenText;

  /// Símbolo da moeda (padrão: R$)
  final String currencySymbol;

  /// Alinhamento do texto
  final TextAlign? textAlign;

  const FFMoneyText({
    super.key,
    required this.value,
    this.fontSize = 16,
    this.fontWeight = FontWeight.bold,
    this.colorBySig = true,
    this.positiveColor,
    this.negativeColor,
    this.neutralColor,
    this.showPositiveSign = false,
    this.hidden = false,
    this.hiddenText = '••••••',
    this.currencySymbol = 'R\$',
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (hidden) {
      return Text(
        '$currencySymbol $hiddenText',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: neutralColor ?? theme.colorScheme.onSurface,
        ),
        textAlign: textAlign,
      );
    }

    final color = _getColor(context);
    final formattedValue = _formatValue();

    return Text(
      formattedValue,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      ),
      textAlign: textAlign,
    );
  }

  Color _getColor(BuildContext context) {
    final theme = Theme.of(context);

    if (!colorBySig) {
      return neutralColor ?? theme.colorScheme.onSurface;
    }

    if (value > 0) {
      return positiveColor ?? AppColors.success;
    } else if (value < 0) {
      return negativeColor ?? AppColors.error;
    } else {
      return neutralColor ?? theme.colorScheme.onSurface;
    }
  }

  String _formatValue() {
    final formatter = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: currencySymbol,
      decimalDigits: 2,
    );

    if (showPositiveSign && value > 0) {
      return '+${formatter.format(value)}';
    }

    return formatter.format(value);
  }

  /// Factory para valor de entrada (sempre verde)
  factory FFMoneyText.income({
    Key? key,
    required double value,
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.bold,
    bool hidden = false,
  }) {
    return FFMoneyText(
      key: key,
      value: value.abs(),
      fontSize: fontSize,
      fontWeight: fontWeight,
      colorBySig: false,
      neutralColor: AppColors.success,
      showPositiveSign: true,
      hidden: hidden,
    );
  }

  /// Factory para valor de despesa (sempre vermelho)
  factory FFMoneyText.expense({
    Key? key,
    required double value,
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.bold,
    bool hidden = false,
  }) {
    return FFMoneyText(
      key: key,
      value: -value.abs(),
      fontSize: fontSize,
      fontWeight: fontWeight,
      colorBySig: false,
      neutralColor: AppColors.error,
      hidden: hidden,
    );
  }

  /// Factory para valor neutro (cor padrão do tema)
  factory FFMoneyText.neutral({
    Key? key,
    required double value,
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.bold,
    bool hidden = false,
  }) {
    return FFMoneyText(
      key: key,
      value: value,
      fontSize: fontSize,
      fontWeight: fontWeight,
      colorBySig: false,
      hidden: hidden,
    );
  }
}
