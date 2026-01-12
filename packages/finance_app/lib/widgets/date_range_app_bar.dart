import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:finance_app/services/prefs_service.dart';
import 'sync_status_indicator.dart';

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
  });

  @override
  Size get preferredSize =>
      PrefsService.embeddedMode && title == null
          ? Size.zero
          : Size.fromHeight(
              toolbarHeight ?? (title == null ? 64 : 76),
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
        actions: [
          const SyncStatusIndicator(),
          if (actions != null) ...actions!,
        ],
      );
    }

    final monthLabel =
        DateFormat('MMMM yyyy', 'pt_BR').format(range.start).toUpperCase();
    final defaultMonthStyle = monthStyle ??
        const TextStyle(fontSize: 24, fontWeight: FontWeight.bold);

    return AppBar(
      centerTitle: centerTitle ?? true,
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
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 28),
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
                icon: const Icon(Icons.chevron_right, size: 28),
                onPressed: onNext,
                tooltip: 'Próximo mês',
              ),
            ],
          ),
        ],
      ),
      actions: [
        const SyncStatusIndicator(),
        if (actions != null) ...actions!,
      ],
    );
  }
}
