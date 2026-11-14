import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../data/characters.dart';
import '../game/brawler_game.dart';
import '../net/net_service.dart';

class GameScreen extends StatefulWidget {
  final CharacterDef character;
  final String name;
  final bool online;
  final bool isHost;
  final Map<String, RosterEntry> roster;
  const GameScreen({
    super.key,
    required this.character,
    required this.name,
    required this.online,
    required this.isHost,
    required this.roster,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final BrawlerGame game;
  bool? _win;

  @override
  void initState() {
    super.initState();
    game = BrawlerGame(GameConfig(
      character: widget.character,
      name: widget.name,
      online: widget.online,
      isHost: widget.isHost,
      roster: widget.roster,
      onFinish: (w) {
        if (mounted) setState(() => _win = w);
      },
    ));
  }

  @override
  void dispose() {
    game.disposeNet();
    if (widget.online) NetService.instance.leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GameWidget(game: game),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (_win != null)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _win! ? '¡VICTORIA!' : 'DERROTA',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: _win! ? const Color(0xFFFFEB3B) : Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('VOLVER AL MENÚ'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
