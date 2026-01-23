import 'package:flutter/material.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class MiniChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final Color? textColor;
  final Color? backgroundColor;
  final Color? borderColor;

  const MiniChip({
    super.key,
    required this.label,
    this.icon,
    this.iconColor,
    this.textColor,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color resolvedBackground =
      backgroundColor ?? colorScheme.surfaceContainerHighest;
    final Color? resolvedBorder = borderColor;
    final Color resolvedText = textColor ?? colorScheme.onSurfaceVariant;
    final Color resolvedIcon = iconColor ?? resolvedText;

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: resolvedBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: resolvedBorder == null
            ? null
            : Border.all(color: resolvedBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: resolvedIcon),
            const SizedBox(width: AppSpacing.xs),
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
