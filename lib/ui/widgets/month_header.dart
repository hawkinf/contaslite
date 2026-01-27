import 'package:flutter/material.dart';

/// Header de período padronizado (igual ao PeriodHeader de Contas).
///
/// Layout:
/// - Altura total: 56px (container)
/// - Pill interna: 44px de altura, centralizada
/// - Chevrons: IconButton com icon size 18, splashRadius 18, dentro da pill
/// - Título: titleMedium, fontWeight w600 (NÃO uppercase)
class MonthHeader extends StatelessWidget {
  final String title;
  @Deprecated('subtitle foi removido - header sempre 1 linha')
  final String? subtitle;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onTap;

  const MonthHeader({
    super.key,
    required this.title,
    @Deprecated('subtitle foi removido - header sempre 1 linha')
    this.subtitle,
    this.onPrevious,
    this.onNext,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: Center(
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: colorScheme.onSurfaceVariant, size: 18),
                splashRadius: 18,
                onPressed: onPrevious,
              ),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 18),
                splashRadius: 18,
                onPressed: onNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
