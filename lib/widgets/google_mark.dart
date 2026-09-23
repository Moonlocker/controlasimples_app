import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Desenha o logotipo "G" multicolorido oficial do Google.
///
/// Usa os mesmos traçados SVG usados no sistema web, sem depender de assets ou
/// pacotes externos. As cores seguem as diretrizes de marca do Google.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const _GoogleMarkPainter(),
      child: const SizedBox.square(dimension: 20),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()..style = PaintingStyle.fill;
    for (final (color, data) in _parts) {
      paint.color = color;
      canvas.drawPath(_parsePath(data), paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

  static const List<(Color, String)> _parts = [
    (Color(0xFF4285F4), _blue),
    (Color(0xFF34A853), _green),
    (Color(0xFFFBBC05), _yellow),
    (Color(0xFFEA4335), _red),
  ];

  // Traçados oficiais do "G" do Google em uma grade 24x24.
  static const _blue =
      'M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1Z';
  static const _green =
      'M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.99.66-2.26 1.06-3.71 1.06a6.06 6.06 0 0 1-5.66-4.18H2.02v2.84C3.84 20.53 7.6 23 12 23Z';
  static const _yellow =
      'M6.34 14.45a6.36 6.36 0 0 1 0-4.1V7.51H2.02a10.5 10.5 0 0 0 0 8.98l4.32-4.04Z';
  static const _red =
      'M12 5.38c1.62 0 3.06.56 4.21 1.64l3.16-3.16A9.47 9.47 0 0 0 12 1C7.6 1 3.84 3.47 2.02 7.51l4.32 3.84A6.06 6.06 0 0 1 12 5.38Z';

  /// Parser mínimo de caminho SVG (M/L/H/V/C/S/Q/T/A/Z, maiúsculas e
  /// minúsculas) suficiente para os traçados oficiais do Google.
  static Path _parsePath(String d) {
    final tokens = <String>[
      for (final m in RegExp(
        r'([a-zA-Z])|(-?\d*\.?\d+(?:[eE][-+]?\d+)?)',
      ).allMatches(d))
        m.group(0)!,
    ];

    final path = Path();
    var i = 0;
    var x = 0.0, y = 0.0;
    var startX = 0.0, startY = 0.0;
    var cmd = 'M';
    var lastCubicCx = 0.0, lastCubicCy = 0.0;
    var lastQuadCx = 0.0, lastQuadCy = 0.0;
    var wasCubic = false, wasQuad = false;

    double num() => double.parse(tokens[i++]);

    while (i < tokens.length) {
      final token = tokens[i];
      if (RegExp(r'^[a-zA-Z]$').hasMatch(token)) {
        cmd = token;
        i++;
      }
      final relative = cmd == cmd.toLowerCase();
      final op = cmd.toUpperCase()[0];

      switch (op) {
        case 'M':
          x = relative ? x + num() : num();
          y = relative ? y + num() : num();
          path.moveTo(x, y);
          startX = x;
          startY = y;
          cmd = relative ? 'l' : 'L';
          wasCubic = false;
          wasQuad = false;
          break;

        case 'L':
          x = relative ? x + num() : num();
          y = relative ? y + num() : num();
          path.lineTo(x, y);
          wasCubic = false;
          wasQuad = false;
          break;

        case 'H':
          x = relative ? x + num() : num();
          path.lineTo(x, y);
          wasCubic = false;
          wasQuad = false;
          break;

        case 'V':
          y = relative ? y + num() : num();
          path.lineTo(x, y);
          wasCubic = false;
          wasQuad = false;
          break;

        case 'C':
          final cx1 = relative ? x + num() : num();
          final cy1 = relative ? y + num() : num();
          lastCubicCx = relative ? x + num() : num();
          lastCubicCy = relative ? y + num() : num();
          x = relative ? x + num() : num();
          y = relative ? y + num() : num();
          path.cubicTo(cx1, cy1, lastCubicCx, lastCubicCy, x, y);
          wasCubic = true;
          wasQuad = false;
          break;

        case 'S':
          final cx1 = wasCubic ? 2 * x - lastCubicCx : x;
          final cy1 = wasCubic ? 2 * y - lastCubicCy : y;
          lastCubicCx = relative ? x + num() : num();
          lastCubicCy = relative ? y + num() : num();
          x = relative ? x + num() : num();
          y = relative ? y + num() : num();
          path.cubicTo(cx1, cy1, lastCubicCx, lastCubicCy, x, y);
          wasCubic = true;
          wasQuad = false;
          break;

        case 'Q':
          lastQuadCx = relative ? x + num() : num();
          lastQuadCy = relative ? y + num() : num();
          x = relative ? x + num() : num();
          y = relative ? y + num() : num();
          path.quadraticBezierTo(lastQuadCx, lastQuadCy, x, y);
          wasQuad = true;
          wasCubic = false;
          break;

        case 'T':
          final cx1 = wasQuad ? 2 * x - lastQuadCx : x;
          final cy1 = wasQuad ? 2 * y - lastQuadCy : y;
          x = relative ? x + num() : num();
          y = relative ? y + num() : num();
          path.quadraticBezierTo(cx1, cy1, x, y);
          wasQuad = true;
          wasCubic = false;
          break;

        case 'A':
          final rx = num();
          final ry = num();
          final rotation = num() * math.pi / 180;
          final largeArc = num() != 0;
          final clockwise = num() != 0;
          final ex = relative ? x + num() : num();
          final ey = relative ? y + num() : num();
          final end = Offset(ex, ey);
          if (rx > 0 && ry > 0) {
            if (end == Offset(x, y)) {
              path.lineTo(ex, ey);
            } else {
              path.arcToPoint(
                end,
                radius: Radius.elliptical(rx, ry),
                rotation: rotation,
                largeArc: largeArc,
                clockwise: clockwise,
              );
            }
          } else {
            path.lineTo(ex, ey);
          }
          x = ex;
          y = ey;
          wasCubic = false;
          wasQuad = false;
          break;

        case 'Z':
          path.close();
          x = startX;
          y = startY;
          wasCubic = false;
          wasQuad = false;
          break;
      }
    }

    return path;
  }
}
