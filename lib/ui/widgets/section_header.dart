import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;

  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(
          title,
          style: AppTextStyles.label.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}
