import 'package:flutter/material.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'ff_card.dart';

/// Card informativo do FácilFin Design System.
///
/// Layout horizontal com:
/// - leading (logo ou ícone em container)
/// - title (texto principal)
/// - subtitle(s) (textos secundários)
///
/// Usado para: Sobre o App, informações do usuário, etc.
class FFInfoCard extends StatelessWidget {
  /// Widget leading (logo, ícone, avatar)
  final Widget leading;

  /// Título principal
  final String title;

  /// Subtítulo primário
  final String? subtitle;

  /// Subtítulo secundário
  final String? secondarySubtitle;

  /// Widget trailing opcional
  final Widget? trailing;

  /// Callback ao tocar no card
  final VoidCallback? onTap;

  /// Padding interno customizado
  final EdgeInsetsGeometry? padding;

  const FFInfoCard({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.secondarySubtitle,
    this.trailing,
    this.onTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FFCard(
      onTap: onTap,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          leading,
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
                if (secondarySubtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    secondarySubtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }

  /// Factory para criar um card de "Sobre o App"
  factory FFInfoCard.about({
    Key? key,
    required Widget logo,
    required String appName,
    required String version,
    String? developer,
    VoidCallback? onTap,
  }) {
    return FFInfoCard(
      key: key,
      leading: logo,
      title: appName,
      subtitle: version,
      secondarySubtitle: developer != null ? 'Desenvolvido por $developer' : null,
      onTap: onTap,
    );
  }
}

/// Container padrão para ícones/logos em FFInfoCard
class FFInfoCardLeading extends StatelessWidget {
  /// Widget filho (ícone, imagem, etc)
  final Widget child;

  /// Tamanho do container
  final double size;

  /// Border radius
  final double borderRadius;

  /// Cor de fundo
  final Color? backgroundColor;

  const FFInfoCardLeading({
    super.key,
    required this.child,
    this.size = 56,
    this.borderRadius = AppRadius.md,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = backgroundColor ??
        theme.colorScheme.primaryContainer.withValues(alpha: 0.3);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: bgColor,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      ),
    );
  }
}
