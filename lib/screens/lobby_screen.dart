import 'dart:async';
import 'package:flutter/material.dart';
import '../data/characters.dart';
import '../game/brawler_game.dart';
import '../net/net_service.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String code;
  final bool isHost;
  const LobbyScreen({super.key, required this.code, required this.isHost});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final net = NetService.instance;
  StreamSubscription<String>? _sub;
  bool _going = false;

  @override
  void initState() {
    super.initState();
    _sub = net.metaStateStream().listen(_onState);
  }

  Future<void> _onState(String s) async {
    if (_going) return;
    if (s == 'closed') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El anfitrión cerró la sala')));
      Navigator.pop(context);
      return;
    }
    if (s == 'playing') {
      _going = true;
      final players = await net.playersOnce();
      if (!mounted) return;
      final roster = <String, RosterEntry>{};
      players.forEach((uid, v) {
        final m = toMap(v);
        roster[uid] = RosterEntry(m['name']?.toString() ?? 'Jugador', m['char']?.toString() ?? kCharacters.first.id);
      });
      final me = roster[net.uid];
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GameScreen(
            character: charById(me?.charId ?? kCharacters.first.id),
            name: me?.name ?? 'Jugador',
            online: true,
            isHost: widget.isHost,
            roster: roster,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (!_going) net.leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14102B),
      appBar: AppBar(title: const Text('Sala de espera'), backgroundColor: Colors.transparent),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Código de sala', style: TextStyle(color: Colors.white70)),
            Text(
              widget.code,
              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: 8, color: Color(0xFFFFEB3B)),
            ),
            const SizedBox(height: 8),
            StreamBuilder<Map<String, dynamic>>(
              stream: net.playersStream(),
              builder: (context, snap) {
                final players = snap.data ?? {};
                return Column(
                  children: [
                    Text('Jugadores: ${players.length}/4'),
                    const SizedBox(height: 6),
                    for (final e in players.entries)
                      Text(
                        '• ${toMap(e.value)['name'] ?? '?'}  (${charById(toMap(e.value)['char']?.toString() ?? '').name})',
                        style: const TextStyle(fontSize: 16),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            if (widget.isHost)
              FilledButton(onPressed: () => net.startGame(), child: const Text('INICIAR PARTIDA'))
            else
              const Text('Esperando al anfitrión…'),
          ],
        ),
      ),
    );
  }
}
