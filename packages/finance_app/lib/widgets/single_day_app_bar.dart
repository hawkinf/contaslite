import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:finance_app/services/prefs_service.dart';

class SingleDayAppBar extends StatelessWidget implements PreferredSizeWidget {
  final DateTime date;
  final String? city;
  final List<Widget>? actions;
  final Widget? leading;
  final bool? centerTitle;
  final double? toolbarHeight;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final TextStyle? titleStyle;

  const SingleDayAppBar({
    super.key,
    required this.date,
    this.city,
    this.actions,
    this.leading,
    this.centerTitle,
    this.toolbarHeight,
    this.backgroundColor,
    this.foregroundColor,
    this.titleStyle,
  });

  @override
  Size get preferredSize =>
      PrefsService.embeddedMode ? Size.zero : Size.fromHeight(toolbarHeight ?? 80);

  @override
  Widget build(BuildContext context) {
    if (PrefsService.embeddedMode) {
      return const SizedBox.shrink();
    }

    final formatter = DateFormat('dd MMMM yyyy', 'pt_BR');
    final weekdayFormatter = DateFormat('EEEE', 'pt_BR');
    final label = formatter.format(date);
    final weekday = weekdayFormatter.format(date);
    final weekdayLabel = weekday.substring(0, 1).toUpperCase() + weekday.substring(1);

    return AppBar(
      automaticallyImplyLeading: false,
      centerTitle: centerTitle ?? true,
      toolbarHeight: preferredSize.height,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      leading: leading,
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.brown.shade300,
          border: Border.all(color: Colors.black, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$label - $weekdayLabel',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      actions: actions,
    );
  }
}
