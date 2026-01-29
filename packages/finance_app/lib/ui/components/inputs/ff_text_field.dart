import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_radius.dart';

/// Densidade do campo de texto
enum FFTextFieldDensity {
  /// Regular (altura 48)
  regular,

  /// Compacto (altura 40)
  compact,
}

/// Campo de texto do FácilFin Design System.
///
/// Características:
/// - Estilo consistente com o DS
/// - Suporte a label
/// - Suporte a prefixo/sufixo
/// - Suporte a modo compacto
class FFTextField extends StatelessWidget {
  /// Controller do campo
  final TextEditingController? controller;

  /// Label do campo
  final String? label;

  /// Placeholder/hint
  final String? hint;

  /// Ícone de prefixo
  final Widget? prefix;

  /// Ícone de sufixo
  final Widget? suffix;

  /// Tipo de teclado
  final TextInputType? keyboardType;

  /// Formatadores de input
  final List<TextInputFormatter>? inputFormatters;

  /// Se é somente leitura
  final bool readOnly;

  /// Callback ao mudar texto
  final ValueChanged<String>? onChanged;

  /// Callback ao submeter
  final ValueChanged<String>? onSubmitted;

  /// Densidade do campo
  final FFTextFieldDensity density;

  /// Alinhamento do texto
  final TextAlign textAlign;

  /// Se deve expandir para largura total
  final bool expanded;

  /// Largura fixa (se não expandido)
  final double? width;

  /// Se o campo está habilitado
  final bool enabled;

  /// Focus node
  final FocusNode? focusNode;

  const FFTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.inputFormatters,
    this.readOnly = false,
    this.onChanged,
    this.onSubmitted,
    this.density = FFTextFieldDensity.regular,
    this.textAlign = TextAlign.start,
    this.expanded = true,
    this.width,
    this.enabled = true,
    this.focusNode,
  });

  /// Factory para campo compacto
  factory FFTextField.compact({
    Key? key,
    TextEditingController? controller,
    String? label,
    String? hint,
    Widget? prefix,
    Widget? suffix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    TextAlign textAlign = TextAlign.start,
    bool expanded = true,
    double? width,
    bool enabled = true,
    FocusNode? focusNode,
  }) {
    return FFTextField(
      key: key,
      controller: controller,
      label: label,
      hint: hint,
      prefix: prefix,
      suffix: suffix,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      readOnly: readOnly,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      density: FFTextFieldDensity.compact,
      textAlign: textAlign,
      expanded: expanded,
      width: width,
      enabled: enabled,
      focusNode: focusNode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isCompact = density == FFTextFieldDensity.compact;
    final height = isCompact ? 32.0 : 48.0;
    final fontSize = isCompact ? 12.0 : 14.0;
    final labelFontSize = isCompact ? 10.0 : 12.0;

    Widget field = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: labelFontSize,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: isCompact ? 2 : 6),
        ],
        Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: enabled
                  ? colorScheme.outlineVariant.withValues(alpha: 0.6)
                  : colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            color: enabled
                ? (isDark ? colorScheme.surfaceContainerHighest : Colors.white)
                : colorScheme.surfaceContainerLow,
          ),
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (prefix != null)
                Padding(
                  padding: EdgeInsets.only(left: isCompact ? 8 : 12),
                  child: prefix,
                ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  readOnly: readOnly,
                  enabled: enabled,
                  textAlign: textAlign,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      fontSize: fontSize,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 8 : 12,
                    ),
                    isDense: true,
                  ),
                ),
              ),
              if (suffix != null)
                Padding(
                  padding: EdgeInsets.only(right: isCompact ? 8 : 12),
                  child: suffix,
                ),
            ],
          ),
        ),
      ],
    );

    if (!expanded && width != null) {
      return SizedBox(width: width, child: field);
    }

    return field;
  }
}

/// Campo numérico com botões de incremento/decremento
class FFNumberField extends StatelessWidget {
  /// Controller do campo
  final TextEditingController controller;

  /// Label do campo
  final String? label;

  /// Valor mínimo
  final int min;

  /// Valor máximo
  final int max;

  /// Callback ao mudar valor
  final ValueChanged<int>? onChanged;

  /// Densidade do campo
  final FFTextFieldDensity density;

  const FFNumberField({
    super.key,
    required this.controller,
    this.label,
    this.min = 1,
    this.max = 9999,
    this.onChanged,
    this.density = FFTextFieldDensity.regular,
  });

  /// Factory para campo compacto
  factory FFNumberField.compact({
    Key? key,
    required TextEditingController controller,
    String? label,
    int min = 1,
    int max = 9999,
    ValueChanged<int>? onChanged,
  }) {
    return FFNumberField(
      key: key,
      controller: controller,
      label: label,
      min: min,
      max: max,
      onChanged: onChanged,
      density: FFTextFieldDensity.compact,
    );
  }

  void _increment() {
    final current = int.tryParse(controller.text) ?? min;
    if (current < max) {
      controller.text = (current + 1).toString();
      onChanged?.call(current + 1);
    }
  }

  void _decrement() {
    final current = int.tryParse(controller.text) ?? min;
    if (current > min) {
      controller.text = (current - 1).toString();
      onChanged?.call(current - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isCompact = density == FFTextFieldDensity.compact;
    final height = isCompact ? 32.0 : 48.0;
    final iconSize = isCompact ? 14.0 : 18.0;
    final fontSize = isCompact ? 12.0 : 14.0;
    final labelFontSize = isCompact ? 10.0 : 12.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: labelFontSize,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: isCompact ? 2 : 6),
        ],
        Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
            color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIconButton(
                icon: Icons.remove,
                onTap: _decrement,
                colorScheme: colorScheme,
                iconSize: iconSize,
                isCompact: isCompact,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onChanged: (value) {
                    final intValue = int.tryParse(value);
                    if (intValue != null) {
                      onChanged?.call(intValue);
                    }
                  },
                ),
              ),
              _buildIconButton(
                icon: Icons.add,
                onTap: _increment,
                colorScheme: colorScheme,
                iconSize: iconSize,
                isCompact: isCompact,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    required double iconSize,
    required bool isCompact,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          width: isCompact ? 28 : 36,
          height: double.infinity,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: iconSize,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
