import 'dart:math' as math;
import 'package:flutter/material.dart';

class EloLogo extends StatelessWidget {
  final double width;
  final double height;

  const EloLogo({
    super.key,
    this.width = 55,
    this.height = 35,
  });

  @override
  Widget build(BuildContext context) {
    final double diameter = math.min(height, width * 0.35);
    final double spacing = diameter * 0.15;

    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _circle(const Color(0xFF0066CC), diameter),
            SizedBox(width: spacing),
            _circle(const Color(0xFFFFCC00), diameter),
            SizedBox(width: spacing),
            _circle(const Color(0xFFFF0000), diameter),
          ],
        ),
      ),
    );
  }

  Widget _circle(Color color, double diameter) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
