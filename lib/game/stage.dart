import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'constants.dart';

/// Escenario: ciudad de noche + calle.
class Stage extends PositionComponent {
  Stage() : super(size: Vector2(kArenaW * kWaves, kViewH), priority: -10);

  @override
  void render(Canvas c) {
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1A1240), Color(0xFFB04A6E)],
      ).createShader(Rect.fromLTWH(0, 0, size.x, kFloorTop));
    c.drawRect(Rect.fromLTWH(0, 0, size.x, kFloorTop), sky);

    final rnd = Random(7);
    final pBuilding = Paint()..color = const Color(0xFF241B3D);
    final pWindow = Paint()..color = const Color(0xFFFFE082);
    double x = 0;
    while (x < size.x) {
      final w = 60 + rnd.nextInt(80).toDouble();
      final h = 80 + rnd.nextInt(110).toDouble();
      c.drawRect(Rect.fromLTWH(x, kFloorTop - h, w, h), pBuilding);
      for (double wy = kFloorTop - h + 10; wy < kFloorTop - 14; wy += 22) {
        for (double wx = x + 8; wx < x + w - 10; wx += 16) {
          if (rnd.nextInt(3) > 0) c.drawRect(Rect.fromLTWH(wx, wy, 8, 12), pWindow);
        }
      }
      x += w + 6;
    }

    c.drawRect(Rect.fromLTWH(0, kFloorTop, size.x, kViewH - kFloorTop), Paint()..color = const Color(0xFF3B3B4F));
    final line = Paint()
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = 3;
    for (double lx = 0; lx < size.x; lx += 120) {
      c.drawLine(Offset(lx, 310), Offset(lx + 60, 310), line);
    }
  }
}
