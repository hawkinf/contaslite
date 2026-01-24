import 'package:flutter/material.dart';

class LaunchTypeSegmented extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final bool compact;

  const LaunchTypeSegmented({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(
          value: 0,
          label: Text('Avulsa / Parcelada', style: TextStyle(fontSize: 13)),
          icon: Icon(Icons.receipt_long, size: 18),
        ),
        ButtonSegment(
          value: 1,
          label: Text('Recorrente Fixa', style: TextStyle(fontSize: 13)),
          icon: Icon(Icons.loop, size: 18),
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
      style: ButtonStyle(
        visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 6 : 8),
        ),
        minimumSize: WidgetStatePropertyAll(Size(0, compact ? 36 : 40)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        side: WidgetStatePropertyAll(
          BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
    );
  }
}