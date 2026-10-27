import 'package:flutter/material.dart';

/// App icon artwork: a guitar pick with strings on a warm rounded square.
/// Drawn in code so launcher PNGs can be regenerated (tool/generate_icons).
class AppIconArt extends StatelessWidget {
  const AppIconArt({super.key, this.size = 96, this.foregroundOnly = false});

  final double size;

  /// Android adaptive icon foreground: pick only, transparent, shrunk into
  /// the 66/108 safe zone (the launcher supplies the background and mask).
  final bool foregroundOnly;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _IconPainter(foregroundOnly: foregroundOnly),
  );
}

class _IconPainter extends CustomPainter {
  _IconPainter({required this.foregroundOnly});

  final bool foregroundOnly;

  @override
  void paint(Canvas canvas, Size size) {
    if (foregroundOnly) {
      const safe = 66 / 108;
      canvas
        ..translate(size.width * (1 - safe) / 2, size.height * (1 - safe) / 2)
        ..scale(safe);
      _paintPick(canvas, size.width);
      return;
    }
    final s = size.width;
    final rect = Offset.zero & size;

    // Background: rounded square with a warm diagonal gradient.
    final bg = RRect.fromRectAndRadius(rect, Radius.circular(s * 0.22));
    canvas.drawRRect(
      bg,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8A3D), Color(0xFFB8360F)],
        ).createShader(rect),
    );

    _paintPick(canvas, s);
  }

  void _paintPick(Canvas canvas, double s) {
    // Pick: rounded triangle pointing down.
    final pick = Path()
      ..moveTo(s * 0.50, s * 0.86)
      ..cubicTo(s * 0.30, s * 0.70, s * 0.14, s * 0.46, s * 0.16, s * 0.30)
      ..cubicTo(s * 0.18, s * 0.16, s * 0.34, s * 0.12, s * 0.50, s * 0.12)
      ..cubicTo(s * 0.66, s * 0.12, s * 0.82, s * 0.16, s * 0.84, s * 0.30)
      ..cubicTo(s * 0.86, s * 0.46, s * 0.70, s * 0.70, s * 0.50, s * 0.86)
      ..close();
    canvas.drawShadow(pick, Colors.black, s * 0.03, false);
    canvas.drawPath(pick, Paint()..color = const Color(0xFFFFF4EC));

    // Strings across the pick, thicker at the bottom like a real guitar.
    canvas
      ..save()
      ..clipPath(pick);
    for (var i = 0; i < 6; i++) {
      final y = s * (0.24 + i * 0.09);
      canvas.drawLine(
        Offset(0, y),
        Offset(s, y),
        Paint()
          ..color = const Color(0xFFB8360F)
          ..strokeWidth = s * (0.012 + i * 0.005),
      );
    }
    canvas.restore();

    // Hit dot on the third string, as in the game.
    canvas.drawCircle(
      Offset(s * 0.5, s * 0.42),
      s * 0.075,
      Paint()..color = const Color(0xFFFFC107),
    );
  }

  @override
  bool shouldRepaint(_IconPainter oldDelegate) =>
      oldDelegate.foregroundOnly != foregroundOnly;
}
