import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import '../data/characters.dart';
import '../net/net_service.dart';
import 'brawler_game.dart';
import 'constants.dart';
import 'draw.dart';

const double _attackDur = 0.28;

// ───────────────────────── JUGADOR LOCAL ─────────────────────────
class Player extends PositionComponent with HasGameReference<BrawlerGame> {
  final CharacterDef def;
  double hp;
  int facing = 1;
  double z = 0, vz = 0;
  double attackT = 0, comboT = 0, hurtT = 0, invuln = 0;
  int combo = 0;
  int attackCount = 0;
  bool dead = false;

  Player(this.def)
      : hp = def.maxHp,
        super(size: Vector2(50, 90), anchor: Anchor.bottomCenter, position: Vector2(120, 320));

  @override
  void update(double dt) {
    super.update(dt);
    attackT = max(0.0, attackT - dt);
    comboT = max(0.0, comboT - dt);
    hurtT = max(0.0, hurtT - dt);
    invuln = max(0.0, invuln - dt);

    if (z > 0 || vz > 0) {
      vz -= 1100 * dt;
      z += vz * dt;
      if (z <= 0) {
        z = 0;
        vz = 0;
      }
    }

    if (!dead && hurtT <= 0) {
      final j = game.joystick.relativeDelta;
      final k = attackT > 0 ? 0.3 : 1.0;
      if (attackT <= 0 && j.x.abs() > 0.15) facing = j.x > 0 ? 1 : -1;
      position.x += j.x * def.speed * k * dt;
      position.y += j.y * def.speed * 0.7 * k * dt;
    }
    position.x = position.x.clamp(game.minX, game.maxX).toDouble();
    position.y = position.y.clamp(kFloorTop, kFloorBottom).toDouble();
    priority = position.y.round();
  }

  void attack() {
    if (dead || hurtT > 0 || attackT > 0.1) return;
    combo = comboT > 0 ? (combo + 1) % 3 : 0;
    attackT = _attackDur;
    comboT = 0.7;
    attackCount++;
    final dmg = def.damage * (combo == 2 ? 1.7 : 1.0);
    for (final e in game.enemies.values.toList()) {
      final dx = (e.position.x - position.x) * facing;
      final dy = (e.position.y - position.y).abs();
      if (dx > -12 && dx < def.reach + e.def.w * 0.4 && dy < 22) {
        game.hitEnemy(e, dmg, facing, combo == 2);
      }
    }
  }

  void jump() {
    if (dead || z > 0) return;
    vz = 430;
  }

  /// Ataque especial: golpea a todos los cercanos, cuesta 8 de vida.
  void special() {
    if (dead || attackT > 0 || hp <= 12) return;
    hp -= 8;
    attackT = 0.4;
    invuln = 0.5;
    attackCount++;
    for (final e in game.enemies.values.toList()) {
      if ((e.position - position).length < 100) {
        game.hitEnemy(e, def.damage * 2, e.position.x >= position.x ? 1 : -1, true);
      }
    }
  }

  void hurt(double dmg, int dir) {
    if (dead || invuln > 0 || z > 25) return;
    hp -= dmg;
    hurtT = 0.3;
    invuln = 0.7;
    position.x += dir * 16.0;
    if (hp <= 0) {
      hp = 0;
      dead = true;
      game.onLocalDeath();
    }
  }

  @override
  void render(Canvas canvas) {
    if (!dead && invuln > 0 && (invuln * 16).floor().isOdd) return;
    drawFighter(
      canvas,
      w: size.x,
      h: size.y,
      body: def.color,
      accent: def.accent,
      facing: facing,
      attack: attackT > 0 ? (1 - attackT / _attackDur).clamp(0.0, 1.0).toDouble() : -1,
      z: z,
      lying: dead,
    );
  }
}

// ───────────────────────── JUGADOR REMOTO ─────────────────────────
class RemotePlayer extends PositionComponent with HasGameReference<BrawlerGame> {
  final String uid;
  final String name;
  final CharacterDef def;
  double hp;
  int facing = 1;
  double z = 0;
  double attackT = 0;
  int _lastAt = 0;
  Vector2 target = Vector2(120, 320);

  static final TextPaint _tp = TextPaint(
    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
  );

  RemotePlayer(this.uid, this.name, this.def)
      : hp = def.maxHp,
        super(size: Vector2(50, 90), anchor: Anchor.bottomCenter, position: Vector2(120, 320));

  void applyState(Map<String, dynamic> s, {bool snap = false}) {
    target = Vector2(dbl(s['x'], position.x), dbl(s['y'], position.y));
    facing = dbl(s['f'], 1) >= 0 ? 1 : -1;
    z = dbl(s['z'], 0);
    hp = dbl(s['h'], hp);
    final at = dbl(s['a'], 0).toInt();
    if (at != _lastAt) {
      _lastAt = at;
      if (!snap) attackT = _attackDur;
    }
    if (snap) position = target.clone();
  }

  @override
  void update(double dt) {
    super.update(dt);
    attackT = max(0.0, attackT - dt);
    position.lerp(target, min(1.0, dt * 12));
    priority = position.y.round();
  }

  @override
  void render(Canvas canvas) {
    drawFighter(
      canvas,
      w: size.x,
      h: size.y,
      body: def.color,
      accent: def.accent,
      facing: facing,
      attack: attackT > 0 ? (1 - attackT / _attackDur).clamp(0.0, 1.0).toDouble() : -1,
      z: z,
      lying: hp <= 0,
    );
    _tp.render(canvas, name, Vector2(size.x / 2, -8 - z), anchor: Anchor.bottomCenter);
  }
}

// ───────────────────────── ENEMIGO ─────────────────────────
class Enemy extends PositionComponent with HasGameReference<BrawlerGame> {
  final String id;
  final int kind;
  final bool auth; // true = este dispositivo simula su IA (solo / anfitrión)
  final EnemyDef def;
  double hp;
  int facing = -1;
  int swing = 0;
  int _seen = 0;
  double flashT = 0, stunT = 0, windup = 0, recover = 0.5, atkAnim = 0;
  late Vector2 target;

  static final TextPaint _tp = TextPaint(
    style: const TextStyle(color: Color(0xFFFFEB3B), fontSize: 20, fontWeight: FontWeight.w900),
  );

  Enemy(this.id, this.kind, this.auth, Vector2 pos)
      : def = kEnemies[kind],
        hp = kEnemies[kind].hp,
        super(
          size: Vector2(kEnemies[kind].w, kEnemies[kind].h),
          anchor: Anchor.bottomCenter,
          position: pos,
        ) {
    target = pos.clone();
  }

  /// Cliente: aplica el estado recibido del anfitrión.
  void applyNet(Map<String, dynamic> m, {bool first = false}) {
    target = Vector2(dbl(m['x'], position.x), dbl(m['y'], position.y));
    hp = dbl(m['h'], hp);
    facing = dbl(m['f'], 1) >= 0 ? 1 : -1;
    final s = dbl(m['s'], 0).toInt();
    swing = s;
    if (first) _seen = s;
  }

  void takeHit(double dmg, int dir, bool knock) {
    hp -= dmg;
    flashT = 0.15;
    if (!auth) return; // el cliente solo muestra el destello
    stunT = knock ? 0.55 : 0.22;
    windup = 0;
    position.x += dir * (knock ? 40.0 : 12.0);
    if (hp <= 0) game.removeEnemy(this);
  }

  @override
  void update(double dt) {
    super.update(dt);
    flashT = max(0.0, flashT - dt);
    atkAnim = max(0.0, atkAnim - dt);
    priority = position.y.round();

    if (swing != _seen) {
      _seen = swing;
      atkAnim = _attackDur;
      game.enemyStrike(this);
    }

    if (!auth) {
      position.lerp(target, min(1.0, dt * 12));
      return;
    }
    if (stunT > 0) {
      stunT -= dt;
      return;
    }
    if (windup > 0) {
      windup -= dt;
      if (windup <= 0) {
        swing++;
        recover = 0.7;
      }
      return;
    }
    if (recover > 0) {
      recover -= dt;
      return;
    }
    final t = game.nearestFighter(position);
    if (t == null) return;
    final dx = t.x - position.x;
    final dy = t.y - position.y;
    facing = dx >= 0 ? 1 : -1;
    if (dx.abs() < def.reach && dy.abs() < 14) {
      windup = 0.4;
      return;
    }
    final goal = Vector2(t.x - facing * (def.reach - 12), t.y);
    final dir = goal - position;
    if (dir.length > 2) {
      dir.normalize();
      position.add(dir * (def.speed * dt));
    }
    position.y = position.y.clamp(kFloorTop, kFloorBottom).toDouble();
  }

  @override
  void render(Canvas canvas) {
    drawFighter(
      canvas,
      w: size.x,
      h: size.y,
      body: def.color,
      accent: def.accent,
      facing: facing,
      attack: atkAnim > 0 ? (1 - atkAnim / _attackDur).clamp(0.0, 1.0).toDouble() : -1,
      flash: flashT > 0,
    );
    // barra de vida
    final frac = (hp / def.hp).clamp(0.0, 1.0).toDouble();
    canvas.drawRect(Rect.fromLTWH(0, -10, size.x, 5), Paint()..color = const Color(0xFF551111));
    canvas.drawRect(Rect.fromLTWH(0, -10, size.x * frac, 5), Paint()..color = const Color(0xFFFF5252));
    if (windup > 0) _tp.render(canvas, '!', Vector2(size.x / 2, -14), anchor: Anchor.bottomCenter);
  }
}
