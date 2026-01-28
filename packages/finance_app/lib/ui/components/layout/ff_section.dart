import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';

/// Widget para agrupar conteúdo em seções.
///
/// Exibe um título opcional com ícone e subtítulo,
/// seguido do conteúdo filho com espaçamento consistente.
class FFSection extends StatelessWidget {
  /// Título da seção (ex: "CONTA", "CONFIGURAÇÕES")
  final String? title;

  /// Ícone opcional à esquerda do título
  final IconData? icon;

  /// Subtítulo opcional abaixo do título
  final String? subtitle;

  /// Conteúdo da seção
  final Widget child;

  /// Espaçamento após a seção (padrão 32)
  final double bottomSpacing;

  /// Se o título deve ser em uppercase
  final bool uppercaseTitle;

  const FFSection({
    super.key,
    this.title,
    this.icon,
    this.subtitle,
    required this.child,
    this.bottomSpacing = AppSpacing.xxl,
    this.uppercaseTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          _buildSectionTitle(context, theme),
          SizedBox(height: subtitle != null ? AppSpacing.xs : AppSpacing.md),
        ],
        if (subtitle != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.md),
            child: Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
        child,
        SizedBox(height: bottomSpacing),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, ThemeData theme) {
    final displayTitle = uppercaseTitle ? title!.toUpperCase() : title!;

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            displayTitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
