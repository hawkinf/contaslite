import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

class ActionBanner extends StatelessWidget {
  final Widget? leading;
  final IconData? leadingIcon;
  final String text;
  final List<Widget> actions;

  const ActionBanner({
    super.key,
    this.leading,
    this.leadingIcon,
    required this.text,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedLeading = leading ??
        Icon(
          leadingIcon ?? Icons.info_outline,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          resolvedLeading,
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          ...actions.expand(
            (action) => [
              const SizedBox(width: 4),
              action,
            ],
          ),
        ],
      ),
    );
  }
}
