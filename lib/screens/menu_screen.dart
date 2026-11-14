import 'dart:math';
import 'package:flutter/material.dart';
import '../data/characters.dart';
import '../net/net_service.dart';
import 'game_screen.dart';
import 'lobby_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _name = TextEditingController(text: 'Jugador${Random().nextInt(900) + 100}');
  int _sel = 0;
  bool _busy = false;

  CharacterDef get _char => kCharacters[_sel];
  String get _pname {
    final t = _name.text.trim();
    return t.isEmpty ? 'Jugador' : t;
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _solo() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(character: _char, name: _pname, online: false, isHost: true, roster: const {}),
      ),
    );
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final code = await NetService.instance.createRoom(_pname, _char.id);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LobbyScreen(code: code, isHost: true)),
      );
    } catch (e) {
      _snack('No se pudo crear la sala: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Código de sala'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 5,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Entrar')),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final err = await NetService.instance.joinRoom(code, _pname, _char.id);
      if (!mounted) return;
      if (err != null) {
        _snack(err);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LobbyScreen(code: code.trim().toUpperCase(), isHost: false)),
        );
      }
    } catch (e) {
      _snack('No se pudo entrar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _card(int i) {
    final c = kCharacters[i];
    final sel = i == _sel;
    return GestureDetector(
      onTap: () => setState(() => _sel = i),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF211A44),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? const Color(0xFFFFEB3B) : Colors.white24, width: sel ? 3 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 56,
              decoration: BoxDecoration(
                color: c.color,
                borderRadius: BorderRadius.circular(6),
                border: Border(top: BorderSide(color: c.accent, width: 8)),
              ),
            ),
            const SizedBox(height: 6),
            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            Text(c.title, style: const TextStyle(fontSize: 11, color: Colors.white70)),
            const SizedBox(height: 4),
            Text('Vida ${c.maxHp.toInt()}  Daño ${c.damage.toInt()}', style: const TextStyle(fontSize: 11)),
            Text('Veloc. ${c.speed.toInt()}  Alcance ${c.reach.toInt()}', style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final online = NetService.instance.ready;
    return Scaffold(
      backgroundColor: const Color(0xFF14102B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'BRAWLERS\nONLINE',
                        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Color(0xFFFFEB3B), height: 1),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _name,
                        maxLength: 12,
                        decoration: const InputDecoration(
                          labelText: 'Tu nombre',
                          counterText: '',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton(onPressed: _busy ? null : _solo, child: const Text('JUGAR SOLO')),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: online && !_busy ? _create : null,
                        child: const Text('CREAR SALA ONLINE'),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: online && !_busy ? _join : null,
                        child: const Text('UNIRSE A SALA'),
                      ),
                      if (!online)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Online no disponible: configura Firebase (ver README).',
                            style: TextStyle(fontSize: 11, color: Colors.orangeAccent),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Center(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [for (var i = 0; i < kCharacters.length; i++) _card(i)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
