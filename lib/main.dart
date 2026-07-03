import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game_config.dart';
import 'screens/loading_screen.dart';
import 'services/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Storage.init();

  // The loading screen supports both orientations; the game locks to portrait
  // once loading has completed (handled in HomeScreen / GameScreen).
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const PinballPlungeApp());
}

class PinballPlungeApp extends StatelessWidget {
  const PinballPlungeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pinball Plunge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppTheme.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTheme.accent,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),
      home: const LoadingScreen(),
    );
  }
}
