import 'package:flutter/material.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Tipos de filtro de conta disponíveis
enum FFAccountFilterType { all, pagar, receber, cartoes }

/// Definição de um chip de filtro customizado
class FFFilterChipOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const FFFilterChipOption({
    required this.value,
    required this.label,
    this.icon,
  });
}

/// Barra de filtros com chips do FácilFin Design System.
///
/// Exibe chips de seleção para filtrar contas por tipo,
/// toggle para ocultar pagas, dropdown de período e trailing actions.
///
/// Suporta modo compacto e lista de filtros customizável.
///
/// Exemplo de uso básico:
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
///
/// Exemplo com filtros customizados e trailing:
/// ```dart
/// FFFilterChipsBar.custom<String>(
///   options: [
///     FFFilterChipOption(value: 'all', label: 'Todos'),
///     FFFilterChipOption(value: 'recorrente', label: 'Recorrência'),
///     FFFilterChipOption(value: 'avista', label: 'À vista'),
///     FFFilterChipOption(value: 'parcelado', label: 'Parcelado'),
///   ],
///   selected: 'all',
///   onSelected: (value) => setState(() => _filter = value),
///   trailing: IconButton(icon: Icon(Icons.refresh), onPressed: _refresh),
///   compact: true,
/// )
/// ```
class FFFilterChipsBar<T> extends StatelessWidget {
  /// Lista de opções de filtro customizadas
  final List<FFFilterChipOption<T>>? options;

  /// Filtro atualmente selecionado (usado com opções padrão)
  final FFAccountFilterType? selected;

  /// Valor selecionado (usado com opções customizadas)
  final T? selectedValue;

  /// Callback quando o filtro é alterado (opções padrão)
  final ValueChanged<FFAccountFilterType>? onSelected;

  /// Callback quando o filtro é alterado (opções customizadas)
  final ValueChanged<T>? onValueSelected;

  /// Se deve ocultar contas pagas/recebidas
  final bool hidePaid;

  /// Callback quando o toggle de pagas é alterado
  final ValueChanged<bool>? onHidePaidChanged;

  /// Valor atual do período
  final String periodValue;

  /// Callback quando o período é alterado
  final ValueChanged<String>? onPeriodChanged;

  /// Se deve mostrar o chip de contas pagas
  final bool showPaidChip;

  /// Se deve mostrar o dropdown de período
  final bool showPeriodDropdown;

  /// Modo compacto (altura menor, chips menores)
  final bool compact;

  /// Widget trailing (ex: botões de ação)
  final Widget? trailing;

  /// Padding interno
  final EdgeInsetsGeometry? padding;

  /// Construtor com filtros padrão (FFAccountFilterType)
  const FFFilterChipsBar({
    super.key,
    required FFAccountFilterType this.selected,
    required ValueChanged<FFAccountFilterType> this.onSelected,
    required this.hidePaid,
    required ValueChanged<bool> this.onHidePaidChanged,
    required this.periodValue,
    required ValueChanged<String> this.onPeriodChanged,
    this.showPaidChip = true,
    this.showPeriodDropdown = true,
    this.compact = false,
    this.trailing,
    this.padding,
  })  : options = null,
        selectedValue = null,
        onValueSelected = null;

  /// Construtor com filtros customizados
  const FFFilterChipsBar.custom({
    super.key,
    required List<FFFilterChipOption<T>> this.options,
    required T this.selectedValue,
    required ValueChanged<T> this.onValueSelected,
    this.hidePaid = false,
    this.onHidePaidChanged,
    this.periodValue = 'month',
    this.onPeriodChanged,
    this.showPaidChip = false,
    this.showPeriodDropdown = false,
    this.compact = false,
    this.trailing,
    this.padding,
  })  : selected = null,
        onSelected = null;

  double get _chipHeight => compact ? 26 : 30;
  double get _fontSize => compact ? 11 : 12;
  double get _iconSize => compact ? 14 : 16;
  EdgeInsets get _containerPadding => compact
      ? const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4)
      : const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectivePadding = padding ?? _containerPadding;

    return Container(
      padding: effectivePadding,
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
                children: _buildFilterChips(context),
              ),
            ),
          ),
          if (_hasSecondarySection) ...[
            SizedBox(width: compact ? AppSpacing.sm : AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _buildSecondarySection(context),
              ),
            ),
          ],
          if (trailing != null) ...[
            SizedBox(width: compact ? AppSpacing.sm : AppSpacing.md),
            trailing!,
          ],
        ],
      ),
    );
  }

  bool get _hasSecondarySection =>
      showPaidChip || showPeriodDropdown || onHidePaidChanged != null;

  List<Widget> _buildFilterChips(BuildContext context) {
    if (options != null) {
      return _buildCustomChips(context);
    }
    return _buildDefaultChips(context);
  }

  List<Widget> _buildDefaultChips(BuildContext context) {
    return [
      _buildChip(context, 'Todos', FFAccountFilterType.all),
      SizedBox(width: compact ? 4 : AppSpacing.sm),
      _buildChip(context, 'Pagar', FFAccountFilterType.pagar),
      SizedBox(width: compact ? 4 : AppSpacing.sm),
      _buildChip(context, 'Receber', FFAccountFilterType.receber),
      SizedBox(width: compact ? 4 : AppSpacing.sm),
      _buildChip(context, 'Cartões', FFAccountFilterType.cartoes),
    ];
  }

  List<Widget> _buildCustomChips(BuildContext context) {
    final chips = <Widget>[];
    for (int i = 0; i < options!.length; i++) {
      if (i > 0) {
        chips.add(SizedBox(width: compact ? 4 : AppSpacing.sm));
      }
      chips.add(_buildCustomChip(context, options![i]));
    }
    return chips;
  }

  List<Widget> _buildSecondarySection(BuildContext context) {
    final widgets = <Widget>[];

    if (showPaidChip && onHidePaidChanged != null) {
      widgets.add(_buildPaidChip(context));
    }

    if (showPeriodDropdown && onPeriodChanged != null) {
      if (widgets.isNotEmpty) {
        widgets.add(SizedBox(width: compact ? 4 : AppSpacing.sm));
      }
      widgets.add(_buildPeriodDropdown(context));
    }

    return widgets;
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
      height: _chipHeight,
      child: ChoiceChip(
        labelPadding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8),
        label: Text(
          label,
          style: TextStyle(
            fontSize: _fontSize,
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
        onSelected: (_) => onSelected?.call(type),
      ),
    );
  }

  Widget _buildCustomChip(BuildContext context, FFFilterChipOption<T> option) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isSelected = selectedValue == option.value;
    final Color textColor = isSelected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return SizedBox(
      height: _chipHeight,
      child: ChoiceChip(
        labelPadding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (option.icon != null) ...[
              Icon(option.icon, size: _iconSize, color: textColor),
              SizedBox(width: compact ? 4 : 6),
            ],
            Text(
              option.label,
              style: TextStyle(
                fontSize: _fontSize,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
        selected: isSelected,
        showCheckmark: false,
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.primaryContainer,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        shape: const StadiumBorder(),
        onSelected: (_) => onValueSelected?.call(option.value),
      ),
    );
  }

  Widget _buildPaidChip(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color textColor = hidePaid
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return SizedBox(
      height: _chipHeight,
      child: ChoiceChip(
        labelPadding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off_outlined, size: _iconSize, color: textColor),
            SizedBox(width: compact ? 4 : 6),
            Text(
              compact ? 'Pagas' : 'Contas Pagas',
              style: TextStyle(
                fontSize: _fontSize,
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
        onSelected: onHidePaidChanged ?? (_) {},
      ),
    );
  }

  Widget _buildPeriodDropdown(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dropdownWidth = compact ? 130.0 : 160.0;
    final dropdownHeight = compact ? 28.0 : 32.0;

    return Container(
      height: dropdownHeight,
      width: dropdownWidth,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
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
            if (value != null) onPeriodChanged?.call(value);
          },
          icon: Icon(
            Icons.arrow_drop_down,
            size: _iconSize,
            color: colorScheme.onSurfaceVariant,
          ),
          style: TextStyle(
            fontSize: _fontSize,
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
