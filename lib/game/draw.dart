import 'dart:math';
import 'package:flutter/material.dart';

/// Dibuja un luchador con formas simples (sin sprites).
/// Para usar sprites propios, reemplaza esta función por tu SpriteComponent.
void drawFighter(
  Canvas c, {
  required double w,
  required double h,
  required Color body,
  required Color accent,
  required int facing,
  double attack = -1,
  double z = 0,
  bool flash = false,
  bool lying = false,
}) {
  // sombra
  c.drawOval(
    Rect.fromCenter(center: Offset(w / 2, h), width: w * 0.95, height: h * 0.12),
    Paint()..color = const Color(0x66000000),
  );
  c.save();
  if (lying) {
    c.translate(w / 2, h);
    c.rotate(pi / 2 * facing);
    c.translate(-w / 2, -h);
  }
  c.translate(0, -z);
  c.translate(w / 2, 0);
  c.scale(facing.toDouble(), 1);
  c.translate(-w / 2, 0);

  final Color main = flash ? Colors.white : body;
  final Color dark = flash ? Colors.white : Color.lerp(body, Colors.black, 0.4)!;
  final Color skin = flash ? Colors.white : const Color(0xFFF2C29B);
  final pMain = Paint()..color = main;
  final pDark = Paint()..color = dark;
  final pSkin = Paint()..color = skin;
  final pAcc = Paint()..color = accent;

  c.drawRect(Rect.fromLTWH(w * 0.2, h * 0.64, w * 0.24, h * 0.36), pDark);
  c.drawRect(Rect.fromLTWH(w * 0.54, h * 0.64, w * 0.24, h * 0.36), pDark);
  c.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.12, h * 0.30, w * 0.76, h * 0.38), const Radius.circular(6)),
    pMain,
  );
  c.drawRect(Rect.fromLTWH(w * 0.12, h * 0.58, w * 0.76, h * 0.06), pAcc);
  c.drawCircle(Offset(w * 0.5, h * 0.17), h * 0.14, pSkin);
  c.drawRect(Rect.fromLTWH(w * 0.5 - h * 0.14, h * 0.11, h * 0.28, h * 0.045), pAcc);
  c.drawCircle(Offset(w * 0.62, h * 0.17), 2, Paint()..color = Colors.black);

  if (attack >= 0) {
    final ext = sin(attack * pi);
    final len = w * 0.35 + w * 0.6 * ext;
    c.drawRect(Rect.fromLTWH(w * 0.6, h * 0.36, len, h * 0.09), pSkin);
    c.drawCircle(Offset(w * 0.6 + len, h * 0.405), h * 0.065, pAcc);
  } else {
    c.drawRect(Rect.fromLTWH(w * 0.68, h * 0.34, w * 0.16, h * 0.26), pSkin);
  }
  c.restore();
}
