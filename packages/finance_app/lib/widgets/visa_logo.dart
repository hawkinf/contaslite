import 'package:flutter/material.dart';

class VisaLogo extends StatelessWidget {
  final double width;
  final double height;

  const VisaLogo({
    super.key,
    this.width = 55,
    this.height = 35,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _VisaPainter(),
      ),
    );
  }
}

class _VisaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Cor azul da Visa
    paint.color = const Color(0xFF1434CB);

    // Desenhar retângulo de fundo azul
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );

    // Desenhar detalhe laranja no canto superior esquerdo
    paint.color = const Color(0xFFFFA200);
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width * 0.25, 0);
    path.lineTo(0, size.height * 0.35);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
