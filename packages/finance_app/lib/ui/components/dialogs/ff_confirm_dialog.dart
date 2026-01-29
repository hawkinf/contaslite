import 'package:flutter/material.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../buttons/ff_primary_button.dart';
import '../buttons/ff_secondary_button.dart';

/// Diálogo de confirmação do FácilFin Design System.
///
/// Usado para confirmar ações destrutivas ou importantes.
///
/// Exemplo:
/// ```dart
/// final confirmed = await FFConfirmDialog.show(
///   context: context,
///   title: 'Excluir categoria?',
///   message: 'Esta ação não pode ser desfeita.',
///   confirmLabel: 'Excluir',
///   isDanger: true,
/// );
/// ```
class FFConfirmDialog extends StatelessWidget {
  /// Título do diálogo
  final String title;

  /// Mensagem de confirmação
  final String message;

  /// Label do botão de confirmação
  final String confirmLabel;

  /// Label do botão de cancelamento
  final String cancelLabel;

  /// Se é uma ação perigosa (botão vermelho)
  final bool isDanger;

  /// Ícone opcional
  final IconData? icon;

  const FFConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirmar',
    this.cancelLabel = 'Cancelar',
    this.isDanger = false,
    this.icon,
  });

  /// Exibe o diálogo e retorna true se confirmado
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirmar',
    String cancelLabel = 'Cancelar',
    bool isDanger = false,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => FFConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDanger: isDanger,
        icon: icon,
      ),
    );
    return result ?? false;
  }

  /// Factory para confirmação de exclusão
  static Future<bool> showDelete({
    required BuildContext context,
    required String itemName,
    String? customMessage,
  }) {
    return show(
      context: context,
      title: 'Excluir "$itemName"?',
      message: customMessage ?? 'Esta ação não pode ser desfeita.',
      confirmLabel: 'Excluir',
      isDanger: true,
      icon: Icons.delete_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      backgroundColor: isDark ? colorScheme.surface : Colors.white,
      elevation: isDark ? 0 : 8,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon
              Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDanger
                            ? Colors.red.withValues(alpha: 0.1)
                            : colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        icon,
                        color: isDanger ? Colors.red : colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // Message
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FFSecondaryButton(
                    label: cancelLabel,
                    onPressed: () => Navigator.of(context).pop(false),
                    expanded: false,
                    height: 40,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _ConfirmButton(
                    label: confirmLabel,
                    isDanger: isDanger,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botão de confirmação (pode ser danger ou primary)
class _ConfirmButton extends StatelessWidget {
  final String label;
  final bool isDanger;
  final VoidCallback onPressed;

  const _ConfirmButton({
    required this.label,
    required this.isDanger,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (isDanger) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    return FFPrimaryButton(
      label: label,
      onPressed: onPressed,
      expanded: false,
      height: 40,
    );
  }
}
