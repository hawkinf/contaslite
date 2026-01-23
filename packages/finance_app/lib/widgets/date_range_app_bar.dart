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
        : Size.fromHeight(toolbarHeight ?? (title == null ? 64 : 76));

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
      actions: actions ?? [],
    );
  }
}

