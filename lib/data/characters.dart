import 'package:flutter/material.dart';

/// ============================================================
///  PERSONAJES (generados al azar). CAMBIA AQUÍ nombres, colores
///  y estadísticas cuando quieras.
/// ============================================================
class CharacterDef {
  final String id;
  final String name;
  final String title;
  final Color color;
  final Color accent;
  final double maxHp;
  final double speed;
  final double damage;
  final double reach;
  const CharacterDef({
    required this.id,
    required this.name,
    required this.title,
    required this.color,
    required this.accent,
    required this.maxHp,
    required this.speed,
    required this.damage,
    required this.reach,
  });
}

const List<CharacterDef> kCharacters = [
  CharacterDef(
    id: 'c1', name: 'RAYO', title: 'Veloz y ágil',
    color: Color(0xFF29B6F6), accent: Color(0xFFFFEB3B),
    maxHp: 90, speed: 190, damage: 8, reach: 46,
  ),
  CharacterDef(
    id: 'c2', name: 'TITÁN', title: 'Pesado y fuerte',
    color: Color(0xFFE53935), accent: Color(0xFFFFFFFF),
    maxHp: 140, speed: 120, damage: 14, reach: 54,
  ),
  CharacterDef(
    id: 'c3', name: 'LUNA', title: 'Alcance largo',
    color: Color(0xFF8E24AA), accent: Color(0xFFFF80AB),
    maxHp: 100, speed: 160, damage: 10, reach: 62,
  ),
  CharacterDef(
    id: 'c4', name: 'CHISPA', title: 'Equilibrado',
    color: Color(0xFF43A047), accent: Color(0xFFFF9800),
    maxHp: 110, speed: 150, damage: 11, reach: 50,
  ),
];

CharacterDef charById(String id) =>
    kCharacters.firstWhere((c) => c.id == id, orElse: () => kCharacters.first);

/// Enemigos (índice 0 = matón, 1 = navaja, 2 = jefe)
class EnemyDef {
  final String name;
  final Color color;
  final Color accent;
  final double hp, speed, damage, reach, w, h;
  const EnemyDef({
    required this.name,
    required this.color,
    required this.accent,
    required this.hp,
    required this.speed,
    required this.damage,
    required this.reach,
    required this.w,
    required this.h,
  });
}

const List<EnemyDef> kEnemies = [
  EnemyDef(name: 'MATÓN', color: Color(0xFF6D4C41), accent: Color(0xFFBDBDBD),
      hp: 30, speed: 70, damage: 6, reach: 44, w: 50, h: 90),
  EnemyDef(name: 'NAVAJA', color: Color(0xFF455A64), accent: Color(0xFFFF5252),
      hp: 22, speed: 115, damage: 5, reach: 40, w: 46, h: 86),
  EnemyDef(name: 'JEFE COLMILLO', color: Color(0xFF263238), accent: Color(0xFFFFD600),
      hp: 320, speed: 60, damage: 16, reach: 70, w: 84, h: 140),
];
