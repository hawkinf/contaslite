import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_radius.dart';

/// Header de grupo de data do FácilFin Design System.
///
/// Exibe um título formatado com data e dia da semana,
/// ícone opcional e badge com quantidade de itens.
///
/// Exemplo de uso:
/// ```dart
/// FFDateGroupHeader(
///   date: DateTime.now(),
///   itemCount: 5,
/// )
/// ```
class FFDateGroupHeader extends StatelessWidget {
  /// Data do grupo
  final DateTime date;

  /// Quantidade de itens no grupo
  final int itemCount;

  /// Título customizado (sobrescreve formatação automática)
  final String? title;

  /// Ícone do header
  final IconData icon;

  /// Widget trailing customizado (sobrescreve badge de contagem)
  final Widget? trailing;

  /// Margem externa
  final EdgeInsetsGeometry margin;

  /// Padding interno
  final EdgeInsetsGeometry padding;

  const FFDateGroupHeader({
    super.key,
    required this.date,
    this.itemCount = 0,
    this.title,
    this.icon = Icons.calendar_today,
    this.trailing,
    this.margin = const EdgeInsets.fromLTRB(16, 10, 16, 8),
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final formattedTitle = title ?? _formatGroupLabel(date);

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant, size: 14),
          const SizedBox(width: 8),
          Text(
            formattedTitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
              letterSpacing: 0.4,
            ),
          ),
          const Spacer(),
          trailing ?? _buildCountBadge(context),
        ],
      ),
    );
  }

  Widget _buildCountBadge(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = itemCount == 1 ? '1 item' : '$itemCount itens';

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  String _formatGroupLabel(DateTime date) {
    final dateLabel = DateFormat('dd/MM/yyyy').format(date);
    final dayOfWeek = DateFormat('EEEE', 'pt_BR').format(date).toUpperCase();
    return '$dateLabel • $dayOfWeek';
  }
}
