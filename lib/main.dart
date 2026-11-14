import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'net/net_service.dart';
import 'screens/menu_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await NetService.instance.init(); // si Firebase no está configurado, solo funciona el modo solo
  runApp(const BrawlersApp());
}

class BrawlersApp extends StatelessWidget {
  const BrawlersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brawlers Online',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const MenuScreen(),
    );
  }
}
