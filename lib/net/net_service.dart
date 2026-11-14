import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../firebase_options.dart';

double dbl(Object? v, double d) => v is num ? v.toDouble() : d;

Map<String, dynamic> toMap(Object? v) {
  if (v is! Map) return <String, dynamic>{};
  return v.map<String, dynamic>(
    (k, val) => MapEntry<String, dynamic>(k.toString(), val is Map ? toMap(val) : val),
  );
}

/// Capa de red: salas, lobby y sincronización con Firebase Realtime Database.
///
/// rooms/{code}/meta     {host, state: lobby|playing}
/// rooms/{code}/players  {uid: {name, char}}
/// rooms/{code}/state    {uid: {x,y,f,z,h,a}}   (cada jugador, 10 Hz)
/// rooms/{code}/world    {a, r, e:{id:{x,y,h,f,k,s}}} (el anfitrión, 10 Hz)
/// rooms/{code}/hits     golpes de clientes hacia el anfitrión
class NetService {
  NetService._();
  static final NetService instance = NetService._();

  bool ready = false;
  String uid = '';
  String room = '';
  bool isHost = false;

  Future<bool> init() async {
    if (!DefaultFirebaseOptions.isConfigured) return false;
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
      final cred = await FirebaseAuth.instance
          .signInAnonymously()
          .timeout(const Duration(seconds: 10));
      uid = cred.user!.uid;
      ready = true;
    } catch (_) {
      ready = false;
    }
    return ready;
  }

  DatabaseReference _ref(String code) => FirebaseDatabase.instance.ref('rooms/$code');

  Future<String> createRoom(String name, String charId) async {
    final rnd = Random();
    const abc = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    String code = '';
    while (true) {
      code = List.generate(5, (_) => abc[rnd.nextInt(abc.length)]).join();
      final snap = await _ref(code).child('meta').get();
      if (!snap.exists) break;
    }
    await _ref(code).child('meta').set({'host': uid, 'state': 'lobby'});
    room = code;
    isHost = true;
    await _addPlayer(name, charId);
    return code;
  }

  /// Devuelve null si todo va bien, o un mensaje de error.
  Future<String?> joinRoom(String code, String name, String charId) async {
    code = code.trim().toUpperCase();
    final meta = await _ref(code).child('meta').get();
    if (!meta.exists) return 'La sala no existe';
    final m = toMap(meta.value);
    if (m['state'] != 'lobby') return 'La partida ya empezó';
    final pl = await _ref(code).child('players').get();
    if (toMap(pl.value).length >= 4) return 'La sala está llena (máx. 4)';
    room = code;
    isHost = false;
    await _addPlayer(name, charId);
    return null;
  }

  Future<void> _addPlayer(String name, String charId) async {
    final p = _ref(room).child('players/$uid');
    await p.set({'name': name, 'char': charId});
    p.onDisconnect().remove();
    _ref(room).child('state/$uid').onDisconnect().remove();
  }

  Future<void> leave() async {
    if (room.isEmpty) return;
    final r = _ref(room);
    final wasHost = isHost;
    room = '';
    isHost = false;
    try {
      if (wasHost) {
        await r.remove();
      } else {
        await r.child('players/$uid').remove();
        await r.child('state/$uid').remove();
      }
    } catch (_) {}
  }

  Future<void> startGame() => _ref(room).child('meta/state').set('playing');

  Stream<Map<String, dynamic>> playersStream() =>
      _ref(room).child('players').onValue.map((e) => toMap(e.snapshot.value));

  Future<Map<String, dynamic>> playersOnce() async {
    final s = await _ref(room).child('players').get();
    return toMap(s.value);
  }

  Stream<String> metaStateStream() => _ref(room).child('meta').onValue.map((e) {
        final m = toMap(e.snapshot.value);
        return m.isEmpty ? 'closed' : (m['state']?.toString() ?? 'lobby');
      });

  void publishState(Map<String, dynamic> s) {
    if (room.isEmpty) return;
    _ref(room).child('state/$uid').set(s);
  }

  Stream<Map<String, dynamic>> stateStream() =>
      _ref(room).child('state').onValue.map((e) => toMap(e.snapshot.value));

  void publishWorld(Map<String, dynamic> w) {
    if (room.isEmpty) return;
    _ref(room).child('world').set(w);
  }

  Stream<Map<String, dynamic>> worldStream() =>
      _ref(room).child('world').onValue.map((e) => toMap(e.snapshot.value));

  void sendHit(String enemyId, double dmg, int dir, bool knock) {
    if (room.isEmpty) return;
    _ref(room).child('hits').push().set({'e': enemyId, 'd': dmg, 'r': dir, 'k': knock ? 1 : 0});
  }

  Stream<Map<String, dynamic>> hitsStream() =>
      _ref(room).child('hits').onChildAdded.map((e) {
        final m = toMap(e.snapshot.value);
        e.snapshot.ref.remove();
        return m;
      });
}
