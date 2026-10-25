import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Fondo azul con pinceladas de colores en las esquinas (como el diseño).
class Fondo extends StatelessWidget {
  final Widget child;
  final bool pinceladas;
  const Fondo({super.key, required this.child, this.pinceladas = true});

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E34A8), Tg.azul, Color(0xFF081F6E)],
          ),
        ),
      ),
      if (pinceladas)
        const RepaintBoundary(
          child: CustomPaint(painter: _PincelPainter(), size: Size.infinite),
        ),
      child,
    ]);
  }
}

class _PincelPainter extends CustomPainter {
  const _PincelPainter();

  /// Un trazo de pincel: línea gruesa con "pelos" más finos alrededor.
  /// x, y van en fracción del ANCHO; con [abajo] la y se mide desde el borde inferior.
  void _t(Canvas c, Size s, double x1, double y1, double x2, double y2,
      double g, Color color,
      {bool abajo = false}) {
    final w = s.width;
    final a = Offset(x1 * w, abajo ? s.height - y1 * w : y1 * w);
    final b = Offset(x2 * w, abajo ? s.height - y2 * w : y2 * w);
    final grueso = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = g * w;
    c.drawLine(a, b, grueso);

    final d = b - a;
    final len = d.distance;
    if (len == 0) return;
    final n = Offset(-d.dy / len, d.dx / len);
    final pelo = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = g * w * 0.12;
    for (var i = -2; i <= 2; i++) {
      final o = n * (i * g * w * 0.2);
      c.drawLine(a + o - d * 0.06, b + o + d * 0.09, pelo);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Textura: rayas diagonales muy suaves.
    final raya = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 2;
    for (double x = -size.height; x < size.width; x += 38) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), raya);
    }

    // Arriba
    _t(canvas, size, -0.04, 0.07, 0.28, 0.0, 0.06, Tg.amarillo);
    _t(canvas, size, 0.12, 0.04, 0.40, -0.005, 0.03, Tg.rosa);
    _t(canvas, size, 0.86, 0.0, 1.04, 0.05, 0.04, const Color(0xFF2EAD5B));
    _t(canvas, size, 0.93, 0.16, 1.06, 0.12, 0.025, Tg.naranja);
    // Abajo
    _t(canvas, size, -0.04, 0.05, 0.30, 0.02, 0.06, Tg.amarillo, abajo: true);
    _t(canvas, size, 0.33, 0.02, 0.65, 0.045, 0.04, const Color(0xFF2EAD5B), abajo: true);
    _t(canvas, size, 0.62, 0.04, 1.04, 0.0, 0.05, Tg.rosa, abajo: true);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
