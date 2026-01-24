import 'package:flutter/material.dart';
class DialogCloseButton extends StatelessWidget {
  const DialogCloseButton({
    super.key,
    required this.onPressed,
    this.size = 34,
    this.useBackground = true,
  });

  final VoidCallback onPressed;
  final double size;
  final bool useBackground;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = useBackground
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
        : Colors.transparent;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.close,
            color: colorScheme.onSurfaceVariant,
            size: size <= 32 ? 18 : 20,
          ),
        ),
      ),
    );
  }
}
