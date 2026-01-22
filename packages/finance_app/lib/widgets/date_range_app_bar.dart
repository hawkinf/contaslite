import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:finance_app/services/prefs_service.dart';
import 'package:finance_app/widgets/month_selector.dart';

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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: MonthSelector(
                      monthLabel: monthLabel,
                      onPrev: onPrevious,
                      onNext: onNext,
                    ),
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
          color: const Color(0xFFD6C7BC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF3A2F2A), width: 1),
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
            _buildSwitchRow(
              'Pagar',
              filterContasPagar,
              onFilterContasPagarChanged,
              const Color(0xFFDC2626),
              borderColor: const Color(0xFF991B1B),
              textColor: Colors.white,
            ),
            const SizedBox(height: 0),
            _buildSwitchRow(
              'Receber',
              filterContasReceber,
              onFilterContasReceberChanged,
              const Color(0xFF16A34A),
              borderColor: const Color(0xFF14532D),
              textColor: Colors.white,
            ),
            const SizedBox(height: 0),
            _buildSwitchRow(
              'Cartões',
              filterCartoes,
              onFilterCartoesChanged,
              const Color(0xFF1F2937),
              borderColor: const Color(0xFF111827),
              textColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow(
    String label,
    bool value,
    ValueChanged<bool>? onChanged,
    Color switchColor, {
    Color? borderColor,
    Color? textColor,
  }) {
    final Color resolvedTextColor = textColor ?? switchColor;
    final Color labelColor =
        value ? resolvedTextColor : resolvedTextColor.withValues(alpha: 0.7);

    final Color trackColor =
        value ? switchColor : const Color(0xFFCBD5E1);
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onChanged == null ? null : () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 30,
              height: 16,
              decoration: BoxDecoration(
                color: trackColor,
                border: Border.all(color: borderColor ?? switchColor, width: 1),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  alignment:
                      value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF94A3B8),
                        width: 0.7,
                      ),
                    ),
                  ),
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

