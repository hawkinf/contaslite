import 'package:flutter/material.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Tipos de filtro de conta disponíveis
enum FFAccountFilterType { all, pagar, receber, cartoes }

/// Barra de filtros com chips do FácilFin Design System.
///
/// Exibe chips de seleção para filtrar contas por tipo,
/// toggle para ocultar pagas, e dropdown de período.
///
/// Exemplo de uso:
/// ```dart
/// FFFilterChipsBar(
///   selected: FFAccountFilterType.all,
///   onSelected: (type) => setState(() => _filter = type),
///   hidePaid: true,
///   onHidePaidChanged: (value) => setState(() => _hidePaid = value),
///   periodValue: 'month',
///   onPeriodChanged: (value) => setState(() => _period = value),
/// )
/// ```
class FFFilterChipsBar extends StatelessWidget {
  /// Filtro atualmente selecionado
  final FFAccountFilterType selected;

  /// Callback quando o filtro é alterado
  final ValueChanged<FFAccountFilterType> onSelected;

  /// Se deve ocultar contas pagas/recebidas
  final bool hidePaid;

  /// Callback quando o toggle de pagas é alterado
  final ValueChanged<bool> onHidePaidChanged;

  /// Valor atual do período
  final String periodValue;

  /// Callback quando o período é alterado
  final ValueChanged<String> onPeriodChanged;

  /// Se deve mostrar o chip de contas pagas
  final bool showPaidChip;

  /// Se deve mostrar o dropdown de período
  final bool showPeriodDropdown;

  const FFFilterChipsBar({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.hidePaid,
    required this.onHidePaidChanged,
    required this.periodValue,
    required this.onPeriodChanged,
    this.showPaidChip = true,
    this.showPeriodDropdown = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChip(context, 'Todos', FFAccountFilterType.all),
                  const SizedBox(width: AppSpacing.sm),
                  _buildChip(context, 'Pagar', FFAccountFilterType.pagar),
                  const SizedBox(width: AppSpacing.sm),
                  _buildChip(context, 'Receber', FFAccountFilterType.receber),
                  const SizedBox(width: AppSpacing.sm),
                  _buildChip(context, 'Cartões', FFAccountFilterType.cartoes),
                ],
              ),
            ),
          ),
          if (showPaidChip || showPeriodDropdown) ...[
            const SizedBox(width: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (showPaidChip) _buildPaidChip(context),
                  if (showPaidChip && showPeriodDropdown)
                    const SizedBox(width: AppSpacing.sm),
                  if (showPeriodDropdown) _buildPeriodDropdown(context),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context,
    String label,
    FFAccountFilterType type,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isSelected = selected == type;
    final Color textColor = isSelected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return SizedBox(
      height: 30,
      child: ChoiceChip(
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        selected: isSelected,
        showCheckmark: false,
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.primaryContainer,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        shape: const StadiumBorder(),
        onSelected: (_) => onSelected(type),
      ),
    );
  }

  Widget _buildPaidChip(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color textColor = hidePaid
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return SizedBox(
      height: 30,
      child: ChoiceChip(
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off_outlined, size: 16, color: textColor),
            const SizedBox(width: 6),
            Text(
              'Contas Pagas',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
        selected: hidePaid,
        showCheckmark: false,
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.primaryContainer,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        shape: const StadiumBorder(),
        onSelected: onHidePaidChanged,
      ),
    );
  }

  Widget _buildPeriodDropdown(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 32,
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: periodValue,
          isDense: true,
          isExpanded: true,
          onChanged: (value) {
            if (value != null) onPeriodChanged(value);
          },
          icon: Icon(
            Icons.arrow_drop_down,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurfaceVariant,
          ),
          items: const [
            DropdownMenuItem(value: 'today', child: Text('Hoje')),
            DropdownMenuItem(value: 'tomorrow', child: Text('Amanhã')),
            DropdownMenuItem(value: 'yesterday', child: Text('Ontem')),
            DropdownMenuItem(value: 'currentWeek', child: Text('Semana Atual')),
            DropdownMenuItem(value: 'nextWeek', child: Text('Próx. Semana')),
            DropdownMenuItem(value: 'month', child: Text('Mês Atual')),
          ],
        ),
      ),
    );
  }
}
