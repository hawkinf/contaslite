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
    return Image.asset(
      'assets/icons/cc_mc.png',
      package: 'finance_app',
      width: width,
      height: height,
      fit: BoxFit.contain,
    );
  }
}
