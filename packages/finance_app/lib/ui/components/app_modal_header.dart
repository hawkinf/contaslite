import 'package:flutter/material.dart';
import '../../widgets/dialog_close_button.dart';
import '../theme/app_spacing.dart';

class AppModalHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final VoidCallback? onClose;
  final EdgeInsetsGeometry padding;
  final bool showDivider;

  const AppModalHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.onClose,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        );
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        );

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              )
            : null,
      ),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: titleStyle, overflow: TextOverflow.ellipsis),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: subtitleStyle, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              ...actions!,
            ],
            if (onClose != null) ...[
              const SizedBox(width: AppSpacing.sm),
              DialogCloseButton(onPressed: onClose!),
            ],
          ],
        ),
      ),
    );
  }
}
