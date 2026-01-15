import 'package:flutter/material.dart';

class AmexLogo extends StatelessWidget {
  final double width;
  final double height;

  const AmexLogo({
    super.key,
    this.width = 55,
    this.height = 35,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF006FCF),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: width * 0.08,
                vertical: height * 0.04,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(1),
              ),
              child: Text(
                'AMERICAN',
                style: TextStyle(
                  color: const Color(0xFF006FCF),
                  fontSize: height * 0.18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            SizedBox(height: height * 0.04),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: width * 0.12,
                vertical: height * 0.04,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(1),
              ),
              child: Text(
                'EXPRESS',
                style: TextStyle(
                  color: const Color(0xFF006FCF),
                  fontSize: height * 0.18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
