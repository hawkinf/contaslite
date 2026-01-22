import 'package:flutter/material.dart';

class MonthSelector extends StatefulWidget {
  final String monthLabel;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const MonthSelector({
    super.key,
    required this.monthLabel,
    this.onPrev,
    this.onNext,
  });

  @override
  State<MonthSelector> createState() => _MonthSelectorState();
}

class _MonthSelectorState extends State<MonthSelector> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final Color baseColor = const Color(0xFF9B7A6D);
    final Color pressedColor = const Color(0xFF8E6E62);
    final Color borderColor = const Color(0xFF2B1A14);
    final Color highlightColor = const Color(0xFFCDB7AD);
    final Color iconColor = const Color(0xFFF1F5F9);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _pressed ? pressedColor : baseColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(height: 1, color: highlightColor),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: iconColor, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.onPrev,
                  tooltip: 'Mes anterior',
                ),
                const SizedBox(width: 6),
                Text(
                  widget.monthLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: iconColor, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.onNext,
                  tooltip: 'Proximo mes',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
