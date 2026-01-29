import 'package:flutter/material.dart';

/// Modos de visualização do calendário
enum FFCalendarViewMode {
  /// Visualização semanal
  weekly,

  /// Visualização mensal
  monthly,

  /// Visualização anual
  yearly,
}

/// Extensão para labels dos modos
extension FFCalendarViewModeExtension on FFCalendarViewMode {
  String get label {
    switch (this) {
      case FFCalendarViewMode.weekly:
        return 'Semanal';
      case FFCalendarViewMode.monthly:
        return 'Mensal';
      case FFCalendarViewMode.yearly:
        return 'Anual';
    }
  }

  String get shortLabel {
    switch (this) {
      case FFCalendarViewMode.weekly:
        return 'Sem';
      case FFCalendarViewMode.monthly:
        return 'Mês';
      case FFCalendarViewMode.yearly:
        return 'Ano';
    }
  }
}

/// Seletor de modo do calendário do FácilFin Design System.
///
/// Permite alternar entre os modos semanal, mensal e anual
/// com animação suave de transição.
///
/// Exemplo de uso:
/// ```dart
/// FFCalendarModeSelector(
///   currentMode: FFCalendarViewMode.monthly,
///   onModeChanged: (mode) => setState(() => _viewMode = mode),
/// )
/// ```
class FFCalendarModeSelector extends StatelessWidget {
  /// Modo atual selecionado
  final FFCalendarViewMode currentMode;

  /// Callback quando o modo é alterado
  final ValueChanged<FFCalendarViewMode> onModeChanged;

  /// Altura do container
  final double height;

  /// Se deve usar labels curtos (para mobile)
  final bool useShortLabels;

  /// Padding interno dos botões
  final EdgeInsetsGeometry? buttonPadding;

  /// Cor de fundo do container
  final Color? backgroundColor;

  /// Se deve mostrar borda inferior
  final bool showBottomBorder;

  const FFCalendarModeSelector({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    this.height = 48,
    this.useShortLabels = false,
    this.buttonPadding,
    this.backgroundColor,
    this.showBottomBorder = true,
  });

  /// Factory para layout compacto (mobile)
  factory FFCalendarModeSelector.compact({
    Key? key,
    required FFCalendarViewMode currentMode,
    required ValueChanged<FFCalendarViewMode> onModeChanged,
  }) {
    return FFCalendarModeSelector(
      key: key,
      currentMode: currentMode,
      onModeChanged: onModeChanged,
      height: 40,
      useShortLabels: true,
      buttonPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.surfaceContainerLow,
        border: showBottomBorder
            ? Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              )
            : null,
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: FFCalendarViewMode.values.map((mode) {
              return _buildModeButton(context, mode, colorScheme);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(
    BuildContext context,
    FFCalendarViewMode mode,
    ColorScheme colorScheme,
  ) {
    final isSelected = currentMode == mode;
    final label = useShortLabels ? mode.shortLabel : mode.label;
    final effectivePadding = buttonPadding ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 6);

    return GestureDetector(
      onTap: () => onModeChanged(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: effectivePadding,
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
