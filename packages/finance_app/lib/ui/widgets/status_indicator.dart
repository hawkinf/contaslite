import 'package:flutter/material.dart';
import '../theme/app_radius.dart';

enum StatusIndicatorVariant { dot, bar }

class StatusIndicator extends StatelessWidget {
  final Color color;
  final StatusIndicatorVariant variant;
  final double size;
  final double thickness;

  const StatusIndicator.dot({
    super.key,
    required this.color,
    this.size = 6,
  })  : variant = StatusIndicatorVariant.dot,
        thickness = 0;

  const StatusIndicator.bar({
    super.key,
    required this.color,
    this.thickness = 3,
  })  : variant = StatusIndicatorVariant.bar,
        size = 0;

  @override
  Widget build(BuildContext context) {
    switch (variant) {
      case StatusIndicatorVariant.dot:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        );
      case StatusIndicatorVariant.bar:
        return Container(
          height: thickness,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        );
    }
  }
}
