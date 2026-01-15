import 'dart:math' as math;
import 'package:flutter/material.dart';

class MastercardLogo extends StatelessWidget {
  final double width;
  final double height;

  const MastercardLogo({
    super.key,
    this.width = 55,
    this.height = 35,
  });

  @override
  Widget build(BuildContext context) {
    final double diameter = math.min(height, width * 0.7);
    final double overlap = diameter * 0.35;

    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _circle(const Color(0xFFEB001B), diameter),
            Transform.translate(
              offset: Offset(-overlap, 0),
              child: _circle(const Color(0xFFF79E1B), diameter),
            ),
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
