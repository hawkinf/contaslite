import 'package:flutter/material.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

class MiniChip extends StatelessWidget {
  final String label;
  final Color? textColor;
  final Color? backgroundColor;
  final IconData? icon;

  const MiniChip({
    super.key,
    required this.label,
    this.textColor,
    this.backgroundColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color resolvedBackground =
        backgroundColor ?? colorScheme.surfaceContainerHighest;
    final Color resolvedText = textColor ?? colorScheme.onSurfaceVariant;

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: resolvedBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: resolvedText),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: AppTextStyles.chip.copyWith(color: resolvedText),
          ),
        ],
      ),
    );
  }
}
