import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Dialog de calculadora simples para ajudar no preenchimento de valores
class CalculatorDialog extends StatefulWidget {
  final double? initialValue;

  const CalculatorDialog({super.key, this.initialValue});

  @override
  State<CalculatorDialog> createState() => _CalculatorDialogState();
}

class _CalculatorDialogState extends State<CalculatorDialog> {
  String _display = '0';
  String _expression = '';
  double? _result;
  String? _lastOperator;
  bool _newNumber = true;

  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null && widget.initialValue! > 0) {
      _display = _formatNumber(widget.initialValue!);
      _result = widget.initialValue;
      _newNumber = true;
    }
  }

  String _formatNumber(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  void _onDigit(String digit) {
    setState(() {
      if (_newNumber) {
        _display = digit;
        _newNumber = false;
      } else {
        if (_display == '0' && digit != ',') {
          _display = digit;
        } else {
          _display += digit;
        }
      }
    });
  }

  void _onDecimal() {
    setState(() {
      if (_newNumber) {
        _display = '0,';
        _newNumber = false;
      } else if (!_display.contains(',')) {
        _display += ',';
      }
    });
  }

  void _onOperator(String op) {
    setState(() {
      _calculate();
      _lastOperator = op;
      _expression = '$_display $op';
      _newNumber = true;
    });
  }

  void _calculate() {
    if (_lastOperator == null || _result == null) {
      _result = _parseDisplay();
      return;
    }

    final currentValue = _parseDisplay();
    switch (_lastOperator) {
      case '+':
        _result = _result! + currentValue;
        break;
      case '-':
        _result = _result! - currentValue;
        break;
      case '×':
        _result = _result! * currentValue;
        break;
      case '÷':
        if (currentValue != 0) {
          _result = _result! / currentValue;
        }
        break;
    }
    _display = _formatNumber(_result!);
  }

  double _parseDisplay() {
    return double.tryParse(_display.replaceAll(',', '.')) ?? 0;
  }

  void _onEquals() {
    setState(() {
      _calculate();
      _lastOperator = null;
      _expression = '';
      _newNumber = true;
    });
  }

  void _onClear() {
    setState(() {
      _display = '0';
      _expression = '';
      _result = null;
      _lastOperator = null;
      _newNumber = true;
    });
  }

  void _onBackspace() {
    setState(() {
      if (_display.length > 1) {
        _display = _display.substring(0, _display.length - 1);
      } else {
        _display = '0';
        _newNumber = true;
      }
    });
  }

  void _useResult() {
    final value = _parseDisplay();
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget buildButton(String label, {VoidCallback? onPressed, Color? bgColor, Color? textColor, int flex = 1}) {
      return Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Material(
            color: bgColor ?? colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 52,
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: textTheme.titleLarge?.copyWith(
                    color: textColor ?? colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: colorScheme.surface,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.calculate, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Calculadora',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_expression.isNotEmpty)
                    Text(
                      _expression,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  Text(
                    _display,
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Buttons
            Row(
              children: [
                buildButton('C', onPressed: _onClear, bgColor: colorScheme.errorContainer, textColor: colorScheme.onErrorContainer),
                buildButton('⌫', onPressed: _onBackspace),
                buildButton('%', onPressed: () {
                  setState(() {
                    final val = _parseDisplay() / 100;
                    _display = _formatNumber(val);
                    _newNumber = true;
                  });
                }),
                buildButton('÷', onPressed: () => _onOperator('÷'), bgColor: colorScheme.primaryContainer, textColor: colorScheme.onPrimaryContainer),
              ],
            ),
            Row(
              children: [
                buildButton('7', onPressed: () => _onDigit('7')),
                buildButton('8', onPressed: () => _onDigit('8')),
                buildButton('9', onPressed: () => _onDigit('9')),
                buildButton('×', onPressed: () => _onOperator('×'), bgColor: colorScheme.primaryContainer, textColor: colorScheme.onPrimaryContainer),
              ],
            ),
            Row(
              children: [
                buildButton('4', onPressed: () => _onDigit('4')),
                buildButton('5', onPressed: () => _onDigit('5')),
                buildButton('6', onPressed: () => _onDigit('6')),
                buildButton('-', onPressed: () => _onOperator('-'), bgColor: colorScheme.primaryContainer, textColor: colorScheme.onPrimaryContainer),
              ],
            ),
            Row(
              children: [
                buildButton('1', onPressed: () => _onDigit('1')),
                buildButton('2', onPressed: () => _onDigit('2')),
                buildButton('3', onPressed: () => _onDigit('3')),
                buildButton('+', onPressed: () => _onOperator('+'), bgColor: colorScheme.primaryContainer, textColor: colorScheme.onPrimaryContainer),
              ],
            ),
            Row(
              children: [
                buildButton('0', onPressed: () => _onDigit('0'), flex: 2),
                buildButton(',', onPressed: _onDecimal),
                buildButton('=', onPressed: _onEquals, bgColor: colorScheme.primary, textColor: colorScheme.onPrimary),
              ],
            ),
            const SizedBox(height: 12),

            // Use result button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _useResult,
                icon: const Icon(Icons.check),
                label: Text('Usar ${_currencyFormat.format(_parseDisplay())}'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
