import 'dart:async';
import 'dart:math';
import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';
import '../data/characters.dart';
import '../net/net_service.dart';
import 'constants.dart';
import 'fighters.dart';
import 'stage.dart';

class RosterEntry {
  final String name;
  final String charId;
  const RosterEntry(this.name, this.charId);
}

class GameConfig {
  final CharacterDef character;
  final String name;
  final bool online;
  final bool isHost;
  final Map<String, RosterEntry> roster; // uid -> datos
  final void Function(bool win) onFinish;
  GameConfig({
    required this.character,
    required this.name,
    required this.online,
    required this.isHost,
    required this.roster,
    required this.onFinish,
  });
}

class BrawlerGame extends FlameGame {
  BrawlerGame._(this.config, World w)
      : super(
          world: w,
          camera: CameraComponent.withFixedResolution(world: w, width: kViewW, height: kViewH),
        );

  factory BrawlerGame(GameConfig config) => BrawlerGame._(config, World());

  final GameConfig config;
  late final JoystickComponent joystick;
  late final Player player;
  final Map<String, Enemy> enemies = {};
  final Map<String, RemotePlayer> remotes = {};

  int arenaUnlocked = 0; // oleadas superadas
  int spawnedWave = -1;
  double cameraX = 0;
  bool finished = false;
  int result = 0; // 0 jugando, 1 victoria, 2 derrota
  int _nextEnemyId = 0;
  double _netT = 0;

  StreamSubscription<Map<String, dynamic>>? _subState;
  StreamSubscription<Map<String, dynamic>>? _subWorld;
  StreamSubscription<Map<String, dynamic>>? _subHits;

  bool get isAuth => !config.online || config.isHost;
  double get minX => cameraX + 30;
  double get maxX => min(arenaUnlocked + 1, kWaves) * kArenaW - 30;

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    world.add(Stage());
    player = Player(config.character);
    world.add(player);
    _buildHud();
    if (config.online) _startNet();
  }

  // ───────── HUD / controles ─────────
  void _buildHud() {
    joystick = JoystickComponent(
      knob: CircleComponent(radius: 22, paint: Paint()..color = const Color(0xCCFFFFFF)),
      background: CircleComponent(radius: 56, paint: Paint()..color = const Color(0x44FFFFFF)),
      margin: const EdgeInsets.only(left: 36, bottom: 24),
    );
    final vp = camera.viewport;
    vp.add(joystick);
    vp.add(_button('A', const Color(0xFFE53935), const EdgeInsets.only(right: 28, bottom: 28), () => player.attack()));
    vp.add(_button('B', const Color(0xFF1E88E5), const EdgeInsets.only(right: 108, bottom: 28), () => player.jump()));
    vp.add(_button('X', const Color(0xFFFFB300), const EdgeInsets.only(right: 68, bottom: 100), () => player.special()));
    vp.add(Hud());
  }

  HudButtonComponent _button(String label, Color color, EdgeInsets margin, VoidCallback onTap) {
    return HudButtonComponent(
      button: _RoundBtn(label, color),
      buttonDown: _RoundBtn(label, Color.lerp(color, Colors.white, 0.5)!),
      margin: margin,
      onPressed: onTap,
    );
  }

  // ───────── bucle ─────────
  @override
  void update(double dt) {
    super.update(dt);
    if (finished) return;

    cameraX = min(
      max(cameraX, player.position.x - kViewW / 2),
      min(arenaUnlocked, kWaves - 1) * kArenaW,
    );
    camera.viewfinder.position = Vector2(cameraX, 0);

    if (isAuth) _authUpdate();

    if (config.online) {
      _netT += dt;
      if (_netT >= 0.1) {
        _netT = 0;
        _publish();
      }
    }
  }

  void _authUpdate() {
    final next = spawnedWave + 1;
    if (next < kWaves && arenaUnlocked == next) {
      if (_frontX() >= next * kArenaW + 60) {
        spawnedWave = next;
        _spawnWave(next);
      }
    }
    if (spawnedWave >= 0 && arenaUnlocked == spawnedWave && enemies.isEmpty) {
      arenaUnlocked = spawnedWave + 1;
      if (spawnedWave == kWaves - 1) {
        _finish(true);
        return;
      }
    }
    if (config.online && player.dead && remotes.values.every((r) => r.hp <= 0)) {
      _finish(false);
    }
  }

  double _frontX() {
    double m = player.dead ? -1 : player.position.x;
    for (final r in remotes.values) {
      if (r.hp > 0) m = max(m, r.position.x);
    }
    return m;
  }

  void _spawnWave(int n) {
    final rnd = Random();
    final players = 1 + remotes.length;
    final count = (n == kWaves - 1 ? 3 : 4 + n * 2) + (players - 1) * 2;
    for (var i = 0; i < count; i++) {
      _addEnemy(rnd.nextInt(3) == 0 ? 1 : 0, n, rnd);
    }
    if (n == kWaves - 1) _addEnemy(2, n, rnd); // jefe
  }

  void _addEnemy(int kind, int n, Random rnd) {
    final fromLeft = rnd.nextBool();
    final x = fromLeft ? n * kArenaW - 40 : (n + 1) * kArenaW + 40;
    final y = kFloorTop + rnd.nextDouble() * (kFloorBottom - kFloorTop);
    final id = 'e${_nextEnemyId++}';
    final e = Enemy(id, kind, true, Vector2(x, y));
    enemies[id] = e;
    world.add(e);
  }

  // ───────── combate ─────────
  void hitEnemy(Enemy e, double dmg, int dir, bool knock) {
    e.takeHit(dmg, dir, knock);
    if (!e.auth) NetService.instance.sendHit(e.id, dmg, dir, knock);
  }

  void removeEnemy(Enemy e) {
    enemies.remove(e.id);
    e.removeFromParent();
  }

  void enemyStrike(Enemy e) {
    if (player.dead) return;
    final dx = player.position.x - e.position.x;
    final dy = (player.position.y - e.position.y).abs();
    final inFront = dx * e.facing > -10;
    if (inFront && dx.abs() < e.def.reach + 18 && dy < 20) {
      player.hurt(e.def.damage, e.facing);
    }
  }

  Vector2? nearestFighter(Vector2 from) {
    Vector2? best;
    double bd = double.infinity;
    void check(Vector2 p) {
      final d = p.distanceTo(from);
      if (d < bd) {
        bd = d;
        best = p;
      }
    }

    if (!player.dead) check(player.position);
    for (final r in remotes.values) {
      if (r.hp > 0) check(r.position);
    }
    return best;
  }

  void onLocalDeath() {
    if (!config.online) _finish(false);
  }

  void _finish(bool win) {
    if (finished) return;
    finished = true;
    result = win ? 1 : 2;
    if (config.online && isAuth) _publishWorld();
    config.onFinish(win);
  }

  // ───────── red ─────────
  void _startNet() {
    final net = NetService.instance;
    _subState = net.stateStream().listen(_onStates);
    if (isAuth) {
      _subHits = net.hitsStream().listen(_onHit);
    } else {
      _subWorld = net.worldStream().listen(_onWorld);
    }
  }

  void disposeNet() {
    _subState?.cancel();
    _subWorld?.cancel();
    _subHits?.cancel();
  }

  void _publish() {
    NetService.instance.publishState({
      'x': player.position.x.round(),
      'y': player.position.y.round(),
      'f': player.facing,
      'z': player.z.round(),
      'h': player.hp.round(),
      'a': player.attackCount,
    });
    if (isAuth) _publishWorld();
  }

  void _publishWorld() {
    final e = <String, dynamic>{};
    enemies.forEach((id, en) {
      e[id] = {
        'x': en.position.x.round(),
        'y': en.position.y.round(),
        'h': en.hp.round(),
        'f': en.facing,
        'k': en.kind,
        's': en.swing,
      };
    });
    NetService.instance.publishWorld({'a': arenaUnlocked, 'r': result, 'e': e});
  }

  void _onStates(Map<String, dynamic> all) {
    final me = NetService.instance.uid;
    for (final entry in all.entries) {
      if (entry.key == me) continue;
      final info = config.roster[entry.key];
      if (info == null) continue;
      final s = toMap(entry.value);
      var r = remotes[entry.key];
      if (r == null) {
        r = RemotePlayer(entry.key, info.name, charById(info.charId));
        remotes[entry.key] = r;
        world.add(r);
        r.applyState(s, snap: true);
      } else {
        r.applyState(s);
      }
    }
    for (final k in remotes.keys.toList()) {
      if (!all.containsKey(k)) {
        remotes.remove(k)?.removeFromParent();
      }
    }
  }

  void _onHit(Map<String, dynamic> m) {
    final e = enemies[m['e']];
    if (e == null) return;
    e.takeHit(dbl(m['d'], 5), dbl(m['r'], 1).toInt(), dbl(m['k'], 0) > 0);
  }

  void _onWorld(Map<String, dynamic> w) {
    arenaUnlocked = dbl(w['a'], 0).toInt();
    final res = dbl(w['r'], 0).toInt();
    final em = toMap(w['e']);
    for (final id in enemies.keys.toList()) {
      if (!em.containsKey(id)) removeEnemy(enemies[id]!);
    }
    em.forEach((id, v) {
      final m = toMap(v);
      final e = enemies[id];
      if (e == null) {
        final ne = Enemy(id, dbl(m['k'], 0).toInt(), false, Vector2(dbl(m['x'], 0), dbl(m['y'], 300)));
        ne.applyNet(m, first: true);
        enemies[id] = ne;
        world.add(ne);
      } else {
        e.applyNet(m);
      }
    });
    if (res != 0) _finish(res == 1);
  }
}

// ───────────────────────── HUD ─────────────────────────
class _RoundBtn extends PositionComponent {
  final String label;
  final Color color;
  _RoundBtn(this.label, this.color) : super(size: Vector2.all(64));

  static final TextPaint _tp = TextPaint(
    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
  );

  @override
  void render(Canvas c) {
    c.drawCircle(const Offset(32, 32), 31, Paint()..color = color.withAlpha(190));
    _tp.render(c, label, Vector2(32, 32), anchor: Anchor.center);
  }
}

class Hud extends PositionComponent with HasGameReference<BrawlerGame> {
  Hud() : super(size: Vector2(kViewW, kViewH), priority: 50);

  static final TextPaint _tp = TextPaint(
    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
  );
  static final TextPaint _big = TextPaint(
    style: const TextStyle(color: Color(0xFFFFEB3B), fontSize: 26, fontWeight: FontWeight.w900),
  );
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    var row = 0;
    void bar(String name, double hp, double maxHp, Color c) {
      final y = 10.0 + row * 22;
      _tp.render(canvas, name, Vector2(14, y));
      const x0 = 100.0;
      final frac = (hp / maxHp).clamp(0.0, 1.0).toDouble();
      canvas.drawRect(Rect.fromLTWH(x0, y + 2, 140, 12), Paint()..color = const Color(0xFF442222));
      canvas.drawRect(Rect.fromLTWH(x0, y + 2, 140 * frac, 12), Paint()..color = c);
      row++;
    }

    final g = game;
    bar(g.config.name, g.player.hp, g.player.def.maxHp, g.player.def.color);
    for (final r in g.remotes.values) {
      bar(r.name, r.hp, r.def.maxHp, r.def.color);
    }

    _tp.render(canvas, 'OLEADA ${min(g.arenaUnlocked + 1, kWaves)}/$kWaves', Vector2(kViewW / 2, 12), anchor: Anchor.topCenter);
    if (g.config.online) {
      _tp.render(canvas, 'SALA ${NetService.instance.room}', Vector2(kViewW / 2, 30), anchor: Anchor.topCenter);
    }

    final canAdvance = g.enemies.isEmpty && g.arenaUnlocked > 0 && g.arenaUnlocked * kArenaW > g.cameraX + 5;
    if (canAdvance && sin(_t * 8) > 0) {
      _big.render(canvas, '¡VAMOS!  →', Vector2(kViewW - 60, 90), anchor: Anchor.topRight);
    }
    if (g.player.dead && g.config.online && !g.finished) {
      _big.render(canvas, 'ESPECTANDO…', Vector2(kViewW / 2, 120), anchor: Anchor.center);
    }
  }
}
