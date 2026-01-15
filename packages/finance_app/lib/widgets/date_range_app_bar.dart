import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:finance_app/services/prefs_service.dart';

class DateRangeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final DateTimeRange range;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final String? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool? centerTitle;
  final double? toolbarHeight;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final TextStyle? titleStyle;
  final TextStyle? monthStyle;
  
  // Filtros de switches
  final bool showFilters;
  final bool filterContasPagar;
  final bool filterContasReceber;
  final bool filterCartoes;
  final ValueChanged<bool>? onFilterContasPagarChanged;
  final ValueChanged<bool>? onFilterContasReceberChanged;
  final ValueChanged<bool>? onFilterCartoesChanged;

  const DateRangeAppBar({
    super.key,
    required this.range,
    this.onPrevious,
    this.onNext,
    this.title,
    this.actions,
    this.leading,
    this.centerTitle,
    this.toolbarHeight,
    this.backgroundColor,
    this.foregroundColor,
    this.titleStyle,
    this.monthStyle,
    this.showFilters = false,
    this.filterContasPagar = true,
    this.filterContasReceber = true,
    this.filterCartoes = true,
    this.onFilterContasPagarChanged,
    this.onFilterContasReceberChanged,
    this.onFilterCartoesChanged,
  });

  @override
  Size get preferredSize =>
      PrefsService.embeddedMode && title == null
          ? Size.zero
          : Size.fromHeight(
              showFilters ? 80 : (toolbarHeight ?? (title == null ? 64 : 76)),
            );

  @override
  Widget build(BuildContext context) {
    if (PrefsService.embeddedMode && title == null) {
      return const SizedBox.shrink();
    }

    final defaultTitleStyle = titleStyle ??
        const TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

    if (PrefsService.embeddedMode) {
      return AppBar(
        centerTitle: centerTitle ?? true,
        toolbarHeight: toolbarHeight ?? kToolbarHeight,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        leading: leading,
        title: Text(
          title ?? '',
          style: defaultTitleStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: actions ?? [],
      );
    }

    final monthLabel =
        DateFormat('MMMM yyyy', 'pt_BR').format(range.start).toUpperCase();
    final effectiveForegroundColor = foregroundColor ?? Theme.of(context).appBarTheme.foregroundColor ?? Colors.white;
    final defaultMonthStyle = monthStyle ??
        TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: effectiveForegroundColor);

    return AppBar(
      centerTitle: true,
      toolbarHeight: preferredSize.height,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      leading: leading,
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (title != null)
            Text(
              title!,
              style: defaultTitleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, size: 28, color: effectiveForegroundColor),
                onPressed: onPrevious,
                tooltip: 'Mês anterior',
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    monthLabel,
                    style: defaultMonthStyle,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, size: 28, color: effectiveForegroundColor),
                onPressed: onNext,
                tooltip: 'Próximo mês',
              ),
            ],
          ),
          if (showFilters)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSwitchRow('Pagar', filterContasPagar, onFilterContasPagarChanged, Colors.red),
                  const SizedBox(width: 16),
                  _buildSwitchRow('Receber', filterContasReceber, onFilterContasReceberChanged, Colors.blue),
                  const SizedBox(width: 16),
                  _buildSwitchRow('Cartões', filterCartoes, onFilterCartoesChanged, Colors.white),
                ],
              ),
            ),
        ],
      ),
      actions: actions ?? [],
    );
  }
  
  Widget _buildSwitchRow(String label, bool value, ValueChanged<bool>? onChanged, Color switchColor) {
    return SizedBox(
      height: 28,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 20,
            child: Transform.scale(
              scale: 0.7,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: switchColor,
                activeTrackColor: switchColor.withValues(alpha: 0.5),
                inactiveThumbColor: switchColor.withValues(alpha: 0.4),
                inactiveTrackColor: switchColor.withValues(alpha: 0.2),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: value ? FontWeight.bold : FontWeight.normal,
              color: value ? switchColor : switchColor.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
