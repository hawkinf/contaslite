import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Tipo de badge
enum FFBadgeType {
  success,
  error,
  warning,
  info,
  neutral,
}

/// Badge de status do FácilFin Design System.
///
/// Usado para indicar status (success, error, warning, info, neutral).
/// - Fundo suave
/// - Texto legível
/// - Ícone opcional
class FFBadge extends StatelessWidget {
  /// Texto do badge
  final String label;

  /// Tipo do badge (define cores)
  final FFBadgeType type;

  /// Ícone opcional à esquerda
  final IconData? icon;

  /// Tamanho do texto (padrão 13)
  final double fontSize;

  /// Padding customizado
  final EdgeInsetsGeometry? padding;

  const FFBadge({
    super.key,
    required this.label,
    this.type = FFBadgeType.neutral,
    this.icon,
    this.fontSize = 13,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getBadgeColors(context);

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: colors.foregroundColor, size: fontSize + 5),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            label,
            style: TextStyle(
              color: colors.foregroundColor,
              fontWeight: FontWeight.w500,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeColors _getBadgeColors(BuildContext context) {
    final theme = Theme.of(context);

    switch (type) {
      case FFBadgeType.success:
        return _BadgeColors(
          backgroundColor: AppColors.success.withValues(alpha: 0.1),
          foregroundColor: AppColors.success,
        );
      case FFBadgeType.error:
        return _BadgeColors(
          backgroundColor: AppColors.error.withValues(alpha: 0.1),
          foregroundColor: AppColors.error,
        );
      case FFBadgeType.warning:
        return _BadgeColors(
          backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.1),
          foregroundColor: const Color(0xFFF59E0B),
        );
      case FFBadgeType.info:
        return _BadgeColors(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          foregroundColor: theme.colorScheme.primary,
        );
      case FFBadgeType.neutral:
        return _BadgeColors(
          backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        );
    }
  }

  /// Factory para badge de status de sincronização
  factory FFBadge.syncStatus({
    Key? key,
    required String label,
    required bool isSynced,
    bool isOffline = false,
    bool isError = false,
  }) {
    FFBadgeType type;
    IconData icon;

    if (isError) {
      type = FFBadgeType.error;
      icon = Icons.cloud_off;
    } else if (isOffline) {
      type = FFBadgeType.neutral;
      icon = Icons.cloud_off_outlined;
    } else if (isSynced) {
      type = FFBadgeType.success;
      icon = Icons.cloud_done;
    } else {
      type = FFBadgeType.info;
      icon = Icons.sync;
    }

    return FFBadge(
      key: key,
      label: label,
      type: type,
      icon: icon,
    );
  }
}

/// Cores internas do badge
class _BadgeColors {
  final Color backgroundColor;
  final Color foregroundColor;

  const _BadgeColors({
    required this.backgroundColor,
    required this.foregroundColor,
  });
}
