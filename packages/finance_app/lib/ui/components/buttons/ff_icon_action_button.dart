import 'package:flutter/material.dart';

/// Botão de ícone com container arredondado do FácilFin Design System.
///
/// Características:
/// - Container com fundo colorido suave
/// - Tooltip obrigatório para acessibilidade
/// - Hover effect no desktop
/// - Tamanho consistente
class FFIconActionButton extends StatelessWidget {
  /// Ícone do botão
  final IconData icon;

  /// Tooltip obrigatório
  final String tooltip;

  /// Callback ao pressionar
  final VoidCallback? onPressed;

  /// Cor do ícone (padrão: primary)
  final Color? iconColor;

  /// Cor de fundo (padrão: iconColor com alpha 0.1)
  final Color? backgroundColor;

  /// Tamanho do container (padrão 40)
  final double size;

  /// Tamanho do ícone (padrão 20)
  final double iconSize;

  /// Se o botão está habilitado
  final bool enabled;

  const FFIconActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.iconColor,
    this.backgroundColor,
    this.size = 40,
    this.iconSize = 20,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = enabled
        ? (iconColor ?? theme.colorScheme.primary)
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);

    final effectiveBgColor = backgroundColor ??
        effectiveIconColor.withValues(alpha: 0.1);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: effectiveBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: effectiveIconColor,
            ),
          ),
        ),
      ),
    );
  }

  /// Factory para botão de perigo (ex: logout, delete)
  factory FFIconActionButton.danger({
    Key? key,
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
    double size = 40,
    double iconSize = 20,
    bool enabled = true,
  }) {
    return FFIconActionButton(
      key: key,
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      iconColor: const Color(0xFFDC2626), // AppColors.error
      backgroundColor: const Color(0xFFDC2626).withValues(alpha: 0.1),
      size: size,
      iconSize: iconSize,
      enabled: enabled,
    );
  }

  /// Factory para botão de sucesso
  factory FFIconActionButton.success({
    Key? key,
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
    double size = 40,
    double iconSize = 20,
    bool enabled = true,
  }) {
    return FFIconActionButton(
      key: key,
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      iconColor: const Color(0xFF16A34A), // AppColors.success
      backgroundColor: const Color(0xFF16A34A).withValues(alpha: 0.1),
      size: size,
      iconSize: iconSize,
      enabled: enabled,
    );
  }
}
