import 'package:flutter/material.dart';
import '../../theme/app_radius.dart';

/// Densidade do dropdown
enum FFDropdownDensity {
  /// Regular (altura 48)
  regular,

  /// Compacto (altura 40)
  compact,
}

/// Item do dropdown
class FFDropdownItem<T> {
  /// Valor do item
  final T value;

  /// Label exibido
  final String label;

  /// Ícone opcional
  final IconData? icon;

  const FFDropdownItem({
    required this.value,
    required this.label,
    this.icon,
  });
}

/// Dropdown do FácilFin Design System.
///
/// Características:
/// - Estilo consistente com o DS
/// - Suporte a label
/// - Suporte a modo compacto
/// - Suporte a ícones nos itens
class FFDropdown<T> extends StatelessWidget {
  /// Valor selecionado
  final T? value;

  /// Itens do dropdown
  final List<FFDropdownItem<T>> items;

  /// Callback ao selecionar
  final ValueChanged<T?>? onChanged;

  /// Label do campo
  final String? label;

  /// Hint quando nenhum valor selecionado
  final String? hint;

  /// Densidade do campo
  final FFDropdownDensity density;

  /// Se deve expandir para largura total
  final bool expanded;

  /// Largura fixa (se não expandido)
  final double? width;

  /// Se o campo está habilitado
  final bool enabled;

  const FFDropdown({
    super.key,
    required this.value,
    required this.items,
    this.onChanged,
    this.label,
    this.hint,
    this.density = FFDropdownDensity.regular,
    this.expanded = true,
    this.width,
    this.enabled = true,
  });

  /// Factory para dropdown compacto
  factory FFDropdown.compact({
    Key? key,
    required T? value,
    required List<FFDropdownItem<T>> items,
    ValueChanged<T?>? onChanged,
    String? label,
    String? hint,
    bool expanded = true,
    double? width,
    bool enabled = true,
  }) {
    return FFDropdown<T>(
      key: key,
      value: value,
      items: items,
      onChanged: onChanged,
      label: label,
      hint: hint,
      density: FFDropdownDensity.compact,
      expanded: expanded,
      width: width,
      enabled: enabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final isCompact = density == FFDropdownDensity.compact;
    final height = isCompact ? 32.0 : 48.0;
    final fontSize = isCompact ? 12.0 : 14.0;
    final labelFontSize = isCompact ? 10.0 : 12.0;
    final iconSize = isCompact ? 16.0 : 20.0;

    Widget dropdown = Column(
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
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12),
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
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              hint: hint != null
                  ? Text(
                      hint!,
                      style: TextStyle(
                        fontSize: fontSize,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    )
                  : null,
              icon: Icon(
                Icons.expand_more,
                color: enabled
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                size: iconSize,
              ),
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
              dropdownColor: isDark
                  ? colorScheme.surfaceContainerHighest
                  : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              items: items.map((item) {
                return DropdownMenuItem<T>(
                  value: item.value,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.icon != null) ...[
                        Icon(
                          item.icon,
                          size: iconSize - 2,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          item.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
      ],
    );

    if (!expanded && width != null) {
      return SizedBox(width: width, child: dropdown);
    }

    return dropdown;
  }
}
