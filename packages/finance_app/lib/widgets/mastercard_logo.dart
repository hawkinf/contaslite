import 'package:flutter/material.dart';

class MastercardLogo extends StatelessWidget {
  final double width;
  final double height;

  const MastercardLogo({
    super.key,
    this.width = 28,
    this.height = 18,
  });

  @override
  Widget build(BuildContext context) {
    final circleSize = height;
    final overlap = circleSize * 0.55;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: circleSize,
              height: circleSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFEB001B),
              ),
            ),
          ),
          Positioned(
            left: overlap,
            top: 0,
            child: Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF79E1B).withOpacity(0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
