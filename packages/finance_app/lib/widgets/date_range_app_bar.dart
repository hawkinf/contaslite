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
              showFilters ? 96 : (toolbarHeight ?? (title == null ? 64 : 76)),
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

    final Color baseAppBarColor =
        backgroundColor ?? Theme.of(context).appBarTheme.backgroundColor ?? Colors.blue;
    final Color badgeFillColor =
        Color.lerp(baseAppBarColor, Colors.white, 0.28) ?? baseAppBarColor;
    final Widget? filtersBadge =
        showFilters ? _buildFiltersBadge(badgeFillColor) : null;

    return AppBar(
      centerTitle: true,
      toolbarHeight: preferredSize.height,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: 0,
      shape: const Border(
        bottom: BorderSide(color: Colors.black54, width: 1),
      ),
      leading: leading,
      title: const SizedBox.shrink(),
      flexibleSpace: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
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
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: badgeFillColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.black, width: 1),
                                boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  blurRadius: 2,
                                  offset: const Offset(-1, -1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                    icon: const Icon(Icons.chevron_left, size: 20, color: Colors.white),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: onPrevious,
                                  tooltip: 'Mês anterior',
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  monthLabel,
                                    style: defaultMonthStyle.copyWith(color: Colors.white),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                    icon: const Icon(Icons.chevron_right, size: 20, color: Colors.white),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: onNext,
                                  tooltip: 'Próximo mês',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (filtersBadge != null)
              Align(
                alignment: Alignment.centerLeft,
                child: filtersBadge,
              ),
          ],
        ),
      ),
      actions: actions ?? [],
    );
  }

  Widget _buildFiltersBadge(Color badgeFillColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: badgeFillColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.9),
              blurRadius: 2,
              offset: const Offset(-1, -1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSwitchRow('Pagar', filterContasPagar, onFilterContasPagarChanged, Colors.red),
            const SizedBox(height: 0),
            _buildSwitchRow('Receber', filterContasReceber, onFilterContasReceberChanged, Colors.green),
            const SizedBox(height: 0),
            _buildSwitchRow('Cartões', filterCartoes, onFilterCartoesChanged, Colors.black),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow(String label, bool value, ValueChanged<bool>? onChanged, Color switchColor) {
    final Color labelColor = value ? switchColor : switchColor.withValues(alpha: 0.6);

    return SizedBox(
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 16,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Transform.scale(
                scale: 0.6,
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
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: value ? FontWeight.w700 : FontWeight.w500,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}
