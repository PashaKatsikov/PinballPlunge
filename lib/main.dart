import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/pinboard_brief.dart';
import 'media_library.dart';
import 'router/entry_pipeline.dart';
import 'services/storage.dart';
import 'spine/local_stash.dart';
import 'spine/masked_http.dart';
import 'spine/pulse_sensor.dart';
import 'spine/relay_post.dart';
import 'spine/signal_dock.dart';
import 'spine/tracker_link.dart';

// Bootstrap wiring order (do NOT reorder without reading the guide):
//   1. Ensure the Flutter binding — required before any plugin call.
//   2. Native arcade storage — the game screen reads bestScore in build().
//   3. Firebase + AppCheck. Wrapped in try/catch because the project ships
//      without google-services.json in the template; failure here must not
//      block startup — the shell degrades to native.
//   4. Full orientation whitelist (loading + WebView rotate freely); the
//      arcade re-locks to portrait once the router routes into it.
//   5. Transparent status bar + light icons for the loading artwork.
//   6. Stitch the forged UA BEFORE any bridge is instantiated — RelayPost
//      uses maskedNet on its very first request.
//   7. LocalStash.warmUp() reads SharedPreferences into memory so the first
//      frame of EntryPipeline can decide routing synchronously.

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Storage.init();

  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (_) {}

  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await maskedNet.stitch();

  final LocalStash stash = LocalStash();
  await stash.warmUp();

  final PulseSensor pulse = PulseSensor();
  final TrackerLink tracker = TrackerLink();
  final RelayPost relay = RelayPost(stash);
  final SignalDock dock = SignalDock(stash);

  runApp(PinboardApp(
    stash: stash,
    pulse: pulse,
    tracker: tracker,
    relay: relay,
    dock: dock,
  ));
}

class PinboardApp extends StatelessWidget {
  const PinboardApp({
    super.key,
    required this.stash,
    required this.pulse,
    required this.tracker,
    required this.relay,
    required this.dock,
  });

  final LocalStash stash;
  final PulseSensor pulse;
  final TrackerLink tracker;
  final RelayPost relay;
  final SignalDock dock;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: PinboardBrief.displayName,
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
      home: EntryPipeline(
        stash: stash,
        pulse: pulse,
        tracker: tracker,
        relay: relay,
        dock: dock,
      ),
    );
  }
}
