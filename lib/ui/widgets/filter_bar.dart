import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

class FilterBarOption {
  final String value;
  final String label;
  final IconData? icon;

  const FilterBarOption({
    required this.value,
    required this.label,
    this.icon,
  });
}

class FilterBar extends StatelessWidget {
  final List<FilterBarOption> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  const FilterBar({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SegmentedButton<String>(
      segments: [
        for (final option in options)
          ButtonSegment<String>(
            value: option.value,
            label: Text(option.label),
            icon: option.icon != null ? Icon(option.icon, size: 16) : null,
          ),
      ],
      selected: {selectedValue},
      onSelectionChanged: (value) {
        onSelected(value.first);
      },
      style: ButtonStyle(
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
        ),
        visualDensity: VisualDensity.compact,
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.onSurfaceVariant;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: 0.12);
          }
          return Colors.transparent;
        }),
        side: WidgetStateProperty.all(
          BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.35)),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
