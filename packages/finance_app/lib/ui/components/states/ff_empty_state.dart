import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Estado vazio do FácilFin Design System.
///
/// Exibe uma mensagem quando não há dados para mostrar,
/// com ícone, título, descrição e ação opcional.
///
/// Exemplo de uso:
/// ```dart
/// FFEmptyState(
///   icon: Icons.receipt_long_outlined,
///   title: 'Nenhum lançamento',
///   description: 'Não há lançamentos para este período.',
///   actionLabel: 'Adicionar',
///   onAction: () => _addAccount(),
/// )
/// ```
class FFEmptyState extends StatelessWidget {
  /// Ícone principal
  final IconData icon;

  /// Título da mensagem
  final String title;

  /// Descrição adicional
  final String? description;

  /// Label do botão de ação
  final String? actionLabel;

  /// Callback do botão de ação
  final VoidCallback? onAction;

  /// Cor do ícone
  final Color? iconColor;

  /// Tamanho do ícone
  final double iconSize;

  /// Padding externo
  final EdgeInsetsGeometry padding;

  const FFEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.iconSize = 64,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });

  /// Factory para lista de contas vazia
  factory FFEmptyState.contas({
    Key? key,
    String? description,
    VoidCallback? onAction,
  }) {
    return FFEmptyState(
      key: key,
      icon: Icons.receipt_long_outlined,
      title: 'Nenhum lançamento',
      description: description ?? 'Não há lançamentos para este período.',
      actionLabel: onAction != null ? 'Adicionar' : null,
      onAction: onAction,
    );
  }

  /// Factory para lista de recebimentos vazia
  factory FFEmptyState.recebimentos({
    Key? key,
    String? description,
    VoidCallback? onAction,
  }) {
    return FFEmptyState(
      key: key,
      icon: Icons.trending_up_outlined,
      title: 'Nenhum recebimento',
      description: description ?? 'Não há recebimentos para este período.',
      actionLabel: onAction != null ? 'Adicionar' : null,
      onAction: onAction,
      iconColor: AppColors.success,
    );
  }

  /// Factory para lista de pagamentos vazia
  factory FFEmptyState.pagamentos({
    Key? key,
    String? description,
    VoidCallback? onAction,
  }) {
    return FFEmptyState(
      key: key,
      icon: Icons.trending_down_outlined,
      title: 'Nenhum pagamento',
      description: description ?? 'Não há pagamentos para este período.',
      actionLabel: onAction != null ? 'Adicionar' : null,
      onAction: onAction,
      iconColor: AppColors.error,
    );
  }

  /// Factory para busca sem resultados
  factory FFEmptyState.semResultados({
    Key? key,
    String? description,
  }) {
    return FFEmptyState(
      key: key,
      icon: Icons.search_off_outlined,
      title: 'Sem resultados',
      description: description ?? 'Nenhum item corresponde à sua busca.',
    );
  }

  /// Factory para erro de carregamento
  factory FFEmptyState.erro({
    Key? key,
    String? description,
    VoidCallback? onRetry,
  }) {
    return FFEmptyState(
      key: key,
      icon: Icons.error_outline,
      title: 'Erro ao carregar',
      description: description ?? 'Não foi possível carregar os dados.',
      actionLabel: onRetry != null ? 'Tentar novamente' : null,
      onAction: onRetry,
      iconColor: AppColors.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveIconColor =
        iconColor ?? colorScheme.onSurfaceVariant.withValues(alpha: 0.5);

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: effectiveIconColor,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                description!,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
