import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry contentPadding;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.contentPadding = const EdgeInsets.all(AppSpacing.md),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: titleStyle)),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: contentPadding,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: child,
        ),
      ],
    );
  }
}