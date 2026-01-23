import 'package:flutter/material.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'status_indicator.dart';

class EntryCard extends StatelessWidget {
  final Widget datePill;
  final String title;
  final String subtitle;
  final String value;
  final Color valueColor;
  final List<Widget> chips;
  final VoidCallback? onEdit;
  final Widget? trailing;
  final Color accentColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final List<BoxShadow> boxShadow;
  final EdgeInsetsGeometry padding;

  const EntryCard({
    super.key,
    required this.datePill,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.valueColor,
    required this.chips,
    required this.accentColor,
    this.onEdit,
    this.trailing,
    this.backgroundColor,
    this.borderColor,
    this.boxShadow = const [],
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color resolvedBackground =
        backgroundColor ?? colorScheme.surfaceContainerLow;
    final Color resolvedBorder = borderColor ?? colorScheme.outlineVariant;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: resolvedBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: resolvedBorder),
        boxShadow: boxShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusIndicator.bar(color: accentColor),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              datePill,
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.title.copyWith(fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: AppTextStyles.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: chips,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusIndicator.dot(color: valueColor, size: 6),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        value,
                        style: AppTextStyles.value.copyWith(
                          fontSize: 16,
                          color: valueColor,
                        ),
                      ),
                    ],
                  ),
                  if (trailing != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    trailing!,
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
